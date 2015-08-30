#Requires -Module ActiveDirectory

<#	
.SYNOPSIS
	This script finds all logon and logoff times of all users on all computers in an Active Directory organizational unit.

	The appropriate audit policies must be enabled first because the appropriate event IDs will show up.
.EXAMPLE
	PS> Get-ActiveDirectoryUserActivity.ps1 -OrganizationalUnit 'OU=My Desktops,DC=lab,DC=local' -EmailToAddress administrator@lab.local

		This example will query the security event logs of all computers in the AD OU 'My Desktops' and find
		all instances of the events IDs 4647 and 4648 in the security event logs. It will then generate a friendly
		report showing the user name, time generated, if the event was a logon or logoff and the computer
		the event came from.  Once the file is generated, it will then send an email to administrator@lab.local
		with the user report attached.
		
.PARAMETER OrganizationalUnit
	The distinguisned name of the AD organizational unit that you'd like to query the security event log of computers.
	
.PARAMETER EventID
	Two event IDs representing logon and logoff events.

.PARAMETER EmailToAddress
	The email address that you'd like to send the final report to.

.PARAMETER EmailFromAddress
	The email address you'd like the report sent to show it's from.

.PARAMETER EmailSubject
	The subject of the email that will contain the user activity report.
	
.INPUTS
	None. You cannot pipe objects to Get-ActiveDirectoryUserActivity.ps1.

.OUTPUTS
	None. If successful, this script does not output anything.
#>
[CmdletBinding()]
[OutputType()]
param
(
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[ValidatePattern('^OU\=')]
	[string]$OrganizationalUnit,

	[Parameter()]
	[string[]]$EventId = @(4647,4648),

	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$EmailToAddress,

	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$EmailFromAddress = 'IT Administrator',
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$EmailSubject = 'User Activity Report'

)
process {
	try
	{
		#region Gather all applicable computers
		$Computers = Get-ADComputer -SearchBase $OrganizationalUnit -Filter * | Select-Object Name
		if (-not $Computers)
		{
			throw "No computers found in OU [$($OrganizationalUnit)]"
		}
		#endregion
		
		#region Build XPath filter
		$XPathElements = @()
		foreach ($id in $EventId)
		{
			$XPathElements += "Event[System[EventID='$Id']]"
		}
		$EventFilterXPath = $XPathElements -join ' or '
		#endregion
		
		#region Build the array that will display the information we want
		$LogonId = $EventId[1]
		$LogoffId = $EventId[0]
		
		$SelectOuput = @(
		@{ n = 'ComputerName'; e = { $_.MachineName } },
		@{
			n = 'Event'; e = {
				if ($_.Id -eq $LogonId)
				{
					'Logon'
				}
				else
				{
					'LogOff'
				}
			}
		},
		@{ n = 'Time'; e = { $_.TimeCreated } },
		@{
			n = 'Account'; e = {
				if ($_.Id -eq $LogonId)
				{
					$i = 1
				}
				else
				{
					$i = 3
				}
				[regex]::Matches($_.Message, 'Account Name:\s+(.*)\n').Groups[$i].Value.Trim()
			}
		}
		)
		#endregion
		
		#region Query the computers' event logs and send output to a file to email
		$TempFile = 'C:\useractivity.txt'
		foreach ($Computer in $Computers) {
	    	Get-WinEvent -ComputerName $Computer -LogName Security -FilterXPath $EventFilterXPath | Select-Object $SelectOuput | Out-File $TempFile
		}
		#endregion
		
		$emailParams = @{
			'To' = $EmailToAddress
			'From' = $EmailFromAddress
			'Subject' = $EmailSubject
			'Attachments' = $TempFile
		}
		
		Send-MailMessage @emailParams

	} catch {
		Write-Error $_.Exception.Message
	}
	finally
	{
		## Cleanup the temporary file generated	
		Remove-Item -Path $TempFile -Force -ErrorAction SilentlyContinue
	}
}