#Requires -Module ActiveDirectory
#Requires -Version 4

<#	
.SYNOPSIS
	This script finds all logon, logoff and total active session times of all users on all computers specified. For this script
	to function as expected, the advanced AD policies; Audit Logon, Audit Logoff and Audit Other Logon/Logoff Events must be
	enabled and targeted to the appropriate computers via GPO.

.EXAMPLE
	
.PARAMETER ComputerName
	If you don't have Active Directory and would just like to specify computer names manually use this parameter

.INPUTS
	None. You cannot pipe objects to Get-ActiveDirectoryUserActivity.ps1.

.OUTPUTS
	None. If successful, this script does not output anything.
#>
[CmdletBinding()]
param
(
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string[]]$ComputerName = 'localhost'
	
)
begin
{
	function Get-EventLabel
	{
		param (
			[int]$EventId
		)
		$SessionEvents.where({ $_.ID -eq $EventId }).Label
	}	
}
process
{
	try
	{
		
		#region Defie all of the events to indicate session start or top
		$SessionEvents = @(
			@{ 'Label' = 'Logon'; 'LogName' = 'Security'; 'ID' = 4624 } ## Advanced Audit Policy --> Audit Logon
			@{ 'Label' = 'Logoff'; 'LogName' = 'Security'; 'ID' = 4647 } ## Advanced Audit Policy --> Audit Logoff
			@{ 'Label' = 'Startup'; 'LogName' = 'System'; 'ID' = 6005 }
			@{ 'Label' = 'Shutdown'; 'LogName' = 'System'; 'ID' = 6006 }
			@{ 'Label' = 'RdpSessionReconnect'; 'LogName' = 'Security'; 'ID' = 4778 } ## Advanced Audit Policy --> Audit Other Logon/Logoff Events
			@{ 'Label' = 'RdpSessionDisconnect'; 'LogName' = 'Security'; 'ID' = 4779 } ## Advanced Audit Policy --> Audit Other Logon/Logoff Events
			@{ 'Label' = 'Locked'; 'LogName' = 'Security'; 'ID' = 4800 } ## Advanced Audit Policy --> Audit Other Logon/Logoff Events
			@{ 'Label' = 'Unlocked'; 'LogName' = 'Security'; 'ID' = 4801 } ## Advanced Audit Policy --> Audit Other Logon/Logoff Events
		)
		
		$SessionStartIds = ($SessionEvents | where { $_.Label -in 'Logon', 'RdpSessionReconnect', 'Unlocked' }).ID
		## Startup ID will be used for events where the computer was powered off abruptly or crashes --not a great measurement
		$SessionStopIds = ($SessionEvents | where { $_.Label -in 'Logoff', 'Startup', 'Shutdown', 'RdpSessionDisconnect', 'Locked' }).ID
		#endregion
		

		$evtParams = @{
			'FilterHashTable' = @{
				'LogName' = $SessionEvents.LogName | select -Unique
				'ID' = $SessionEvents.ID
			}
		}
		
		foreach ($computer in $ComputerName)
		{
			try
			{
				Write-Verbose -Message "Gathering up all interesting events on computer [$($computer)]. This may take a bit..."
				$Events = Get-WinEvent @evtParams -ComputerName $computer -Oldest | where {
					## This is hackery but because no one event ID matches up to an interactive logon certain things have to be
					## filtered on to match the pattern.
					if ($_.Id -eq $SessionEvents.where({$_.Label -eq 'Logon'}).ID)
					{
						$xEvt = [xml]$_.ToXml()
						($xEvt.Event.EventData.Data | where { $_.Name -eq 'LogonType' }).'#text' -eq '2' -and
						($xEvt.Event.EventData.Data | where { $_.Name -eq 'LogonGuid' }).'#text' -ne '{00000000-0000-0000-0000-000000000000}' -and
						($xEvt.Event.EventData.Data | where { $_.Name -eq 'ProcessName' }).'#text' -match 'winlogon\.exe'
					}
					else
					{
						$true	
					}
				}
				
				Write-Verbose -Message "Found [$($Events.Count)] events to look through"
				
				$Events.foreach({
					if ($_.Id -in $SessionStartIds)
					{
						$Id = $_.Id
						Write-Verbose -Message "Session start event ID is [$($Id)]"
						$xEvt = [xml]$_.ToXml()
						$Username = ($xEvt.Event.EventData.Data | where { $_.Name -eq 'SubjectUserName' }).'#text'
						$LogonId = ($xEvt.Event.EventData.Data | where { $_.Name -eq 'TargetLogonId' }).'#text'
						Write-Verbose -Message "Session start logon ID is [$($LogonId)]"
						$LogonTime = $_.TimeCreated
						Write-Verbose -Message "Session start time is [$($LogonTime)]"
						$SessionEndEvent = $Events.where({
							$_.TimeCreated -gt $LogonTime -and
							$_.ID -in $SessionStopIds -and
							(([xml]$_.ToXml()).Event.EventData.Data | where { $_.Name -eq 'TargetLogonId' }).'#text' -eq $LogonId
						}) | select -First 1
						if (-not $SessionEndEvent) ## This be improved by seeing if this is the latest logon event
						{
							Write-Verbose -Message "Could not find a session end event for logon ID [$($LogonId)]. Assuming most current"
							$LogoffTime = Get-Date
						}
						else
						{
							$LogoffTime = $SessionEndEvent.TimeCreated
							Write-Verbose -Message "Session stop ID is [$($SessionEndEvent.Id)]"
							Write-Verbose -Message "Session stop time: [$($LogoffTime)] by event [$(Get-EventLabel -EventId $SessionEndEvent.Id)]"
						}
						$LogoffId = $SessionEndEvent.Id
						$output = [ordered]@{
							'ComputerName' = $_.MachineName
							'Username' = $Username
							'StartTime' = $LogonTime
							'StartAction' = Get-EventLabel -EventId $LogonId
							'StopTime' = $LogoffTime
							'StopAction' = Get-EventLabel -EventId $LogoffId
							'Session Active (Days)' = [math]::Round((New-TimeSpan -Start $LogonTime -End $LogoffTime).TotalDays, 2)
							'Session Active (Min)' = [math]::Round((New-TimeSpan -Start $LogonTime -End $LogoffTime).TotalMinutes, 2)
						}
						[pscustomobject]$output
					}
				})
			}
			catch
			{
				Write-Error $_.Exception.Message
			}
		}
		
	}
	catch
	{
		Write-Error $_.Exception.Message
	}
}