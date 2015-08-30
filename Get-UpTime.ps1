<#
.SYNOPSIS
	This script gets the total time a computer has been up for.
.DESCRIPTION
	This script queries the Win32_OperatingSystem WMI class to retrieve the 
	LastBootupTime and output a datetime object containing the specific
	time the computer has been up for.
.NOTES
	Created on: 	6/9/2014
	Created by: 	Adam Bertram
	Filename:		Get-UpTime.ps1
.EXAMPLE
	.\Get-Uptime.ps1 -Computername 'COMPUTER'
	
.PARAMETER Computername
 	This is the name of the computer you'd like to query
#>
[CmdletBinding()]
param (
	[Parameter(ValueFromPipeline,
		ValueFromPipelineByPropertyName)]
	[string]$Computername = 'localhost'
)

begin {
	Set-StrictMode -Version Latest
}

process {
	try {
		$WmiResult = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName
		$LastBoot = $WmiResult.ConvertToDateTime($WmiResult.LastBootupTime)
		$ObjParams = [ordered]@{'Computername' = $Computername }
		((Get-Date) - $LastBoot).psobject.properties | foreach { $ObjParams[$_.Name] = $_.Value }
		New-Object -TypeName PSObject -Property $ObjParams
	} catch {
		Write-Error $_.Exception.Message	
	}
}

end {
	
}