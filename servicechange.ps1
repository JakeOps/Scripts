param(
[string] $serviceName = "",
[String[]] $Servers = "",
[switch] $start,
[switch] $stop)

function StopService ($Server)
{
    $tries = 0
    $Status = Get-Service -ComputerName $Server -Name $serviceName
    $service = $Status.Name
    sc.exe \\$Server stop $service

    While ($tries -lt 5 -and $Status -ne "Stopped")
    {
        Start-Sleep 5
        $Status = Get-Service -ComputerName $Server -Name $serviceName
        $Status = $Status.Status
        Write-Host "$serviceName is $Status"
        $tries = $tries + 1
    }
    if ($tries -eq 5)
    {
        cmd.exe /c net use * /DELETE /YES
        Write-Warning "Service could not stop"
        exit (1)
    }
    else 
    {
        Write-Host "$serviceName is $Status"
    }
}

function StartService ($Server)
{
    $tries = 0
    $Status = Get-Service -ComputerName $Server -Name $serviceName
    $service = $Status.Name
    sc.exe \\$Server start $service

    While ($tries -lt 5 -and $Status -ne "Running") 
    {
        Start-Sleep 5
        $Status = Get-Service -ComputerName $Server -Name $serviceName
        $Status = $Status.Status
        Write-Host "$serviceName is $Status"
        $tries = $tries + 1
    }
    if ($tries -eq 5)
    {
        cmd.exe /c net use * /DELETE /YES
        Write-Warning "Service could not start"
        exit (1)
    }
    else 
    {
        Write-Host "$serviceName is $Status"
    }
}

If ($stop) 
{
    $resultr = New-Object 'System.Collections.Generic.List[String]'
    $resultn = New-Object 'System.Collections.Generic.List[String]'
    foreach ($server in $servers)
    {
        $wasrunning = Get-Service -ComputerName $server -Name $serviceName
        $running = $wasrunning.Status
        Write-Host "Service was $running on $server"
        if ($running -eq "Stopped") 
        {
            $resultn.Add($server)
        }
        else 
        {
            $resultr.Add($server)
            StopService -server $Server
        }
    }
    $ofs = ';'
    "Running = $resultr" | Out-File env.properties -Encoding ASCII
    "Stopped = $resultn" | Out-File env.properties -Encoding ASCII -Append
}

If ($start) 
{
    foreach ($server in $servers)
    {
        foreach ($result in ($env:Stopped -split ';'))
        {
            if ($result -eq $server)
            {
                Write-Host "Service was stopped on $server"
            }
        }
        foreach ($result in ($env:Running -split ';'))
        {
            if ($result -eq $server)
            {
                Write-Host "Service was running on $server"
                StartService  -server $Server
            }
        }
    }
}