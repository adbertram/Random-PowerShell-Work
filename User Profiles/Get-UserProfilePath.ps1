function Get-UserProfilePath
{
	<#
	.SYNOPSIS
		This function find the folder path of a user profile based off of a number of different criteria.  If no criteria is
		used, it will return all user profile paths.
	.EXAMPLE
		PS> .\Get-UserProfilePath -Sid 'S-1-5-21-350904792-1544561288-1862953342-32237'
	
		This example finds the user profile path based on the user's SID
	.EXAMPLE
		PS> .\Get-UserProfilePath -Username 'bob'
	
		This example finds the user profile path based on the username
	.PARAMETER Sid
	 	The user SID
	.PARAMETER Username
		The username
	#>
	[OutputType([string])]
	[CmdletBinding(DefaultParameterSetName = 'None')]
	param (
		[Parameter(ParameterSetName = 'SID')]
		[string]$Sid,
		
		[Parameter(ParameterSetName = 'Username')]
		[string]$Username
	)
	
	process
	{
		try
		{
			if ($Sid)
			{
				$WhereBlock = { $_.PSChildName -eq $Sid }
			}
			elseif ($Username)
			{
				$WhereBlock = { $_.GetValue('ProfileImagePath').Split('\')[-1] -eq $Username }
			}
			else
			{
				$WhereBlock = { $null -ne $_.PSChildName }
			}
			Get-ChildItem 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList' | Where-Object $WhereBlock | ForEach-Object { $_.GetValue('ProfileImagePath') }
		}
		catch
		{
			Write-Log -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" -LogLevel '3'
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}