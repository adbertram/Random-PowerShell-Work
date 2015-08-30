<#
.SYNOPSIS
	This script finds a WMI class by name in all namespaces on a compputer
.NOTES
	Created on: 	1/29/15
	Created by: 	Adam Bertram
	Filename:		Find-WmiClass.ps1
.EXAMPLE
	PS> Find-WmiClas.ps1 -ClassSearchString 'MatchThis' -Computername 'MYSERVER'

	This example will recursively query all WMI namespaces on the computer MYSERVER and attempt to find any
	CIM class that is the exact value of 'MatchThis'
.EXAMPLE
	PS> Find-WmiClas.ps1 -Computername 'MYSERVER'

	This example will recursively query all WMI namespaces on the computer MYSERVER and return all WMI classes
.EXAMPLE
	PS> Find-WmiClas.ps1 -ClassSearchString '*Wildcard*' -Computername 'MYSERVER'

	This example will recursively query all WMI namespaces on the computer MYSERVER and and attempt to find any
	CIM class that matches the value of '*WildCard*'
.PARAMETER PARAM1
 	
.PARAMETER PARAM2
	
#>
[CmdletBinding()]
param (
	[string]$ClassSearchString = '*',
	[string]$PropertySearchString = '*',
	[string]$Namespace = 'root',
	[ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1 })]
	[string]$Computername = 'localhost'
)

begin {
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	Set-StrictMode -Version Latest
	function Get-Namespace ($Namespace = 'root',[switch]$Recursive) {
		try {
			$Ns = Get-WmiObject -Computername $Computername -Namespace $Namespace -Class '__Namespace' -ea 'SilentlyContinue' | Select-Object -ExpandProperty Name
			if (!$Ns) {
				$false
			} else {
				foreach ($n in $Ns) {
					try {
						$Ns = "$Namespace\$n"
						if ($Recursive.IsPresent) {
							Get-Namespace -Namespace $Ns -Recursive
						} else {
							$Ns
						}
					} catch {
						Write-Error $_.Exception.Message
					}
				}
			}
		} catch {
			Write-Error $_.Exception.Message
			$false
		}
	}
}

process {
	$Namespaces = @()
	$Namespaces += Get-Namespace -Namespace $Namespace -Recursive;
	if ($Namespaces) {
		$Namespaces += $Namespace
		foreach ($Ns in $Namespaces) {
			try {
				$Classes = Get-CimClass -Computername $Computername -Namespace $Ns -ClassName $ClassSearchString -ea SilentlyContinue
				if ($Classes) {
					foreach ($Class in $Classes) {
						if ($PropertySearchString -eq '*') {
							[pscustomobject]@{ 'Computername' = $Computername; 'Namespace' = $Ns; 'Class' = $Class.CimClassName }
						} else {
							$Properties = $Class.CimClassProperties
							if ($Properties.Count -gt 0) {
								foreach ($Prop in ($Properties.Name | where { $_ -like $PropertySearchString })) {
									try {
										$Value = Get-Wmiobject -Computername $Computername -Namespace $Ns -Class $Class.CimClassName -ea silentlycontinue | select -ExpandProperty $Prop
										[pscustomobject]@{ 'Computername' = $Computername; 'Namespace' = $Ns; 'Class' = $Class.CimClassName; 'Property' = $Prop; 'Value' = $Value }
									} catch {
										
									}
								}
							}
							[pscustomobject]@{ 'Computername' = $Computername; 'Namespace' = $Ns; 'Class' = $Class.CimClassName; }
						}
					}
				}
			} catch {
				Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
			}
		}
	}
}