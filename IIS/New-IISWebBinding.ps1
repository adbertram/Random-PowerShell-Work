function New-IISWebBinding
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$WebsiteName,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('http', 'https')]
		[string]$Protocol,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[int]$Port,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ipaddress]$IPAddress = '0.0.0.0', ## Default to accepting on all bound IPs
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
	)
	process
	{
		try
		{
			$IPAddress = $IPAddress.IPAddressToString
			$iisIp = $IPAddress
			if ($IPAddress -eq '0.0.0.0')
			{
				$iisIp = '*'
			}
			
			$sb = {
				Import-Module WebAdministration
				if (Get-WebBinding -Protocol $using:Protocol -Port $Port)
				{
					throw "There's already a binding with the protocol of [$($using:Protocol)] and port [$($using:Port)]"
				}
				New-WebBinding -Name $using:WebsiteName -IP $using:iisIp -Port $using:Port -Protocol $using:Protocol
				if ($using:Protocol -eq 'https')
				{
					$using:Certificate | New-Item "IIS:\SSLBindings\$using:IPAddress!$using:Port"
				}
			}
			
			$icmParams = @{
				'ComputerName' = $ComputerName
				'ScriptBlock' = $sb
			}
			if ($PSBoundParameters.ContainsKey('Credential'))
			{
				$icmParams.Credential = $Credential
			}
			Invoke-Command @icmParams
		}
		catch
		{
			throw $_
		}
	}
}