param(
[String[]] $remoteServerList = "testiis3")

#This pulls the encrypted password string from the text file and creates a PSCred with it
function getCred([string] $txt,$user) 
{
        $passtxt = ConvertTo-SecureString $txt -AsPlainText -Force
        $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user,$passtxt
        return $cred
}
#This will take a PSCred and give you back the password in it in plain text
function Decrypt($cred) 
{
    return $pass = $cred.GetNetworkCredential().Password
}

#This function sets a remote path to copy to or from using a credential 
function setPath([string]$uncPath,[string]$user,[string]$pass) 
{
    $command = "cmd.exe /c net use $uncPath $pass /USER:$user"
    Invoke-Expression $command
}

# This function clears any paths setup by the script to ensure other users can't hijack our connections
function clearPaths ([string]$uncPath)
{
    $command = "cmd.exe /c net use $uncPath /DELETE /YES"
    Invoke-Expression $command
}

# Script for remote server
$Serverscript = {
Import-Module WebAdministration
$websites = @()

$net = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\' -recurse |
Get-ItemProperty -name Version,Release -EA 0 |
Where { $_.PSChildName -match '^(?!S)\p{L}'} |
Select PSChildName, Version, Release, @{
  name="Product"
  expression={
      switch -regex ($_.Release) {
        "378389" { [Version]"4.5" }
        "378675|378758" { [Version]"4.5.1" }
        "379893" { [Version]"4.5.2" }
        "393295|393297" { [Version]"4.6" }
        "394254|394271" { [Version]"4.6.1" }
        "394802|394806" { [Version]"4.6.2" }
        "460798" { [Version]"4.7" }
        {$_ -gt 460798} { [Version]"Undocumented 4.7 or higher, please update script" }
      }
    }
}
$item = @{}
$item.Type = ".Net"
$item.Name = ".Net "+ $net[0].Product
$item.Path = ""
$item.Username = ""
$item.AppPool = ""
$item.IPAddresses = ""
$obj = New-Object psobject -Property $item
$websites += $obj

foreach ($site in (Get-Website | Sort Name))
{
    $item = @{}
    $item.Type = "WebSite"
    $item.name = $site.name
    $item.path = $site.physicalPath
    $item.AppPool = $site.applicationPool
    $Bindings = Get-webbinding -Name $site.name | select bindinginformation
    $item.IPAddresses = ""
    foreach ($bind in $Bindings) {
        $item.IPAddresses += "/"
        $item.IPAddresses += $bind.bindingInformation
    }
    $item.IPAddresses = ($item.IPAddresses).TrimStart("/")
    $item.Username = ""
    $obj = New-Object psobject -Property $item
    $websites += $obj
}

[xml]$apps = c:\windows\system32\inetsrv\appcmd list app /config /xml
foreach ($app in ($apps.appcmd.app | sort 'APP.NAME'))
{
    $item = @{}
    $item.Type = "Application"
    $item.Name = $app.'APP.NAME'
    #$item.Name = $item.name.Replace($app.'SITE.NAME',"")
    $item.Path = $app.application.virtualDirectory.physicalPath
    $item.Path = $item.Path.Replace("%SystemDrive%","C:")
    $item.AppPool = $app.'APPPOOL.NAME'
    [xml]$test = c:\windows\system32\inetsrv\appcmd list apppool $app.'APPPOOL.NAME' /config /xml
    $item.Username = $test.appcmd.APPPOOL.add.processModel.userName
    $item.IPAddresses = $test.appcmd.APPPOOL.add.startMode
    if ($test.appcmd.APPPOOL.add.startMode -eq $null){
        $item.IPAddresses = "OnDemand"
    }
    $obj = New-Object psobject -Property $item | sort
    $websites += $obj
}

$services = Get-WmiObject win32_service | select Displayname,PathName,StartName | Sort Displayname | where {$_.displayname -match "[@|#].*"}
foreach ($service in $services)
{
    $item = @{}
    $item.Type = "Service"
    $item.Name = $service.Displayname
    $item.Path = $service.PathName
    $item.Path = $item.Path.Replace('"',"")
    $item.Username = $service.StartName
    $item.AppPool = ""
    $item.IPAddresses = ""
    $obj = New-Object psobject -Property $item
    $websites += $obj
}
Return $websites
}

# call script on remote server
Foreach ($server in $remoteServerList)
{
    If ($credtxt -ne "")
    {
        $cred = getCred $credtxt $user
        $currentpass = Decrypt $cred
        setPath \\$server\C$ $user $currentpass
        $s = New-PSSession -ComputerName $Server -Credential $cred
    }
    else
    {
    $s = New-PSSession -ComputerName $Server
    }
    $output = ""
    $output = Invoke-Command -Session $S -ScriptBlock $Serverscript
    Write-Output $output | select Type,Name,Path,AppPool,Username,IPAddresses | Export-Csv -Path ($Server+"_audit_sites.csv") -NoTypeInformation

Remove-PSSession -Session $s

if ($credtxt -ne "")
    {
        clearPaths \\$server\C$
    }

}


# 2nd part of script
$Files = Get-ChildItem -File
$Exit = 0
Foreach ($File in $Files){

if((Get-FileHash $file).hash  -ne (Get-FileHash ".\Info\$file").hash) {
    Write-Host "$File file is different"
    copy-item $File (New-Item -ItemType directory -force -Name "Info") -Force
    $exit = 7
    }
    Else {}
}

Exit($Exit)