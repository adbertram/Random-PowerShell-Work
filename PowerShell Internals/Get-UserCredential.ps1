#region function Get-UserCredential
function Get-UserCredential
{
	<#
		.SYNOPSIS
			Get-UserCredential provides a way to get a username and password from a normal "user".  The user can provide their
			own credential.  If not, it then prompts the user for their locally logged on username and returns a credential object.
	
		.PARAMETER Credential
			A pscredential object to output.
	#>
	
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
	)
	try
	{
		if (-not $PSBoundParameters.ContainsKey('Credential')) {
			if ((Get-KeystoreDefaultCertificate) -isnot 'System.Security.Cryptography.X509Certificates.X509Certificate2')
			{
				$Credential = Get-Credential -UserName (whoami) -Message 'Cannot find a suitable credential. Please input your password to use.'
			}
			else
			{
				$Credential = Get-KeyStoreCredential -Name 'svcOrchestrator'
			}
		}
		$Credential
	}
	catch
	{
		$PSCmdlet.ThrowTerminatingError($_)
	}
}
#endregion function Get-UserCredential