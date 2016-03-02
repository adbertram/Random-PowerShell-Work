function Get-CmSiteMaintenanceTask {
	<#
	.SYNOPSIS
		This function discovers and records the state of all site maintenance tasks on a ConfigMgr site server.
	.PARAMETER TaskName
		The name of the site maintenance task you'd like to limit the result set by.  This accepts wildcards or
		multiple names
	.PARAMETER Status
		The status (either enabled or disabled) of the site maintenance tasks you'd like to limit the result set by.
	.PARAMETER SiteServer
		The SCCM site server to query
	.PARAMETER SiteCode
		The SCCM site code
	.EXAMPLE
	
	PS> Get-CmSiteMaintenanceTask -TaskName 'Disabled*' -Status Enabled
	
	This example finds all site maintenance tasks starting with 'Disabled' that are enabled.
	#>
	[CmdletBinding()]
	[OutputType([System.Management.ManagementObject])]
	param (
		[Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
		[string[]]$TaskName,
		[Alias('ItemName')]
		[ValidateSet('Enabled', 'Disabled')]
		[string]$Status,
		[string]$SiteServer = '<SITESERVER>',
		[ValidateLength(3, 3)]
		[string]$SiteCode = '<SITECODE>'
	)
	
	process {
		try {
			$WmiParams = @{ 'Computername' = $SiteServer; 'Namespace' = "root\sms\site_$SiteCode"}
			
			Write-Verbose -Message "Building the WMI query..."
			if ($TaskName -or $Status) {
				if ($TaskName) {
					$WmiParams.Query = 'SELECT * FROM SMS_SCI_SQLTask WHERE '
					$NameConditions = @()
					foreach ($n in $TaskName) {
						## Allow asterisks in cmdlet but WQL requires percentage and double backslashes
						$NameValue = $n.Replace('*', '%').Replace('\', '\\')
						$Operator = @{ $true = 'LIKE'; $false = '=' }[$NameValue -match '\%']
						$NameConditions += "(ItemName $Operator '$NameValue')"
					}
					$WmiParams.Query += ($NameConditions -join ' OR ')
				}
				if ($Status) {
					$WmiParams.Class = 'SMS_SCI_SQLTask'
					$Enabled = $Status -eq 'Enabled'
					$WhereBlock = { $_.Enabled -eq $Enabled }
				}
			} else {
				$WmiParams.Class = 'SMS_SCI_SQLTask'
			}
			if ($WhereBlock) {
				Get-WmiObject @WmiParams | where $WhereBlock
			} else {
				Get-WmiObject @WmiParams
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Enable-CmSiteMaintenanceTask {
	<#
	.SYNOPSIS
		This function enables a ConfigMgr site maintenance task.
	.PARAMETER InputObject
		An object of returned from Get-CmSiteMaintenceTask of the task you'd like enabled.
	.EXAMPLE
	
	PS> Get-CmSiteMaintenanceTask -TaskName 'Disabled*' -Status Disabled | Enable-CmsiteMaintenanceTask
	
	This example finds all site maintenance tasks starting with 'Disabled' that are disabled and enables them all.
	#>
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline)]
		[System.Management.ManagementObject]$InputObject
	)
	process {
		try {
			$InputObject | Set-WmiInstance -Arguments @{ 'Enabled' = $true } | Out-Null
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Disable-CmSiteMaintenanceTask {
	<#
	.SYNOPSIS
		This function disables a ConfigMgr site maintenance task.
	.PARAMETER InputObject
		An object of returned from Get-CmSiteMaintenceTask of the task you'd like disabled.
	.EXAMPLE
	
	PS> Get-CmSiteMaintenanceTask -TaskName 'Disabled*' -Status Enabled | Disable-CmsiteMaintenanceTask
	
	This example finds all site maintenance tasks starting with 'Disabled' that are enabled and disables them all.
	#>
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline)]
		[System.Management.ManagementObject]$InputObject
	)
	process {
		try {
			$InputObject | Set-WmiInstance -Arguments @{ 'Enabled' = $false } | Out-Null
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}