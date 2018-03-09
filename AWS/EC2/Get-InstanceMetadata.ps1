function Get-EC2InstanceMetadata
{
	<#	
	.SYNOPSIS
		This function queries AWS's URL to gather instance meta-data. This function is meant to be executed
		from a EC2 instance as the URI that exposes the metadata is not available elsewhere.
	.EXAMPLE
		PS> Get-EC2InstanceMetadata -Path 'public-hostname'
	
		This example would query the URL http://169.254.169.254/latest/meta-data/public-hostname and return the page's result.
	
	.PARAMETER Path
		The URL path to the metadata item you'd like to retrieve.
	
	.PARAMETER BaseUri
		The URI that Amazon publishes to expose instance metadata.
	#>
	[CmdletBinding()]
	[OutputType('System.Management.Automation.PSCustomObject')]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Path,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$BaseUri = 'http://169.254.169.254/latest/meta-data'
	)
	
	$Uri = "$BaseUri/$Path"
	Write-Verbose -Message "Invoking HTTP request for URI [$($Uri)]"
	$result = Invoke-WebRequest -Uri $Uri
	if ($result.StatusCode -ne 200)
	{
		throw "The HTTP request failed when looking up URI [$Uri]"
	}
	
	$result.Content.Split("`n")
}