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
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$ComputerName
)

try
{
	
	#region Defie all of the events to indicate session start or top
	$script:SessionEvents = @(
		@{ 'Label' = 'Logon'; 'EventType' = 'SessionStart'; 'LogName' = 'Security'; 'ID' = 4624 } ## Advanced Audit Policy --> Audit Logon
		@{ 'Label' = 'Logoff'; 'EventType' = 'SessionStop'; 'LogName' = 'Security'; 'ID' = 4647 } ## Advanced Audit Policy --> Audit Logoff
		@{ 'Label' = 'Startup'; 'EventType' = 'SessionStop'; 'LogName' = 'System'; 'ID' = 6005 }
		@{ 'Label' = 'RdpSessionReconnect'; 'EventType' = 'SessionStart'; 'LogName' = 'Security'; 'ID' = 4778 } ## Advanced Audit Policy --> Audit Other Logon/Logoff Events
		@{ 'Label' = 'RdpSessionDisconnect'; 'EventType' = 'SessionStop'; 'LogName' = 'Security'; 'ID' = 4779 } ## Advanced Audit Policy --> Audit Other Logon/Logoff Events
		@{ 'Label' = 'Locked'; 'EventType' = 'SessionStop'; 'LogName' = 'Security'; 'ID' = 4800 } ## Advanced Audit Policy --> Audit Other Logon/Logoff Events
		@{ 'Label' = 'Unlocked'; 'EventType' = 'SessionStart'; 'LogName' = 'Security'; 'ID' = 4801 } ## Advanced Audit Policy --> Audit Other Logon/Logoff Events
	)
	
	$SessionStartIds = ($SessionEvents | where { $_.EventType -eq 'SessionStart' }).ID
	## Startup ID will be used for events where the computer was powered off abruptly or crashes --not a great measurement
	$SessionStopIds = ($SessionEvents | where { $_.EventType -eq 'SessionStop' }).ID
	#endregion
	
	try
	{
		$logNames = ($SessionEvents.LogName | select -Unique)
		$ids = $SessionEvents.Id
		
		## Build the insane XPath query for the security event log in order to query events as fast as possible
		$logonXPath = "Event[System[EventID=4624]] and Event[EventData[Data[@Name='TargetDomainName'] != 'Window Manager']] and Event[EventData[Data[@Name='TargetDomainName'] != 'NT AUTHORITY']] and (Event[EventData[Data[@Name='LogonType'] = '2']] or Event[EventData[Data[@Name='LogonType'] = '11']])"
		$otherXpath = 'Event[System[({0})]]' -f "EventID=$(($ids.where({ $_ -ne '4624' })) -join ' or EventID=')"
		$xPath = '({0}) or ({1})' -f $logonXPath, $otherXpath
		
		$events = Get-WinEvent -ComputerName $ComputerName -LogName $logNames -FilterXPath $xPath
		Write-Verbose -Message "Found [$($events.Count)] events to look through"
		
		$events.foreach({
			if ($_.Id -in $SessionStartIds)
			{
				$logonEvtId = $_.Id
				$xEvt = [xml]$_.ToXml()
				$Username = ($xEvt.Event.EventData.Data | where { $_.Name -eq 'TargetUserName' }).'#text'
				$LogonId = ($xEvt.Event.EventData.Data | where { $_.Name -eq 'TargetLogonId' }).'#text'
				if (-not $LogonId)
				{
					$LogonId = ($xEvt.Event.EventData.Data | where { $_.Name -eq 'LogonId' }).'#text'
				}
				$LogonTime = $_.TimeCreated
				
				Write-Verbose -Message "New session start event found: event ID [$($logonEvtId)] username [$($Username)] logonID [$($LogonId)] time [$($LogonTime)]"
				$SessionEndEvent = $Events.where({
					$_.TimeCreated -gt $LogonTime -and
					$_.ID -in $SessionStopIds -and
					(([xml]$_.ToXml()).Event.EventData.Data | where { $_.Name -eq 'TargetLogonId' }).'#text' -eq $LogonId
				}) | select -First 1
				if (-not $SessionEndEvent) ## This be improved by seeing if this is the latest logon event
				{
					Write-Verbose -Message "Could not find a session end event for logon ID [$($LogonId)]. Assuming most current"
					#Write-Warning "Could not find session end event"
					$LogoffTime = Get-Date
				}
				else
				{
					$LogoffTime = $SessionEndEvent.TimeCreated
					Write-Verbose -Message "Session stop ID is [$($SessionEndEvent.Id)]"
					$LogoffId = $SessionEndEvent.Id
					$output = [ordered]@{
						'ComputerName' = $_.MachineName
						'Username' = $Username
						'StartTime' = $LogonTime
						'StartAction' = $SessionEvents.where({ $_.ID -eq $logonEvtId }).Label
						'StopTime' = $LogoffTime
						'StopAction' = $SessionEvents.where({ $_.ID -eq $LogoffID }).Label
						'Session Active (Days)' = [math]::Round((New-TimeSpan -Start $LogonTime -End $LogoffTime).TotalDays, 2)
						'Session Active (Min)' = [math]::Round((New-TimeSpan -Start $LogonTime -End $LogoffTime).TotalMinutes, 2)
					}
					[pscustomobject]$output
				}
			}
		})
	}
	catch
	{
		Write-Error $_.Exception.Message
	}
}
catch
{
	$PSCmdlet.ThrowTerminatingError($_)
}