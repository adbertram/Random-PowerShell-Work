function Get-VMError
{
	<#
		.SYNOPSIS
			This function queries a Hyper-V host for any errors that have been recorded in any
			HyperV event source.
	
		.PARAMETER Server
			The Hyper-V host that the VM is running on.
	
		.PARAMETER Credential
			A PSCredential object to use for alternative credentials.
	
		.EXAMPLE
			PS> Get-VMError -Server SERVER1
	
			This example queries all Hyper-V event sources on the host SERVER1
	#>
	
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias('ComputerName')]
		[string]$Server,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
	)
	
		$whereFilter = { $_.TimeCreated -gt (Get-Date).AddDays(-1) -and ($_.LevelDisplayName -in @('Error', 'Critical')) }
		
		$properties = @('Machinename', 'TimeCreated', 'LevelDisplayName', 'Message')
		$winParams = @{
			'ComputerName' = $Server
			'LogName' = 'Microsoft-Windows-Hyper-V-*'
		}
		if ($PSBoundParameters.ContainsKey('Credential')) {
			$winParams.Credential = $Credential
		}
		Get-WinEvent @winParams | where -FilterScript $whereFilter | Select $properties
}