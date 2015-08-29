#Requires -Module ActiveDirectory
#Requires -Version 4

<#	
.SYNOPSIS
	This script finds all logon, logoff and total session times of all users on all computers in an Active Directory organizational unit.

	The appropriate audit policies must be enabled first because the appropriate event IDs will show up.
.EXAMPLE
	PS> Get-ActiveDirectoryUserActivity.ps1 -OrganizationalUnit 'OU=My Desktops,DC=lab,DC=local'

		This example will query the security event logs of all computers in the AD OU 'My Desktops' and find
		all instances of the events IDs 4624 and 4634 in the security event logs. It will then generate a friendly
		report showing the user name, time generated, and total session time for each user.
		
.PARAMETER OrganizationalUnit
	The distinguisned name of the AD organizational unit that you'd like to query the security event log of computers.

.PARAMETER ComputerName
	If you don't have Active Directory and would just like to specify computer names manually use this parameter

.INPUTS
	None. You cannot pipe objects to Get-ActiveDirectoryUserActivity.ps1.

.OUTPUTS
	None. If successful, this script does not output anything.
#>
[CmdletBinding(DefaultParameterSetName = 'ComputerName')]
param
(
	[Parameter(Mandatory,ParameterSetName = 'OU')]
	[ValidateNotNullOrEmpty()]
	[ValidatePattern('^OU\=')]
	[string]$OrganizationalUnit,

	[Parameter(ParameterSetName = 'ComputerName')]
	[ValidateNotNullOrEmpty()]
	[string[]]$ComputerName = 'localhost'
	

)
process {
	try
	{
		
		#region Gather all applicable computers
		if ($PSCmdlet.ParameterSetName -eq 'OU')
		{
			$Computers = (Get-ADComputer -SearchBase $OrganizationalUnit -Filter *).Name
		}
		else
		{
			$Computers = $ComputerName	
		}
		if (-not $Computers)
		{
			throw "No computers found"
		}
		#endregion
		
		$Ids = @{
			'Logon' = 4624
			'Logoff' = 4634
		}
		
		#region Query the computers' event logs
		foreach ($Computer in $Computers)
		{
			$evtParams = @{
				'ComputerName' = $Computer
				'Oldest' = $true
			}
			
			Write-Verbose -Message "Getting all interesting events for computer [$($Computer)]. This may take a bit..."
			$MessageFilter = {
				$_.Message -match 'Logon Type:\s+2' -and
				$_.Message -match 'Logon Process:\s+User32'
				$_.Message -notmatch 'Account Name:\s+\w+\$$'
			}
			$Events = (Get-WinEvent @evtParams -FilterHashtable @{ 'LogName' = 'Security'; 'ID' = $Ids.Logon,$Ids.Logoff } | select -First 5000).where($MessageFilter)
			$Events.foreach({
				if ($_.Id -eq $Ids.Logon)
				{
					$LogonTime = $_.TimeCreated
					Write-Verbose -Message "Logon time is [$($LogonTime)]"
					$Username = [regex]::Matches($_.Message, 'Account Name:\s+(.*)\n').Groups[1].Value.Trim()
					Write-Verbose -Message "Username is [$($Username)]"
					$LogonId = [regex]::Matches($_.Message, 'Logon ID:\s+(.*)\n').Groups[3].Value.Trim()
					Write-Verbose -Message "Logon ID is [$($LogonId)]"
					$LogoffEvent = $Events.where({
						$LogoffId = [regex]::Matches($_.Message, 'Logon ID:\s+(.*)\n').Groups[1].Value.Trim()
						$_.TimeCreated -gt $LogonTime -and $LogoffId -eq $LogonId
					}) | select -first 1
					if (-not $LogoffEvent)
					{
						Write-Warning -Message "The matching logoff event could not be found for session ID [$($LogonId)]"
					}
					else
					{
						Write-Verbose -Message "Logoff time is $($LogffEvent.TimeCreated)"
						[pscustomobject]@{
							'ComputerName' = $_.MachineName
							'Username' = $Username
							'SessionId' = $LogonId
							'LogonTime' = $LogonTime
							'LogoffTime' = $LogoffEvent.TimeCreated
							'Session Time (Days)' = [math]::Round((New-TimeSpan -Start $LogonTime -End $LogoffEvent.TimeCreated).TotalDays, 2)
						}
					}
				}
			})
		}
		#endregion

	} catch {
		Write-Error $_.Exception.Message
	}
}