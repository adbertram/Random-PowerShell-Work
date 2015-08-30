#Requires -Module ConfigurationManager
#Requires -Version 3

<#
.SYNOPSIS
	This script checks a SCCM deployment for the number of clients that have failed and if the deployment
	has not started. If either is true then it will send a notification.
.NOTES
	Created on: 	8/22/2014
	Created by: 	Adam Bertram
	Filename:		Test-CmDeploymentClientStatus.ps1
.EXAMPLE
	PS> Test-CmDeploymentClientStatus -DeploymentID ABC0045G
	
	This example would get the percentage of failed client for deployment ID ABC0045G and if
	the percentage was equal to or over the FailureThreshold it would send an email to
	ToEmailAddress.
.PARAMETER DeploymentId
	The SCCM deployment ID to check
.PARAMETER FailurePercentThreshold
	The percentage of clients that must fail the deployment before an email is sent
.PARAMETER ToEmailAddress
	The email address to send a notification email to (if necessary)
.PARAMETER FromEmailAddress
	The email address to show as being sent from
.PARAMETER FromDisplayName
	The name shown in most email clients as the email being sent from
.PARAMETER EmailSubject
	The subject of the email
.PARAMETER EmailBody
	If you'd like to include a snippet of text in the email body.  Use this parameter.
.PARAMETER SmtpServer
	The SMTP server to send the email through
.PARAMETER SiteServer
 	The name of the SCCM site server
.PARAMETER SiteCode
	The SCCM site code
	
#>
[CmdletBinding(DefaultParameterSetName = 'EmailNotification')]
param (
	[Parameter(Mandatory)]
	[string]$DeploymentId,
	[Parameter()]
	[ValidateRange(1, 100)]
	[int]$FailurePercentThreshold = 10,
	[Parameter(ParameterSetName = 'EmailNotification')]
	[string]$ToEmailAddress = 'replacethis@defaultemail.com',
	[Parameter(ParameterSetName = 'EmailNotification')]
	[string]$FromEmailAddress = 'Replace me',
	[Parameter(ParameterSetName = 'EmailNotification')]
	[string]$FromDisplayName = 'A Failed SCCM Deployment',
	[Parameter(ParameterSetName = 'EmailNotification')]
	[string]$EmailSubject = 'Failed SCCM Deployment',
	[Parameter(ParameterSetName = 'EmailNotification')]
	[string]$EmailBody,
	[Parameter(ParameterSetName = 'EmailNotification')]
	[string]$SmtpServer = 'replace.this.com',
	[Parameter()]
	[string]$SiteCode = 'UHP'
)

begin {
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	Set-StrictMode -Version Latest
	
	function Send-FailNotification ($Method) {
		switch ($Method) {
			'Email' {
				$Params = @{
					'From' = "$FromDisplayName <$FromEmailAddress>"
					'To' = $ToEmailAddress
					'Subject' = $EmailSubject
					'SmtpServer' = $SmtpServer
				}
				if (!$EmailBody) {
					$Params.Body = "$($Summary.PercentageFailed) percent of clients failed deployment ID $DeploymentId`n`r$Summary"
				} else {
					$Params.Body = $EmailBody	
				}
				Send-MailMessage @Params
			}
			default {
				$false
			}
		}
	}
	
	function Get-ClientPercentage ($ClientGroup) {
		[math]::Round((($Deployment.$ClientGroup / $Deployment.NumberTargeted) * 100), 1)
	}
	
	function Get-ClientStatusSummary {
		$script:Deployment = Get-CMDeployment -DeploymentId $DeploymentId
		if (!$Deployment) {
			$false
		} else {
			$Object = @{
				'NumberTargeted' = $Deployment.NumberTargeted
				'NumberUnknown' = $Deployment.NumberUnknown
				'PercentageFailed' = Get-ClientPercentage 'NumberErrors'
				'PercentageInProgress' = Get-ClientPercentage 'NumberInProgress'
				'PercentageOther' = Get-ClientPercentage 'NumberOther'
				'PercentageSuccess' = Get-ClientPercentage 'NumberSuccess'
				'PercentageUnknown' = Get-ClientPercentage 'NumberUnknown'
			}
			[pscustomobject]$Object
		}
	}
	
	try {
		Write-Verbose 'Checking to see if the SCCM module is available...'
		if (!(Test-Path "$(Split-Path $env:SMS_ADMIN_UI_PATH -Parent)\ConfigurationManager.psd1")) {
			throw 'Configuration Manager module not found.  Is the admin console intalled?'
		} elseif (!(Get-Module 'ConfigurationManager')) {
			Write-Verbose 'The SCCM module IS available.'
			Import-Module "$(Split-Path $env:SMS_ADMIN_UI_PATH -Parent)\ConfigurationManager.psd1"
		}
		$Location = (Get-Location).Path
		Set-Location "$($SiteCode):"
		
	} catch {
		Write-Error $_.Exception.Message
	}
}

process {
	try {
		Write-Verbose "Getting a summary of all client activity for deployment ID $DeploymentId..."
		$script:Summary = Get-ClientStatusSummary
		if (!$Summary) {
			throw "Could not find deployment ID '$DeploymentId'"
		} elseif ($Summary.PercentageFailed -ge $FailurePercentThreshold) {
			Write-Verbose "Failure threshold breached. There are $($Summary.PercentageFailed) percent of clients that failed this deployment"
			Send-FailNotification -Method 'Email'
		} elseif ($Summary.NumberTargeted -eq $Summary.NumberUnknown) {
			Write-Verbose 'It appears the deployment has not started'
			Send-FailNotification -Method 'Email'
		} else {
			Write-Verbose "Failure threshold not breached. There are only $($Summary.PercentageFailed) percent of clients that failed this deployment"
		}
} catch {
	Write-Error $_.Exception.Message
}
}

end {
	Set-Location $Location
}