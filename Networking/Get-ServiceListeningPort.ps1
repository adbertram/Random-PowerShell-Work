<#
.SYNOPSIS

.NOTES
	Created on: 	8/22/2014
	Created by: 	Adam Bertram
	Filename:		
	Credits:		
	Requirements:	
	Todos:				
.EXAMPLE
	
.EXAMPLE
	
.PARAMETER PARAM1
 	
.PARAMETER PARAM2
	
#>
[CmdletBinding(DefaultParameterSetName = 'name')]
[OutputType('System.Management.Automation.PSCustomObject')]
param (
	[Parameter(ParameterSetName = 'name',
		Mandatory,
		ValueFromPipeline,
		ValueFromPipelineByPropertyName)]
	[ValidateSet("Tom","Dick","Jane")]
	[ValidateRange(21,65)]
	[ValidateScript({Test-Path $_ -PathType 'Container'})] 
	[ValidateNotNullOrEmpty()]
	[ValidateCount(1,5)]
	[ValidateLength(1,10)]
	[ValidatePattern()]
	[string]$Computername = 'localhost'
)

begin {
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	Set-StrictMode -Version Latest
}

process {
	try {
		$ServiceExes = Get-WmiObject -ComputerName $Computername -Property DisplayName, PathName
		
	} catch {
		Write-Error $_.Exception.Message	
	}
}

end {
	try {
		
	} catch {
		Write-Error $_.Exception.Message
	}
}