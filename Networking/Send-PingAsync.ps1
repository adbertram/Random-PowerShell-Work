$ips = '192.168.1.5','192.1..4444'
$t = $ips | foreach {
	(New-Object Net.NetworkInformation.Ping).SendPingAsync($_, 250)
}
[Threading.Tasks.Task]::WaitAll($t)
$t.Result