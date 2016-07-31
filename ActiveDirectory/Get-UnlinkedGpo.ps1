#Requires -Version 4 -Module ActiveDirectory

function Get-UnlinkedGpo
{
	<#
	.SYNOPSIS
		This function queries the Active Directory domain the initiaing computer is in for all GPOs that do not have a 
		link to an object. This is common when atatempting to find GPOs that can be removed.
	
	.EXAMPLE
		PS> Get-UnlinkedGpo
	
		Comment-Example
		
	.PARAMETER Param1
		A mandatory  paramType1 parameter representing ...
	
	#>
	[CmdletBinding()]
	param
	(
		
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$gpoReport = [xml](Get-GPOReport -All -ReportType XML)
			@($gpoReport.GPOs.GPO).where({ -not $_.LinksTo }).foreach({
					[pscustomobject]@{ Name = $_.Name }	
				})
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}