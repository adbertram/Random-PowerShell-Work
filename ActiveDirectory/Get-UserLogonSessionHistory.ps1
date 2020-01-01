<#	
.SYNOPSIS
	This script finds all logon, logoff and total active session times of all users on all computers specified. For this script
	to function as expected, the advanced AD policies; Audit Logon, Audit Logoff and Audit Other Logon/Logoff Events must be
    enabled and targeted to the appropriate computers via GPO or local policy.
.EXAMPLE
	
.PARAMETER ComputerName
	An array of computer names to search for events on. If this is not provided, the script will search the local computer.
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
    [string[]]$ComputerName = $Env:COMPUTERNAME
)

try {
	
    #region Defie all of the events to indicate session start or top
    $sessionEvents = @(
        @{ 'Label' = 'Logon'; 'EventType' = 'SessionStart'; 'LogName' = 'Security'; 'ID' = 4624 } ## Advanced Audit Policy --> Audit Logon
        @{ 'Label' = 'Logoff'; 'EventType' = 'SessionStop'; 'LogName' = 'Security'; 'ID' = 4647 } ## Advanced Audit Policy --> Audit Logoff
        @{ 'Label' = 'Startup'; 'EventType' = 'SessionStop'; 'LogName' = 'System'; 'ID' = 6005 }
        @{ 'Label' = 'RdpSessionReconnect'; 'EventType' = 'SessionStart'; 'LogName' = 'Security'; 'ID' = 4778 } ## Advanced Audit Policy --> Audit Other Logon/Logoff Events
        @{ 'Label' = 'RdpSessionDisconnect'; 'EventType' = 'SessionStop'; 'LogName' = 'Security'; 'ID' = 4779 } ## Advanced Audit Policy --> Audit Other Logon/Logoff Events
        @{ 'Label' = 'Locked'; 'EventType' = 'SessionStop'; 'LogName' = 'Security'; 'ID' = 4800 } ## Advanced Audit Policy --> Audit Other Logon/Logoff Events
        @{ 'Label' = 'Unlocked'; 'EventType' = 'SessionStart'; 'LogName' = 'Security'; 'ID' = 4801 } ## Advanced Audit Policy --> Audit Other Logon/Logoff Events
    )
    
    ## All of the IDs that designate when user activity starts
    $sessionStartIds = ($sessionEvents | where { $_.EventType -eq 'SessionStart' }).ID
    ## All of the IDs that designate when user activity stops
    $sessionStopIds = ($sessionEvents | where { $_.EventType -eq 'SessionStop' }).ID
    #endregion
	
    ## Define all of the log names we'll be querying
    $logNames = ($sessionEvents.LogName | select -Unique)
    ## Grab all of the interesting IDs we'll be looking for
    $ids = $sessionEvents.Id
		
    ## Build the insane XPath query for the security event log in order to query events as fast as possible
    $logonXPath = "Event[System[EventID=4624]] and Event[EventData[Data[@Name='TargetDomainName'] != 'Window Manager']] and Event[EventData[Data[@Name='TargetDomainName'] != 'NT AUTHORITY']] and (Event[EventData[Data[@Name='LogonType'] = '2']] or Event[EventData[Data[@Name='LogonType'] = '11']])"
    $otherXpath = 'Event[System[({0})]]' -f "EventID=$(($ids.where({ $_ -ne '4624' })) -join ' or EventID=')"
    $xPath = '({0}) or ({1})' -f $logonXPath, $otherXpath

    foreach ($computer in $ComputerName) {
        ## Query each computer's event logs using the Xpath filter
        $events = Get-WinEvent -ComputerName $computer -LogName $logNames -FilterXPath $xPath
        Write-Verbose -Message "Found [$($events.Count)] events to look through"

        ## Set up the output object
        $output = [ordered]@{
            'ComputerName'          = $computer
            'Username'              = $null
            'StartTime'             = $null
            'StartAction'           = $null
            'StopTime'              = $null
            'StopAction'            = $null
            'Session Active (Days)' = $null
            'Session Active (Min)'  = $null
        }
        
        ## Need current users because if no stop time, they're still probably logged in
        $getGimInstanceParams = @{
            ClassName = 'Win32_ComputerSystem'
        }
        if ($computer -ne $Env:COMPUTERNAME) {
            $getGimInstanceParams.ComputerName = $computer
        }
        $loggedInUsers = Get-CimInstance @getGimInstanceParams | Select-Object -ExpandProperty UserName | foreach { $_.split('\')[1] }
            
        ## Find all user start activity events and begin parsing
        $events.where({ $_.Id -in $sessionStartIds }).foreach({
                try {
                    $logonEvtId = $_.Id
                    $output.StartAction = $sessionEvents.where({ $_.ID -eq $logonEvtId }).Label
                    $xEvt = [xml]$_.ToXml()

                    ## Figure out the login session ID
                    $output.Username = ($xEvt.Event.EventData.Data | where { $_.Name -eq 'TargetUserName' }).'#text'
                    $logonId = ($xEvt.Event.EventData.Data | where { $_.Name -eq 'TargetLogonId' }).'#text'
                    if (-not $logonId) {
                        $logonId = ($xEvt.Event.EventData.Data | where { $_.Name -eq 'LogonId' }).'#text'
                    }
                    $output.StartTime = $_.TimeCreated
        
                    Write-Verbose -Message "New session start event found: event ID [$($logonEvtId)] username [$($output.Username)] logonID [$($logonId)] time [$($output.StartTime)]"
                    ## Try to match up the user activity end event with the start event we're processing
                    if (-not ($sessionEndEvent = $Events.where({ ## If a user activity end event could not be found, assume the user is still logged on
                                    $_.TimeCreated -gt $output.StartTime -and
                                    $_.ID -in $sessionStopIds -and
                                    (([xml]$_.ToXml()).Event.EventData.Data | where { $_.Name -eq 'TargetLogonId' }).'#text' -eq $logonId
                                })) | select -last 1) {
                        if ($output.UserName -in $loggedInUsers) {
                            $output.StopTime = Get-Date
                            $output.StopAction = 'Still logged in'
                        } else {
                            throw "Could not find a session end event for logon ID [$($logonId)]."
                        }
                    } else {
                        ## Capture the user activity end time
                        $output.StopTime = $sessionEndEvent.TimeCreated
                        Write-Verbose -Message "Session stop ID is [$($sessionEndEvent.Id)]"
                        $output.StopAction = $sessionEvents.where({ $_.ID -eq $sessionEndEvent.Id }).Label
                    }

                    $sessionTimespan = New-TimeSpan -Start $output.StartTime -End $output.StopTime
                    $output.'Session Active (Days)' = [math]::Round($sessionTimespan.TotalDays, 2)
                    $output.'Session Active (Min)'  = [math]::Round($sessionTimespan.TotalMinutes, 2)
                    
                    [pscustomobject]$output
                } catch {
                    Write-Warning -Message $_.Exception.Message
                }
            })
    }
} catch {
    $PSCmdlet.ThrowTerminatingError($_)
}