#requires -Version 5

<#PSScriptInfo

.VERSION 1.1

.GUID 0ef579e1-d89d-4e8a-9b9a-f07ab5af1084

.AUTHOR Adam Bertram

.COMPANYNAME Adam the Automator, LLC

.COPYRIGHT 

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES

.PRIVATEDATA 

#>

<# 

.DESCRIPTION 
 A PowerShell wrapper script to automate the Windows Disk Cleanup utility. 

#> 

param(
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string[]]$Section
)

$sections = @(
	'Active Setup Temp Folders',
	'BranchCache',
	'Content Indexer Cleaner',
	'Device Driver Packages',
	'Downloaded Program Files',
	'GameNewsFiles',
	'GameStatisticsFiles',
	'GameUpdateFiles',
	'Internet Cache Files',
	'Memory Dump Files',
	'Offline Pages Files',
	'Old ChkDsk Files',
	'Previous Installations',
	'Recycle Bin',
	'Service Pack Cleanup',
	'Setup Log Files',
	'System error memory dump files',
	'System error minidump files',
	'Temporary Files',
	'Temporary Setup Files',
	'Temporary Sync Files',
	'Thumbnail Cache',
	'Update Cleanup',
	'Upgrade Discarded Files',
	'User file versions',
	'Windows Defender',
	'Windows Error Reporting Archive Files',
	'Windows Error Reporting Queue Files',
	'Windows Error Reporting System Archive Files',
	'Windows Error Reporting System Queue Files',
	'Windows ESD installation files',
	'Windows Upgrade Log Files'
)

if ($PSBoundParameters.ContainsKey('Section')) {
	if ($Section -notin $sections) {
		throw "The section [$($Section)] is not available. Available options are: [$($sections -join ',')]."
	}
} else {
	$Section = $sections
}

Write-Verbose -Message 'Clearing CleanMgr.exe automation settings.'

$getItemParams = @{
	Path        = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\*'
	Name        = 'StateFlags0001'
	ErrorAction = 'SilentlyContinue'
}
Get-ItemProperty @getItemParams | Remove-ItemProperty -Name StateFlags0001 -ErrorAction SilentlyContinue

Write-Verbose -Message 'Adding enabled disk cleanup sections...'
foreach ($keyName in $Section) {
	$newItemParams = @{
		Path         = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$keyName"
		Name         = 'StateFlags0001'
		Value        = 2
		PropertyType = 'DWord'
		ErrorAction  = 'SilentlyContinue'
	}
	$null = New-ItemProperty @newItemParams
}

Write-Verbose -Message 'Starting CleanMgr.exe...'
Start-Process -FilePath CleanMgr.exe -ArgumentList '/sagerun:1' -NoNewWindow -Wait

Write-Verbose -Message 'Waiting for CleanMgr and DismHost processes...'
Get-Process -Name cleanmgr, dismhost -ErrorAction SilentlyContinue | Wait-Process
