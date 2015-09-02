function Get-MyCimInstance {
	<#
	.SYNOPSIS
		This function provides a way to query CIM and WinRM but with an automatic failover to DCOM.
	.PARAMETER Computername
		The name of the computer to query
	.PARAMETER Class
		The WMI class
	.PARAMETER Namespace
		The WMI namespace
	.PARAMETER Filter
		The WQL filter
	.PARAMETER Property
		If only a single property is needed in the output, specify that here.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory, ValueFromPipeline)]
		[string[]]$Computername,
		[Parameter(Mandatory)]
		[Alias('ClassName')]
		[string]$Class,
		[Parameter()]
		[string]$Namespace,
		[Parameter()]
		[string]$Filter,
		[Parameter()]
		[string]$Property
	)
	process {
		## We're depending on using the ErrorVariabl on a per cmdlet basis.
		$ErrorActionBefore = $ErrorActionPreference
		$ErrorActionPreference = 'SilentlyContinue'
		foreach ($Computer in $Computername) {
			try {
				## Build the parameters for the WinRm query
				$Params = @{ 'Computername' = $Computer; 'Class' = $Class; 'ErrorAction' = 'SilentlyContinue' }
				if ($PsBoundParameters.Property) {
					$Params.Property = $PsBoundParameters.Property
				}
				if ($Filter) {
					$Params.Filter = $Filter
				}
				if ($Namespace) {
					$Params.Namespace = $Namespace
				}
				Write-Verbose "Attempting to query '$Computer' via WinRM"
				$Result = Get-CimInstance @Params -ev WinRmError
				if ($WinRmError) {
					Write-Verbose "Failed to query $Computer via WinRM. Attempting with DCOM"
					## Build parameters for the DCOM query
					$GwmiParams = @{ 'Computername' = $Computer; 'Class' = $Class; 'ErrorAction' = 'SilentlyContinue' }
					if ($Filter) {
						$GwmiParams.Filter = $Filter
					}
					if ($Namespace) {
						$GwmiParams.Namespace = $Namespace
					}
					if ($Property) {
						$GwmiParams.Property = $Property
					}
					$Result = Get-WmiObject @GwmiParams -ev DcomError
					if ($DcomError) {
						throw 'Failed query via DCOM. Giving up.'
					} else {
						$ErrorActionPreference = $ErrorActionBefore
						$Result
					}
				} else {
					$ErrorActionPreference = $ErrorActionBefore
					$Result
				}
			} catch {
				$ErrorActionPreference = $ErrorActionBefore
				Write-Error "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
			}
		}
		
	}
}