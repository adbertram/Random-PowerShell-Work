<#
.SYNOPSIS
	This script is meant to be executed on a periodic basis via a scheduled task.  When ran, it checks for changes in the local admnistrators
	group for one or more computers.  If a new user is found, it will log the event and immediately email notification to warn of a possible hack.		
.EXAMPLE
	PS> Detect-LocalAdmin.ps1 -Computername PC1,PC2 -LogFilePath C:\MyLog.log -SmtpServer mail.domain.com -EmailSubject 'New Local Administrator Detected' -EmailRecipient 'abertram@domain.com'	
.PARAMETER Computername
	One or more computers to check for local administrator group changes
.PARAMETER LogFilePath
 	This is the file path where this script will record all activity
.PARAMETER SmtpServer
	The SMTP server to connect to when sending email notifications
.PARAMETER EmailFrom
	The email address that the email will be sent from.
.PARAMETER EmailSubject
	The subject of the email notification when a new local administrator has been found
.PARAMETER EmailRecipient
	The email address that will be sent the email notification
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory)]
	[ValidateScript({Test-Connection -ComputerName $_ -Quiet -Count 1 })]
	[string[]]$Computername,
	[string]$LogFilePath = 'C:\MyLog.log',
	[string]$SmtpServer = 'mail.domain.com',
	[string]$EmailFrom = 'notifications@domain.local',
	[string]$EmailSubject = 'New Local Administrator Detected',
	[string]$EmailRecipient = 'securityguy@domain.local'
)
begin {
	function Write-Log ($Computer,$Members,$NewMembers) {
		$MyDateTime = Get-Date -Format 'MM-dd-yyyy H:mm:ss'
		[pscustomobject]@{ 'Computer' = $Computer; 'Date' = $MyDateTime; 'Members' = ($Members -join ','); 'NewMembers' = $NewMembers } | Export-Csv -Path $LogFilePath -Append -NoTypeInformation
	}
}
process {
	try {
		foreach ($Computer in $Computername) {
			Write-Verbose "Finding members of local administrators group on computer '$Computer'"
			$Group = [ADSI]"WinNT://$Computer/Administrators"
			$Members = $Group.Invoke("Members") | foreach {
				$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)
			}
			if (!(Test-Path -Path $LogFilePath)) {
				Write-Verbose "The log file '$LogFilePath' does not exist on computer '$Computer'. Creating and appending member list"
				Write-Log -Computer $Computer -Members $Members
			} else {
				Write-Verbose 'Comparing last local administrator members with most current administrator members'
				$LastMembers = Import-Csv -Path $LogFilePath | Where-Object { $_.Computer -eq $Computer }
				if (!$LastMembers) {
					Write-Verbose "No members exist in log file on computer '$Computer'. Appending new results"
					Write-Log -Computer $Computer -Members $Members
				} else {
					$LastMembers = ($LastMembers | Select-Object -Last 1).Members.Split(',')
					Write-Verbose "Found $($LastMembers.Count) total local administrator members last time"
					$Diff = Compare-Object -ReferenceObject $LastMembers -DifferenceObject $Members | Where-Object { $_.SideIndicator -eq '=>' }
					if ($Diff) {
						$NewMembers = $Diff.InputObject
						Write-Log -Computer $Computer -Members $Members -NewMembers $NewMembers
						Write-Verbose "Found $($NewMembers.Count) new members in the local administrator group on computer '$Computer'. Emailing notification."
						$Params = @{
							'From' = $EmailFrom
							'To' = $EmailRecipient
							'Subject' = $EmailSubject
							'SmtpServer' = $SmtpServer
							'Body' = "The following new local administrator accounts were found on the computer $Computer`: $($NewMembers -join ',')"
						}
						#Send-MailMessage @Params
					} else {
						Write-Verbose "No additional members added to administrator group membership detected for computer '$Computer'"
						Write-Log -Computer $Computer -Members $Members
					}
				}
			}
		}
	} catch {
		Write-Error $_.Exception.Message
	}
}

end {
	try {
		
	} catch {
		Write-Error $_.Exception.Message
	}
}