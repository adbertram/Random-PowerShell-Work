#Requires -Module DhcpServer

<#
.SYNOPSIS
	This script finds all DHCP servers in Active Directory, all scopes on all DHCP servers
	and outputs all leases in all of those scopes
.NOTES
	Created on: 	12/10/2014
	Created by: 	Adam Bertram
	Filename:		Get-DhcpLeasesInDomain.ps1
.EXAMPLE
	PS> .\Get-DhcpLeasesInDomain.ps1
	
#>
[CmdletBinding()]
[OutputType('Selected.Microsoft.Management.Infrastructure.CimInstance')]
param ()

begin {
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	Set-StrictMode -Version Latest
}

process {
	try {
		$DhcpServers = Get-DhcpServerInDC | where { Test-Connection -ComputerName $_.DnsName -Quiet -Count 1 } | Select-Object -ExpandProperty DnsName
		foreach ($DhcpServer in $DhcpServers) {
			try {
				try { $Scopes = Get-DhcpServerv4Scope -ComputerName $DhcpServer	} catch {Write-Warning -Message "Error: $($_.Exception.Message)"}
				foreach ($Scope in $Scopes) {
					try { Get-DhcpServerv4Lease -ComputerName $DhcpServer -ScopeId $Scope.ScopeId | Select-Object * -ExcludeProperty 'Cim*' } catch { Write-Warning -Message "Error: $($_.Exception.Message)" }
			}
		} catch {
			Write-Error -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
		}
	}
} catch {
	Write-Error -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
}
}