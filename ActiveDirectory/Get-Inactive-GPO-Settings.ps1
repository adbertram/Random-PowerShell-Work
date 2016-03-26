################################################################################
#
#	Script Name: Get-Inactive-GPO-Settings.ps1
#	Date: 8/2/2012
# 	Author: Adam Bertram
#	Purpose:  This script finds all GPOs in the current domain which have
#		either the user or computer configuration section enabled yet have no
#		settings enabled in that section.
#
################################################################################

if (!(Get-Module 'GroupPolicy') -or !(Get-Module 'Internal')) {
	Write-Error 'One or more required modules not loaded';
	return;
}##endif

$bRemediate = $false;

## Create an array of default Active Directory GPOs
$aDefaultGpos = @('Default Domain Controllers Policy');

$aGposToRead = Get-GPOReport -ReportType XML -All;

foreach ($sGpo in $aGposToRead) {
	$xGpo = ([xml]$sGpo).GPO;
	if ($aDefaultGpos -notcontains $xGpo.Name) { ## Do not report on default AD GPOs.  We don't want to change these
		$o = New-Object System.Object;
		$o | Add-Member -type NoteProperty -Name 'GPO' -Value $xGpo.Name;
		if ($xGpo.User.Enabled -eq 'true' -and !(Test-Member $xGpo.User ExtensionData)) {
			$o | Add-Member -type NoteProperty -Name 'UnpopulatedLink' -Value 'User';
			if ($bRemediate) {
				(Get-GPO $xGpo.Name).GPOStatus = 'UserSettingsDisabled';
				echo "Disabled user settings on GPO $($xGpo.Name)";
			} else {
				$o
			}##endif
		}##endif
		if ($xGpo.Computer.Enabled -eq 'true' -and !(Test-Member $xGpo.Computer ExtensionData)) {
			$o | Add-Member -type NoteProperty -Name 'UnpopulatedLink' -Value 'Computer' -Force;
			if ($bRemediate) {
				(Get-GPO $xGpo.Name).GPOStatus = 'ComputerSettingsDisabled';
				echo "Disabled computer settings on GPO $($xGpo.Name)";
			} else {
				$o
			}##endif
		}##endif
	}##endif
}##endforeach
