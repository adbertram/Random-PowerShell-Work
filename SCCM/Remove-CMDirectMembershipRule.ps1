#Requires -Version 4

<#
.NOTES
	Created on: 5/22/2014 10:56 AM
	Created by: Adam Bertram
	Filename:   Remove-CMDirectMembershipRule.ps1
	Credits:    http://www.david-obrien.net/2013/02/24/remove-direct-membership-rules-configmgr/
.DESCRIPTION
	This script removes all direct membership rules from a specified collection name   
.EXAMPLE
	.\Remove-CMDirectMembershipRule.ps1 -SiteCode 'CON' -SiteServer 'SERVERNAME' -CollectionName 'NAMEHERE'    
.PARAMETER SiteCode
 	Your Configuration Manager site code
.PARAMETER SiteServer
	Your Configuration Manager site server name
.PARAMETER CollectionName
	The collection name you'd like to remove direct membership rules from
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory = $False,
			   ValueFromPipeline = $False,
			   ValueFromPipelineByPropertyName = $True)]
	[string]$SiteCode = 'UHP',
	[Parameter(Mandatory = $False,
			   ValueFromPipeline = $False,
			   ValueFromPipelineByPropertyName = $True)]
	[string]$SiteServer = 'CONFIGMANAGER',
	[Parameter(Mandatory = $True,
			   ValueFromPipeline = $True,
			   ValueFromPipelineByPropertyName = $True)]
	[string]$CollectionName
)

begin {
	try {
		if ([Environment]::Is64BitProcess) {
			# this script needs to run in a x86 shell, but we need to access the x64 reg-hive to get the AdminConsole install directory
			throw 'This script must be run in a x86 shell.'
		}
		$ConfigMgrModule = "$($env:SMS_ADMIN_UI_PATH | Split-Path -Parent)\ConfigurationManager.psd1"
		if (!(Test-Path $ConfigMgrModule)) {
			throw 'Configuration Manager module not found in admin console path'
		}
		Import-Module $ConfigMgrModule
		
		$BeforeLocation = (Get-Location).Path
	} catch {
		Write-Error $_.Exception.Message	
	}
}

process {
	try {
		Set-Location "$SiteCode`:"
		$CommonWmiParams = @{
			'ComputerName' = $SiteServer
			'Namespace' = "root\sms\site_$SiteCode"
		}
		#HACK: This should be 1 WQL query using JOIN but it's not immediately obvious why that doesn't work
		#Get-WmiObject -ComputerName $SiteServer -Namespace "ROOT\sms\site_$SiteCode" -Query "SELECT DISTINCT * FROM SMS_CollectionMember_a AS collmem JOIN SMS_Collection AS coll ON coll.CollectionID = collmem.CollectionID"
		
		$CollectionId = Get-WmiObject @CommonWmiParams -Query "SELECT CollectionID FROM SMS_Collection WHERE Name = '$CollectionName'" | select -ExpandProperty CollectionID
		if (!$CollectionId) {
			throw "No collection found with the name $CollectionName"
		}
				
		## Find the collection members
		$CollectionMembers = Get-WmiObject @CommonWmiParams -Query "SELECT Name FROM SMS_CollectionMember_a WHERE CollectionID = '$CollectionId'" | Select -ExpandProperty Name
		
		if (!$CollectionMembers) {
			Write-Warning 'No collection members found in collection'
		} else {
			@($CollectionMembers).foreach({
				Remove-CMDeviceCollectionDirectMembershipRule -CollectionID $CollectionID -ResourceName $_ -force
			})
		}
	} catch {
		Write-Error $_.Exception.Message
	}
}

end {
	Set-Location $BeforeLocation
}