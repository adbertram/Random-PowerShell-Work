
<#PSScriptInfo

.VERSION 1.0

.GUID b918ed36-48fa-4577-b2bf-c4d9225cd095

.AUTHOR Adam Bertram

.COMPANYNAME Adam the Automator, LLC

.COPYRIGHT 

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


.PRIVATEDATA 

#>

<#
.SYNOPSIS
	This is a script that reads a computer's event log for startup and shutdown events. Once found, it will then compare the
	times each of these events to come up with the total time the computer was down for.

.DESCRIPTION
	This is a script that reads a computer's event log for startup and shutdown events. Once found, it will then compare the
	times each of these events to come up with the total time the computer was down for.

.PARAMETER ComputerName
	One computer name you'd like to run the report on.
#>

[CmdletBinding()]
param (
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$ComputerName = $env:COMPUTERNAME
)

$filterHt = @{
	'LogName' = 'System'
	'ID'      = 6005
}
$StartEvents = Get-WinEvent -ComputerName $ComputerName -FilterHashtable $filterHt
if (-not $StartEvents) {
	throw 'Unable to determine any start times'	
}
$StartTimes = $StartEvents.TimeCreated

## Find all stop events
$filterHt.ID = 6006
$StopEvents = Get-WinEvent -ComputerName $ComputerName -FilterHashtable $filterHt -Oldest
$StopTimes = $StopEvents.TimeCreated

foreach ($startTime in $StartTimes) {
	$StopTime = $StopTimes | ? { $_ -gt $StartTime } | select -First 1
	if (-not $StopTime) {
		$StopTime = Get-Date	
	}
	$output = [ordered]@{
		'Startup'       = $StartTime
		'Shutdown'      = $StopTime
		'Uptime (Days)' = [math]::Round((New-TimeSpan -Start $StartTime -End $StopTime).TotalDays, 2)
		'Uptime (Min)'  = [math]::Round((New-TimeSpan -Start $StartTime -End $StopTime).TotalMinutes, 2)
	}
	[pscustomobject]$output
	
}
