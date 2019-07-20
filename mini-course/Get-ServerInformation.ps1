$serversOuPath = 'OU=Servers,DC=powerlab,DC=local'
$servers = Get-ADComputer -SearchBase $serversOuPath -Filter * | Select-Object -ExpandProperty Name
foreach ($server in $servers) {
    $output = @{
        'ServerName'                  = $null
        'IPAddress'                   = $null
        'OperatingSystem'             = $null
        'AvailableDriveSpace (GB)'    = $null
        'Memory (GB)'                 = $null
        'UserProfilesSize (MB)'       = $null
        'StoppedServices'             = $null
    }
    $getCimInstParams = @{
        CimSession = (New-CimSession -ComputerName $server)
    }
    $output.ServerName = $server

    $userProfileSize = (Get-ChildItem -Path "\\$server\c$\Users\" -File -Recurse | Measure-Object -Property Length -Sum).Sum
    $output.'UserProfilesSize (MB)' = $userProfileSize / 1GB
    
    $output.'AvailableDriveSpace (GB)' = Get-CimInstance @getCimInstParams -ClassName Win32_LogicalDisk | Select-Object -Property DeviceID,@{Name='FreeSpace';Expression={ [Math]::Round(($_.Freespace / 1GB),1) }}
    
    $output.'OperatingSystem' = (Get-CimInstance @getCimInstParams -ClassName Win32_OperatingSystem).Caption

    $output.'Memory (GB)' = (Get-CimInstance @getCimInstParams -ClassName Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum /1GB
    
    $output.'IPAddress' = (Get-CimInstance @getCimInstParams -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'True'").IPAddress[0]
    
    $output.StoppedServices = (Get-Service -ComputerName $server | Where-Object { $_.Status -eq 'Stopped' } | Measure-Object).Count

    Remove-CimSession @getCimInstParams
    
    [pscustomobject]$output
}
