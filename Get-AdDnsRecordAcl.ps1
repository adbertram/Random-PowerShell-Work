#Requires -Module ActiveDirectory

<#
.SYNOPSIS
	This script retrieves the ACL from an Active Directory-integrated DNS record
.NOTES
	Created on: 	8/5/2014
	Created by: 	Adam Bertram
	Filename:		Get-AdDnsRecordAcl.ps1
.EXAMPLE
	PS> .\Get-AdDnsRecordAcl.ps1 -Hostname 'SERVER1'
	
	This example retrieves the ACL for the hostname SERVER1 inside the current forest-integrated
	DNS zone inside Active Directory
.EXAMPLE
	PS> .\Get-AdDnsRecordAcl.ps1 -Hostname 'SERVER1' -AdDnsIntegration 'Domain'
	
	This example retrieves the ACL for the hostname SERVER1 inside the current domain-integrated
	DNS zone inside Active Directory
.PARAMETER Hostname
	The hostname for the DNS record you'd like to see
.PARAMETER DomainName
 	The Active Directory domain name.  This defaults to the current domain
.PARAMETER AdDnsIntegration
	This is the DNS integration type.  This can either be Forest and Domain.

#>
[CmdletBinding()]
[OutputType('System.DirectoryServices.ActiveDirectorySecurity')]
param (
	[Parameter(Mandatory,
			   ValueFromPipeline,
			   ValueFromPipelineByPropertyName)]
	[string[]]$Hostname,
	[Parameter(ValueFromPipeline,
			   ValueFromPipelineByPropertyName)]
	[string]$DomainName = (Get-ADDomain).Forest,
	[ValidateSet('Forest','Domain')]
	[Parameter(ValueFromPipeline,
			   ValueFromPipelineByPropertyName)]
	[string[]]$AdDnsIntegration = 'Forest'
)

begin {
	$ErrorActionPreference = 'Stop'
	Set-StrictMode -Version Latest
}

process {
	try {
		$Path = "AD:\DC=$DomainName,CN=MicrosoftDNS,DC=$AdDnsIntegration`DnsZones,DC=$($DomainName.Split('.') -join ',DC=')"
		foreach ($Record in (Get-ChildItem -Path $Path)) {
			if ($Hostname -contains $Record.Name) {
				Get-Acl -Path "ActiveDirectory:://RootDSE/$($Record.DistinguishedName)"
			}
		}
	} catch {
		Write-Error $_.Exception.Message	
	}
}