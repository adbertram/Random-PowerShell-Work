#Requires -Version 4 -Module ActiveDirectory

function Get-DisabledGpo
{
	<#
	.SYNOPSIS
		This function queries the Active Directory domain the initiaing computer is in for all GPOs that either have
		their computer, user or both settings disabled. This is common when atatempting to find GPOs that can be removed.
	
	.EXAMPLE
		PS> Get-DisabledGpo
	
		Name           DisabledSettingsCategory
		----           ------------------------
		GPO1        	AllSetting
		GPO1     		ComputerSetting
		GPO3 			UserSetting
	#>
	[OutputType([pscustomobject])]
	[CmdletBinding()]
	param ()
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			@(Get-GPO -All).where({ $_.GpoStatus -like '*Disabled' }).foreach({
					[pscustomobject]@{
						Name = $_.DisplayName
						DisabledSettingsCategory = ([string]$_.GpoStatus).TrimEnd('Disabled')
					}	
				})
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}