$hyperVHost = 'HYPERVSRV'
$vmUptimes = Get-VM -ComputerName $hyperVHost | select name, uptime, @{ n = 'Type'; e= { 'VM' } }

$wmiParams = @{
	'ComputerName' = $hyperVHost
	'Class' = 'Win32_OperatingSystem'
}
$hostUptime = Get-WmiObject @wmiParams | select @{ n = 'Uptime'; e = { (Get-Date) - ($_.ConvertToDateTime($_.LastBootUpTime)) } },
												@{ n = 'Name'; e = { $_.PSComputerName } },
												@{ n = 'Type'; e = { 'Host' } }

($vmUptimes + $hostUptime)