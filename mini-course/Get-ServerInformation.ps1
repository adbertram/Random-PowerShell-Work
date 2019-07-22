$serversOuPath = 'OU=Servers,DC=powerlab,DC=local'
$servers = Get-ADComputer -SearchBase $serversOuPath -Filter * |
Select-Object -ExpandProperty Name

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

$report = foreach ($server in $servers) {
    $output = [ordered]@{
        'ServerName'               = $null
        'IPAddress'                = $null
        'OperatingSystem'          = $null
        'AvailableDriveSpace (GB)' = $null
        'Memory (GB)'              = $null
        'UserProfilesSize (MB)'    = $null
        'StoppedServices'          = $null
    }
    $getCimInstParams = @{
        CimSession = (New-CimSession -ComputerName $server)
    }
    $output.ServerName = $server

    $userProfileSize = (Get-ChildItem -Path "\\$server\c$\Users\" -File -Recurse | Measure-Object -Property Length -Sum).Sum
    $output.'UserProfilesSize (MB)' = [math]::Round($userProfileSize / 1GB,1)
    
    $output.'AvailableDriveSpace (GB)' = Get-CimInstance @getCimInstParams -ClassName Win32_LogicalDisk | Select-Object -Property DeviceID, @{Name='FreeSpace'; Expression={ [Math]::Round(($_.Freespace / 1GB), 1) } }
    
    $output.'OperatingSystem' = (Get-CimInstance @getCimInstParams -ClassName Win32_OperatingSystem).Caption

    $output.'Memory (GB)' = (Get-CimInstance @getCimInstParams -ClassName Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum /1GB
    
    $output.'IPAddress' = (Get-CimInstance @getCimInstParams -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'True'").IPAddress[0]
    
    $output.StoppedServices = (Get-Service -ComputerName $server | Where-Object { $_.Status -eq 'Stopped' } | Measure-Object).Count

    Remove-CimSession @getCimInstParams
    
    [pscustomobject]$output
}

$reportfinal = $report | ConvertTo-Html -Fragment
ConvertTo-HTML -PreContent "<h1>Server Information Report</h1>"  -PostContent $reportFINAL -Head $Header | Out-File ServerReport.html
