<#
.SYNOPSIS
	This script retrieves all Configuration Manager updates that are deployed.  It will then check
	a WSUS server's updates and approve any WSUS updates that are in Configuration Manager.  Optionally,
	it can also decline any WSUS updates that are not in Configuration Manager as well as force a manual
	MS Update --> WSUS sync if it finds any updates in Configuration Manager that are not in WSUS.
.NOTES
	Created on: 	1/29/15
	Created by: 	Adam Bertram
	Filename:		Sync-CmToWsusSoftwareUpdates.ps1
	Credits:		http://blogs.technet.com/b/deploymentguys/archive/2009/10/22/approving-windows-updates-in-an-mdt-2010-standalone-environment-from-a-configmgr-software-update-point.aspx
					http://configmgrblog.com/2013/10/26/migrate-approved-software-updates-wsus-configmgr-2012/	
					http://myitforum.com/cs2/blogs/maikkoster/archive/2013/08/29/approving-updates-from-configmgr-scup-to-wsus.aspx
	Requirements:	The WSUS console must be installed - http://www.microsoft.com/en-us/download/details.aspx?id=5216
	Suggestions:	WSUS: No updates are manually approved on the WSUS server
					WSUS: Update source set to Microsoft Update
					WSUS: Synchronization schedule is set to automatic
					WSUS: Automatic Approvals are disabled
					This script is meant to be ran as a scheduled task and as a right-click tool in ConfigMgr.
.EXAMPLE
	PS> .\Sync-CmToWsusSoftwareUpdates.ps1

	This example finds all deployed CM updates and attempts to match these updates against WSUS.  If a match is found, it will
	approve the WSUS update.
.EXAMPLE
		PS> .\Sync-CmToWsusSoftwareUpdates.ps1 -DeclineAllNonMatches

	This example finds all deployed CM updates and attempts to match these updates against WSUS.  If a match is found, it will
	approve the WSUS update.  If a WSUS update is not in CM, it will decline it.
.PARAMETER DeclineAllNonMatches
	By default, the script will only approve matches in WSUS.  If this switch parameter is used, it will also decline all
	WSUS updates that do not have a match in CM.
.PARAMETER SyncWsus
	By default, the script will report on any CM updates that it could not find a match to in WSUS.  If this switch paramter is used
	it will force a manual sync on the WSUS server from MS update in an effort to get any remaining updates onto the WSUS server.
.PARAMETER LogFilePath
	The file path where you'd like to report the script's activity
.PARAMETER CmSiteServer
	The name of the site server to query for updates.
.PARAMETER CmSiteCode
	The 3-letter ConfigMgr site code
.PARAMETER WsusServer
	The name of the WSUS server
.PARAMETER WsusServerPort
	This is the port number that the WSUS server is listening on HTTP.  It's typically 80 or 8530.
#>
[CmdletBinding()]
param (
	[switch]$DeclineAllNonMatches,
	[switch]$SyncWsus,
	[string]$LogFilePath = "$PsScriptRoot\SCCM-WSUSUpdateSync.log",
	[ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1})]
	[string]$CmSiteServer = '',
	[string]$CmSiteCode = '',
	[ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1 })]
	[string]$WsusServer = '',
	[string]$WsusServerPort = '8530'
)

begin {
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	Set-StrictMode -Version Latest
	
	## These functions would be nice to have but I could not immediately figure out how to find
	## the approved products and classifications in CM to sync with WSUS
	<#function Sync-ClassificationSyncOptions {
		Invoke-Command -ComputerName $WsusServer -ScriptBlock { Set-WsusClassification }
	}
	
	function Sync-ProductSyncOptions {
		Invoke-Command -ComputerName $WsusServer -ScriptBlock { Set-WsusProduct }
	}#>
	
	function Write-Log {
		<#
		.SYNOPSIS
			This function creates or appends a line to a log file

		.DESCRIPTION
			This function writes a log line to a log file
		.PARAMETER  Message
			The message parameter is the log message you'd like to record to the log file
		.PARAMETER  LogLevel
			The logging level is the severity rating for the message you're recording. 
			You have 3 severity levels available; 1, 2 and 3 from informational messages
			for FYI to critical messages. This defaults to 1.

		.EXAMPLE
			PS C:\> Write-Log -Message 'Value1' -LogLevel 'Value2'
			
			This example shows how to call the Write-Log function with named parameters.
		#>
		[CmdletBinding()]
		param (
			[Parameter(Mandatory = $true)]
			[string]$Message,
			[ValidateSet(1, 2, 3)]
			[int]$LogLevel = 1
		)
		
		try {
			[pscustomobject]@{
				'Time' = Get-Date
				'Message' = $Message
				'ScriptLineNumber' = "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)"
				'Severity' = $LogLevel
			} | Export-Csv -Path $LogFilePath -Append -NoTypeInformation
		} catch {
			Write-Error $_.Exception.Message
			$false
		}
	}
	
	function Get-MyWsusUpdate {
		$Wsus.GetUpdates()
	}
	
	function Get-AllComputerTargetGroup {
		$Groups = $Wsus.GetComputerTargetGroups()
		$Groups | where { $_.Name -eq 'All Computers' }
	}
	
	function Approve-MyWsusUpdate ([Microsoft.UpdateServices.Internal.BaseApi.Update]$Update) {
		$AllComputerTg = Get-AllComputerTargetGroup
		$Update.Approve([Microsoft.UpdateServices.Administration.UpdateApprovalAction]::Install,$AllComputerTg) | Out-Null
	}
	
	function Decline-MyWsusUpdate ([Microsoft.UpdateServices.Internal.BaseApi.Update]$Update) {
		$Update.Decline()
	}
	
	function Sync-WsusServer {
		$Subscription = $Wsus.GetSubscription()
		$Subscription.StartSynchronization()
	}
	
	try {
		Write-Log 'Loading the WSUS type and creating the WSUS server object...'
		## Load the type in order to query updates from the WSUS server.  You must have the
		## WSUS administration console installed to get these assemblies
		[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
		$script:Wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($WsusServer, $false, $WsusServerPort)
	} catch {
		Write-Log "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" -LogLevel '3'
	}
	
}
process {
	try {
		Write-Log 'Finding all deployed CM updates...'
		$DeployedCmUpdates = Get-CimInstance -ComputerName $CmSiteServer -Namespace "root\sms\site_$CmSiteCode" -Class SMS_SoftwareUpdate | where { $_.IsDeployed -and !$_.IsSuperseded -and !$_.IsExpired }
		if (!$DeployedCmUpdates) {
			throw 'Error retrieving CM updates'
		} else {
			Write-Log "Found $($DeployedCmUpdates.Count) deployed updates"
		}
		Write-Log "Finding all WSUS updates on the $WsusServer WSUS server..."
		$WsusUpdates = Get-MyWsusUpdate
		if (!$WsusUpdates) {
			throw 'Error retrieving WSUS updates'
		}
		Write-Log "Found $($WsusUpdates.Count) applicable updates on the WSUS server"
		Write-Log 'Beginning matching process...'
		$MatchesMade = 0
		$NoMatchMade = 0
		$ApprovedMatches = 0
		$AlreadyApprovedMatches = 0
		$DeclinedWsusUpdates = 0
		foreach ($WsusUpdate in $WsusUpdates) {
			try {
				#Write-Log "Checking WSUS update $($WsusUpdate.Title) for a match..."
				if ($DeployedCmUpdates.LocalizedDisplayname -contains $WsusUpdate.Title) {
					#Write-Log "Found matching WSUS update '$($WsusUpdate.Title)'"
					$MatchesMade++
					if (!$WsusUpdate.IsApproved) {
						#Write-Log "Update is not approved. Checking for license agreement"
						$ApprovedMatches++
						if ($WsusUpdate.HasLicenseAgreement) {
							#Write-Log "Update has a license agreement. Accepting..."
							$WsusUpdate.AcceptLicenseAgreement()
						} else {
							#Write-Log 'Update does not have a license agreement'
						}
						#Write-Log "Approving WSUS update..."
						Approve-MyWsusUpdate -Update $WsusUpdate
						$ApprovedMatches++
					} else {
						#Write-Log "WSUS update is already approved."
						$AlreadyApprovedMatches++
					}
				} else {
					#Write-Log 'No match found'
					$NoMatchMade++
					if ($DeclineAllNonMatches.IsPresent) {
						if ($WsusUpdate.IsDeclined) {
							#Write-Log 'The WSUS update is already declined. No need to decline.'
						} else {		
							#Write-Log 'Declining WSUS update...'
							$DeclinedWsusUpdates++
							Decline-MyWsusUpdate -Update $WsusUpdate
						}
					}
				}
			} catch {
				Write-Log "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" -LogLevel '3'
			}
		}
		Write-Log 'Finding all CM updates that are not in WSUS...'
		$CmUpdatesNotInWsus = $DeployedCmUpdates | where { $WsusUpdates.Title -notcontains $_.LocalizedDisplayName }
		if (!$CmUpdatesNotInWsus) {
			Write-Log 'No CM updates found with no match in WSUS'
		} else {
			foreach ($CmUpdate in $CmUpdatesNotInWsus) {
				Write-Log "CM update '$($CmUpdate.LocalizedDisplayName)' not in WSUS"	
			}
			if ($SyncWsus.IsPresent) {
				## Force a manual sync with Microsoft in an attempt to download the updates we're missing.  We're
				## not tracking the sync but hopefully by the next CM --> WSUS sync, these updates will be there.
				Write-Log 'Forcing a WSUS sync...'
				Sync-WsusServer
			}
		}
		Write-Log "---------------------------------------------"
		Write-Log "WSUS Updates in CM: $MatchesMade"
		Write-Log "WSUS Updates in CM Declined: $DeclinedWsusUpdates"
		Write-Log "WSUS Updates in CM Already Approved: $AlreadyApprovedMatches"
		Write-Log "WSUS Updates in CM Approved: $ApprovedMatches"
		Write-Log "WSUS Updates not in CM: $NoMatchMade"
		Write-Log "CM Updates not in WSUS: $($CmUpdatesNotInWsus.Count)"
		Write-Log "---------------------------------------------"
		Write-Log 'CM --> WSUS synchronization complete'
	} catch {
		Write-Log "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" -LogLevel '3'
	}
}