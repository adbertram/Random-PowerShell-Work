[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$ComputerName,

    [Parameter(Mandatory)]
    [pscredential]$Credential
)

$Header = @"
<style>
    table {
        font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
        border-collapse: collapse;
        width: 100%;
    }
    th {
        padding-top: 12px;
        padding-bottom: 12px;
        text-align: left;
        background-color: #4CAF50;
        color: white;
    }
</style>
"@

$scriptBlock = {
    $output = @{
        'ServerName'               = (hostname)
        'IPAddress'                = $null
        'OperatingSystem'          = $null
        'AvailableDriveSpace (GB)' = $null
        'Memory (GB)'              = $null
        'UserProfilesSize (MB)'    = $null
        'StoppedServices'          = $null
    }

    $userProfileSize = (Get-ChildItem -Path 'C:\Users' -File -Recurse | Measure-Object -Property Length -Sum).Sum
    $output.'UserProfilesSize (MB)' = [math]::Round($userProfileSize / 1GB, 1)

    $output.'IPAddress' = (Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'True'").IPAddress[0]

    $output.'OperatingSystem' = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption

    $output.'Memory (GB)' = (Get-CimInstance -ClassName Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum /1GB

    $output.'AvailableDriveSpace (GB)' = (Get-CimInstance -ClassName Win32_LogicalDisk | 
        Select-Object -Property DeviceID, @{Name='FreeSpace'; Expression={ [Math]::Round(($_.Freespace / 1GB), 1) } } |
            Measure-Object -Property FreeSpace -Sum).Sum

    $output.'StoppedServices' = (Get-Service | Where-Object { $_.Status -eq 'Stopped' } | Measure-Object).Count

    [pscustomobject]$output
}

$icmParams = @{
    ComputerName = $ComputerName
    ScriptBlock = $scriptBlock
    Credential = $Credential
}

$report = Invoke-Command @icmParams | Select-Object -Property * -ExcludeProperty 'RunspaceId','PSComputerName','PSShowComputerName' | ConvertTo-Html -Fragment

ConvertTo-HTML -PreContent "<h1>Server Information Report</h1>"  -PostContent $report -Head $Header | Out-File ServerReport.html
Invoke-Item ServerReport.html
