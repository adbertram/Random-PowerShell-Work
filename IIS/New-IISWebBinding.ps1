<#
	.SYNOPSIS
		This script automates the act of creating an IIS binding on a website. It takes New-WebBinding to another level because
		it also supports HTTPS bindings. These bindings requires attaching a certificate as well. Using this script allows you
		to pass a certificate as well to create the web binding and attach a certificate at the same time.

		Becauuse New-WebBinding also does not support remote computers, by using this script you can run this on remote computers
		using PS remoting as well.

	.PARAMETER ComputerName
		The IIS server hosting the website you'd like to create a new binding on.

	.PARAMETER WebsiteName
		The name of the webiste to add the binding to.

	.PARAMETER Protocol
		The protocol (either http or https) that the binding will apply to.

	.PARAMETER Port
		The port in which the binding will be applied to.

	.PARAMETER IPAddress
		The listening IP address.  This defaults to all listening IPs by using 0.0.0.0.

	.PARAMETER Certificate
		A X.509 certificate that must exist on the remote computer in a LocalMachine store that will be applied if the binding
		is SSL.

	.PARAMETER Credential
		If you need to authenticate a with a different username/password, use this.

#>

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
	$PSCmdlet.ThrowTerminatingError($_)
}