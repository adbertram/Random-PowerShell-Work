<#
.SYNOPSIS
	Changes the account a service runs under    
.NOTES
	 Created on:   	11/28/2014
	 Created by:   	Adam Bertram
	 Filename:     	Set-ServiceAccount.ps1
.EXAMPLE
    PS> .\Set-ServiceAccount.ps1 -ServiceName 'snmp' -Computername 'COMPUTER1','COMPUTER2' -Username someuser -Password password12

	This example changes the account the service snmp runs under to someuser on the computers COMPUTER1 and COMPUTER2
.PARAMETER ServiceName
 	One or more service names
.PARAMETER Computername
	One or more remote computer names.  This script defaults to the local computer.
.PARAMETER Username
	The username to change on the service
.PARAMETER Password
	The password of the username
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
	[string[]]$ServiceName,
	[Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
	[ValidateScript({Test-Connection -ComputerName $_ -Quiet -Count 1 })]
	[string[]]$Computername = 'localhost',
	[Parameter(Mandatory)]
	[string]$Username,
	[Parameter(Mandatory)]
	[string]$Password
)

process {
	foreach ($Computer in $Computername) {
		foreach ($Service in $ServiceName) {
			try {
				Write-Verbose -Message "Changing service '$Service' on the computer '$Computer'"
				$s = Get-WmiObject -ComputerName $Computer -Class Win32_Service -Filter "Name = '$Service'"
				if (!$s) {
					throw "The service '$Service' does not exist"
				}
				$s.Change($null, $null, $null, $null, $null, $null, $Username, $Password) | Out-Null
				$s | Restart-Service -Force
			} catch {
				Write-Error -Message "Error: Computer: $Computer - Service: $Service - Error: $($_.Exception.Message)"	
			}
		}
	}
}