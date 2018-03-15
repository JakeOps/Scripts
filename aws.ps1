param(
[String] $AWSUser = "",
[String] $AWSPass ="",
[String] $InstanceID = "",
[String] $Region = "",
[switch] $start,
[switch] $stop)

Import-Module "C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1"


Set-AWSCredentials -AccessKey $AWSUser -SecretKey $AWSPass -StoreAs JenkinsAWSKey

function StartInstance
{
    Write-Host "Starting Instance $InstanceID"
    Start-EC2Instance -ProfileName JenkinsAWSKey -InstanceId $InstanceID -Region $Region
    GetStatus -isrunning "running"
}

function StopInstance
{
    Write-Host "Stopping Instance $InstanceID"
    Stop-EC2Instance -ProfileName JenkinsAWSKey -InstanceId $InstanceID -Region $Region
    GetStatus -isrunning "stopped"
}

function GetStatus ([String] $isrunning)
{
    $tries = 0
    $Status = Get-EC2Instance -ProfileName JenkinsAWSKey -InstanceId $InstanceID -Region $Region
    $Status = $Status.Instances.State.Name

    While ($tries -lt 10 -and $Status -ne $isrunning) {
        Start-Sleep 5
        $Status = Get-EC2Instance -ProfileName JenkinsAWSKey -InstanceId $InstanceID -Region $Region
        $Status = $Status.Instances.State.Name
        Write-Host "Instance $InstanceID is $Status"
        $tries = $tries + 1
        }

    if ($tries -eq 10){
        Remove-AWSCredentialProfile -ProfileName JenkinsAWSKey -Force
        Write-Warning "Instance state change has taken too long"
        exit (1)
        }
}

If ($start) {
    StartInstance
    }

If ($stop) {
    StopInstance
    }

Remove-AWSCredentialProfile -ProfileName JenkinsAWSKey -Force