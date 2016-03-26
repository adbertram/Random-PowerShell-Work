$aOutput = @();
$aDisabledGpos = Get-GPO -All | Where-Object { $_.GpoStatus -eq 'AllSettingsDisabled' };
foreach ($oGpo in $aDisabledGpos) {
	$oOutput = New-Object System.Object;
	$oOutput | Add-Member -type NoteProperty -Name 'Status' -Value 'Disabled';
	$oOutput | Add-Member -type NoteProperty -Name 'Name' -Value $oGpo.DisplayName;
	$aOutput += $oOutput;
}##endforeach


$aAllGpos = Get-Gpo -All;
$aUnlinkedGpos = @();
foreach ($oGpo in $aAllGpos) {
	 [xml]$oGpoReport = Get-GPOReport -Guid $oGpo.ID -ReportType xml;
	 if (!(Test-Member $oGpoReport.GPO LinksTo)) {
	 	$oOutput = New-Object System.Object;
		$oOutput | Add-Member -type NoteProperty -Name 'Status' -Value 'Unlinked';
		$oOutput | Add-Member -type NoteProperty -Name 'Name' -Value $oGpo.DisplayName;
		$aOutput += $oOutput;
	}##endif
}##endforeach
$aOutput.Count

$aOutput | Sort-Object Name | Format-Table -AutoSize