function Get-LoggedOnUser
{
	<#
	.SYNOPSIS
		This function queries CIM on the local or a remote computer and returns the user (local or Active Directory) that is currently
		logged on.
	
	.EXAMPLE
		PS> Get-LoggedOnUser
	
		This would query the local computer and return the user logged on.
		
	.EXAMPLE
		PS> Get-LoggedOnUser -ComputerName CLIENT
	
		This would query the remote computer CLIENT and return the user logged on.
	
	.PARAMETER ComputerName
		The name of the computer you'd like to run this function against.
	
	#>
	[OutputType([pscustomobject])]
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1 })]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName = $env:COMPUTERNAME
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			foreach ($comp in $ComputerName)
			{
				$output = @{ 'ComputerName' = $comp }
				$output.UserName = (Get-WmiObject -Class win32_computersystem -ComputerName $comp).UserName
				[PSCustomObject]$output
			}
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}