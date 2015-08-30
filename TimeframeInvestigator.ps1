#requires -version 3

<#
.SYNOPSIS
    This script searches a Windows computer for all event log or text log entries
    between a specified start and end time.
.DESCRIPTION
    This script enumerates all event logs and all text logs on a local or remote
    Windows computer.  It looks for any entries between a specified start and end
    time.  It then copies this activity to an output location for further analysis.
.EXAMPLE
    SCRIPTNAME -StartTimestamp '01-29-2014 13:25:00' -EndTimeStamp '01-29-2014 13:28:00' -ComputerName COMPUTERNAME -OutputDirectory $desktop\trouble_logs -SkipEventLog Security
.PARAMETER computername
    The computer name to query. Just one.
.PARAMETER logname
    The name of a file to write failed computer names to. Defaults to errors.txt.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [datetime]$StartTimestamp,
    [Parameter(Mandatory)]
    [datetime]$EndTimestamp,
    [Parameter(ValueFromPipeline,
        ValueFromPipelineByPropertyName)]
    [string]$ComputerName = 'localhost',
    [Parameter()]
	[string]$OutputDirectory = ".\$Computername",
	[Parameter()]
	[string]$LogAuditFilePath = "$OutputDirectory\LogActivity.csv",
	[Parameter()]
	[switch]$EventLogsOnly,
    [Parameter()]
    [switch]$LogFilesOnly,
    [Parameter()]
	[string[]]$ExcludeDirectory,
	[Parameter()]
	[string[]]$FileExtension = @('log', 'txt', 'wer')
)

begin {
    $LogsFolderPath = "$OutputDirectory\logs"
    if (!(Test-Path $LogsFolderPath)) {
        mkdir $LogsFolderPath | Out-Null
	}
	
	function Add-ToLog($FilePath,$LineText,$LineNumber,$MatchType) {
		$Audit = @{
			'FilePath' = $FilePath;
			'LineText' = $LineText
			'LineNumber' = $LineNumber
			'MatchType' = $MatchType
		}
		[pscustomobject]$Audit | Export-Csv -Path $LogAuditFilePath -Append -NoTypeInformation
	}
}

process {

    if (!($LogFilesOnly.IsPresent)) {
		$Logs = (Get-WinEvent -ListLog * -ComputerName $ComputerName | where { $_.RecordCount }).LogName
		$FilterTable = @{
			'StartTime' = $StartTimestamp
			'EndTime' = $EndTimestamp
			'LogName' = $Logs
		}
		
		$Events = Get-WinEvent -ComputerName $ComputerName -FilterHashtable $FilterTable -ea 'SilentlyContinue'
		Write-Verbose "Found $($Events.Count) total events"
		
		## Convert the properties to something friendlier
		$LogProps = @{ }
		[System.Collections.ArrayList]$MyEvents = @()
		foreach ($Event in $Events) {
			$LogProps.Time = $Event.TimeCreated
			$LogProps.Source = $Event.ProviderName
			$LogProps.EventId = $Event.Id
			$LogProps.Message = $Event.Message.Replace("`n", '|').Replace("`r", '|')
			$LogProps.EventLog = $Event.LogName
			$MyEvents.Add([pscustomobject]$LogProps) | Out-Null
		}
		$MyEvents | sort Time | Export-Csv -Path "$OutputDirectory\eventlogs.txt" -Append -NoTypeInformation
	}
	
	if (!($EventLogsOnly.IsPresent)) {
        ## Enumerate all shares
		$Shares = Get-WmiObject -ComputerName $ComputerName -Class Win32_Share | where { $_.Path -match '^\w{1}:\\$' }
		[System.Collections.ArrayList]$AccessibleShares = @()
		foreach ($Share in $Shares) {
			$Share = "\\$ComputerName\$($Share.Name)"
			if (!(Test-Path $Share)) {
				Write-Warning "Unable to access the '$Share' share on '$Computername'"
			} else {
				$AccessibleShares.Add($Share) | Out-Null	
			}
		}
		
		$AllFilesQueryParams = @{
			Path = $AccessibleShares
			Recurse = $true
			Force = $true
			ErrorAction = 'SilentlyContinue'
			File = $true
		}
		if ($ExcludeDirectory) {
			$AllFilesQueryParams.ExcludeDirectory = $ExcludeDirectory	
		}
		##TODO: Add capability to match on Jan,Feb,Mar,etc
		$DateTimeRegex = "($($StartTimestamp.Month)[\\.\-/]?$($StartTimestamp.Day)[\\.\-/]?[\\.\-/]$($StartTimestamp.Year))|($($StartTimestamp.Year)[\\.\-/]?$($StartTimestamp.Month)[\\.\-/]?[\\.\-/]?$($StartTimestamp.Day))"
		Get-ChildItem @AllFilesQueryParams | where { $_.Length -ne 0 } | foreach {
			try {
				Write-Verbose "Processing file '$($_.Name)'"
				if (($_.LastWriteTime -ge $StartTimestamp) -and ($_.LastWriteTime -le $EndTimestamp)) {
					Write-Verbose "Last write time within timeframe for file '$($_.Name)'"
					Add-ToLog -FilePath $_.FullName -MatchType 'LastWriteTime'
				}
				if ($FileExtension -contains $_.Extension.Replace('.','') -and !((Get-Content $_.FullName -Encoding Byte -TotalCount 1024) -contains 0)) {
					## Check the contents of text file to references to dates in the timeframe
					Write-Verbose "Checking log file '$($_.Name)' for date/time match in contents"
					$LineMatches = Select-String -Path $_.FullName -Pattern $DateTimeRegex
					if ($LineMatches) {
						Write-Verbose "Date/time match found in file '$($_.FullName)'"
						foreach ($Match in $LineMatches) {
							Add-ToLog -FilePath $_.FullName -LineNumber $Match.LineNumber -LineText $Match.Line -MatchType 'Contents'
						}
						## I must create the directory ahead of time if it doesn't exist because
						## Copy-Item doesn't have the ability to automatically create the directory
						$Trim = $_.FullName.Replace("\\$Computername\", '')
						$Destination = "$OutputDirectory\$Trim"
						if (!(Test-Path $Destination)) {
							##TODO: Remove the error action when long path support is implemented
							mkdir $Destination -ErrorAction SilentlyContinue | Out-Null
						}
						Copy-Item -Path $_.FullName -Destination $Destination -ErrorAction SilentlyContinue -Recurse
					}
				}
			} catch {
				Write-Warning $_.Exception.Message	
			}
		}
	}
}
