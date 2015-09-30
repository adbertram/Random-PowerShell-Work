function Get-ChefConfigItem
{
	<#
		.SYNOPSIS
			This function parses the appropriate config file path (either Chef solo or client) and returns a set of objects.
	
		.PARAMETER Name
			Optionally, if you'd like to only see a single item in the config file you can use this parameter. Else, it will return
			all configuration items.
	#>
	
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	## Read the config file from disk
	$line = Get-Content -Path $ConfigFilePath | where { $_ -match $Name }
	if ($line)
	{
		foreach ($l in $line)
		{
			[pscustomobject]@{
				'Name' = $l.Split(' ')[0].Trim()
				'Value' = ($l.Split(' ')[-1] -replace "'").Trim()
			}
		}
	}
}

function Set-ChefConfigItem
{
	<#
		.SYNOPSIS
			This changes an existing configuration item in the chef solo or client configuration file.
	
		.PARAMETER Name
			You must specify a configuration item name to be changed.
	
		.PARAMETER Value
			You must specify a value of the configuration item to be changed.
	
		.EXAMPLE
			PS> Get-ChefConfigItem -Name log_level | Set-ChefConfigItem -Value 'info'
	
			This finds the current value of log_level and changes it to 'info' in the configuration file.	
	#>
	
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Value
		
	)
	## Create an array that contains each line of the configuration file that does not match the name
	$config = Get-Content -Path $ConfigFilePath | where { $_ -notmatch $Name }
	## Add the name and value in the format Name 'Value' to the end of the file
	$config += "$Name '$Value'"
	## Overwrite the existing config file with the new one.
	$config | Out-File $ConfigFilePath
}