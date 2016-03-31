function Enable-DynamicDnsRegistration
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
	)

	$icmParams = @{
		'ComputerName' = $ComputerName
	}
	if ($PSBoundParameters.ContainsKey('Credential'))
	{
		$icmParams.Credential = $Credential
	}
	
	$icmParams.ScriptBlock = {
		$VerbosePreference = $using:VerbosePreference
		Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled='true'" | Where-Object { $_.DefaultIPGateway.Count -gt 0 } | ForEach-Object {
			Write-Verbose -Message "Setting DDNS registration..."
			$result = $_.SetDynamicDNSRegistration($true)
			if ($result.ReturnValue -ne 0)
			{
				throw "Failed to set DDNS registration on with return code [$($result.ReturnValue)]"
			}
		}
	}
	
	Invoke-Command @icmParams
}