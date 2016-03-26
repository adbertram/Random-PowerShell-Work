$aExclude = @('Cryptographic Operators',
'Distributed COM Users',
'Domain Computers',
'Domain Controllers',
'Domain Guests',
'Enterprise Read-only Domain Controllers',
'Event Log Readers',
'Incoming Forest Trust Builders',
'Network Configuration Operators',
'Performance Log Users',
'Performance Monitor Users',
'Print Operators',
'Replicator',
'Read-only Domain Controllers',
'Allowed RODC Password Replication Group',
'RAS and IAS Servers',
'Certificate Service DCOM Access');


$aEmpty = Get-ADGroup -Filter * -Properties * | where { $_.Members.Count -eq 0 -and $_.Name -notlike 'KAV*' -and $_.Name -notlike 'KL*' -and $_.Name -notlike 'vpn.*' -and $_.Name -ne 'CTX ISU EMR' };
$i = 0;
$aRemove = @();
foreach ($oGroup in $aEmpty) {
	if ($aExclude -notcontains $oGroup.Name) {
		#$aRemove += $oGroup;
		$oGroup.Name
		$i++
	}
}
$i
#$aRemove | Remove-ADGroup