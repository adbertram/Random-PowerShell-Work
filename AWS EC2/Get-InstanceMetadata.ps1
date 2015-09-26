function Get-InstanceMetadata
{
	<#	
	.SYNOPSIS
		This function queries AWS's URL and recursively gathers all of the instance meta-data. This function is meant to be executed
		from a EC2 instance as the URI that exposes the metadata is not available elsewhere.
	.EXAMPLE
		PS> Get-InstanceMetadata
	
		This example would send a HTTP request to http://169.254.169.254/latest/meta-data, gather the results, build child URIs
		from the results and recursively query those URIs until each branch is finished.
			
	.PARAMETER Uri
		The URI that Amazon publishes to expose instance metadata.
		
	.INPUTS
		None. You cannot pipe objects to Get-InstanceMetadata.

	.OUTPUTS
		System.Management.Automation.PSCustomObject.
	#>
	[CmdletBinding()]
	[OutputType('System.Management.Automation.PSCustomObject')]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Uri = 'http://169.254.169.254/latest/meta-data'
	)
	
	try
	{
		Write-Verbose -Message "Invoking HTTP request for URI [$($Uri)]"
		$result = Invoke-WebRequest -Uri $Uri
		if ($result.StatusCode -ne 200)
		{
			throw "The HTTP request failed when looking up URI [$Uri]"
		}
		
		$childMeta = $result.Content.Split("`n")	
		
		foreach ($c in $childMeta)
		{
			try {
				$childUri = "$Uri/$c"
				if ($c -notlike "*$($Uri | Split-Path -Leaf)*")
				{
					[pscustomobject]@{
						'Name' = ($Uri | Split-Path -Leaf)
						'Value' = $c
					}
					Get-InstanceMetadata -Uri $childUri
				}
			}
			catch 
			{
				Write-Warning $_.Exception.Message
			}
		}
	}
	catch
	{
		$PSCmdlet.ThrowTerminatingError($_)
	}
}

Get-InstanceMetadata