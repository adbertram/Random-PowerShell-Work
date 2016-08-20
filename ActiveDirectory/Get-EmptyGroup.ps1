#Requires -Version 4 -Module ActiveDirectory

function Get-EmptyGroup
{
	<#
	.SYNOPSIS
		This function queries the Active Directory domain the initiaing computer is in for all groups that have no members. 
		This is common when attempting to find groups that can be removed.
	
		This does not include default AD groups like Domain Computers, Domain Users, etc.
	
	.EXAMPLE
		PS> Get-EmptyGroup
	
		
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
			@(Get-ADGroup -Filter * -Properties isCriticalSystemObject,Members).where({ (-not $_.isCriticalSystemObject) -and ($_.Members.Count -eq 0) })
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}