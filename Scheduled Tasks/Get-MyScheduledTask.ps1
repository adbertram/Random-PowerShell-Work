#Requires -Version 4

<#
.SYNOPSIS
	This script finds all scheduled tasks registered on a local computer.  It outputs the author of the scheduled task
	and the creation date.  This is useful in malware detection when malware might create a scheduled task in the 
	background without anyone knowing.
.NOTES
	Created on: 	5/7/2015
	Created by: 	Adam Bertram
	Filename:		Get-MyScheduledTask			
.EXAMPLE
	PS> Get-MyScheduledTask.ps1 | Where-Object {$_.CreationDate -lt (Get-Date).AddDays(-1)}

	This example will find all scheduled tasks that were created within the last day.
.EXAMPLE
	PS> Get-MyScheduledTask.ps1 | Where-Object {($_.Author -notmatch 'Microsoft') -and $_.Author}

	This example will find all scheduled tasks that are non-default.  It removes all scheduled tasks that have an author with
	the word 'Microsoft' in it or has a null value for the author	
#>
[CmdletBinding()]
[OutputType('Selected.Microsoft.Management.Infrastructure.CimInstance')]
param ()
process {
	try {
		Get-ScheduledTask | Select-Object TaskName,Author, @{ 'n' = 'CreationDate'; 'e' = { [datetime]$_.Date } }
	} catch {
		Write-Error "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
	}
}