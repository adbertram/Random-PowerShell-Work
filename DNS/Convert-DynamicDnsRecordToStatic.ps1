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
	[string]$Computername = 'DEFAULTVALUE'
)

begin {
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	Set-StrictMode -Version Latest
	try {
		
	} catch {
		Write-Error $_.Exception.Message
	}
}

process {
	try {
		Get-DnsServerResourceRecord -ComputerName dc01 -ZoneName domain.com | where { ($_.HostName -match '^U.*XA65') -and ($_.Hostname -notmatch 'VM') -and ($_.Hostname -notmatch '.domain.com$') } | select @{ n = 'Hostname'; e = { $_.Hostname } }, @{n = 'IpAddres	s'; e = { $_.RecordData.IPv4Address.IPAddressToString } }
		$CitrixRecords | select -Skip 1 | % { try { Add-DnsServerResourceRecord -ZoneName domain.com -ComputerName dc01 -IPv4Address $_.IpAddress -Name $_.Hostname -A } catch { } }
		$CitrixRecords | % { Get-DnsServerResourceRecord -ComputerName dc01 -Name $_.Hostname -RRType A -ZoneName domain.com }
		
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