#Requires -Version 4

function Test-PsRemoting {
	<#
	.SYNOPSIS
	    This function tests if PS remoting is enabled on a remote computer and (if used) will attempt
		to connect with a local username and password.
	.PARAMETER Computername
	 	The remote computer name
	.PARAMETER LocalCredential
		An optional credential object representing the remote computer's local username and password
	.PARAMETER DomainCredential
		If the remote computer and the executing computer are both domain-joined, this is an optional 
		credential object representing a domain username and password to test against.  By default, it
		will test against the currently logged on user.
	#>
	[CmdletBinding(DefaultParameterSetName = 'None')]
	param (
		[Parameter(Mandatory,
				   ValueFromPipeline,
				   ValueFromPipelineByPropertyName)]
		[string[]]$Computername,
		[Parameter(Mandatory,ParameterSetName = 'LocalCredential')]
		[System.Management.Automation.PSCredential]$LocalCredential,
		[Parameter(Mandatory, ParameterSetName = 'DomainCredential')]
		[System.Management.Automation.PSCredential]$DomainCredential
	)
	process {
		foreach ($Computer in $Computername) {
			try {
				if (!$LocalCredential -and !$DomainCredential) {
					## Test remoting under the currently logged on user
					Invoke-Command -ComputerName $Computer -ScriptBlock { 1 }
					$true
				} elseif ($LocalCredential) { ## Test remoting with a local username and password
					
				} else { ## Test remoting with a domain username and password
					
				}
			} catch {
				[pscustomobject]@{ 'Computer' = $Computer; 'Result' = $false; 'Error' = $_.Exception.Message }
			}
		}
	}
}