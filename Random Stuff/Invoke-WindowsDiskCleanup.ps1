<#
	.SYNOPSIS
		This script invokes the Windows Disk Cleanup utility, enables all rules and runs it.

	.EXAMPLE
		PS> .\Invoke-WindowsDiskCleanup.ps1

#>

Write-Log -Message 'Clearing CleanMgr.exe automation settings.'

$getItemParams = @{
	Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\*'
	Name = 'StateFlags0001'
	ErrorAction = 'SilentlyContinue'
}
Get-ItemProperty @getItemParams | Remove-ItemProperty -Name StateFlags0001 -ErrorAction SilentlyContinue

$enabledSections = @(
	'Active Setup Temp Folders'
	'BranchCache'
	'Content Indexer Cleaner'
	'Device Driver Packages'
	'Downloaded Program Files'
	'GameNewsFiles'
	'GameStatisticsFiles'
	'GameUpdateFiles'
	'Internet Cache Files'
	'Memory Dump Files'
	'Offline Pages Files'
	'Old ChkDsk Files'
	'Previous Installations'
	'Recycle Bin'
	'Service Pack Cleanup'
	'Setup Log Files'
	'System error memory dump files'
	'System error minidump files'
	'Temporary Files'
	'Temporary Setup Files'
	'Temporary Sync Files'
	'Thumbnail Cache'
	'Update Cleanup'
	'Upgrade Discarded Files'
	'User file versions'
	'Windows Defender'
	'Windows Error Reporting Archive Files'
	'Windows Error Reporting Queue Files'
	'Windows Error Reporting System Archive Files'
	'Windows Error Reporting System Queue Files'
	'Windows ESD installation files'
	'Windows Upgrade Log Files'
)

Write-Verbose -Message 'Adding enabled disk cleanup sections...'
foreach ($keyName in $enabledSections) {
	$newItemParams = @{
		Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$keyName"
		Name = 'StateFlags0001'
		Value = 1
		PropertyType = 'DWord'
		ErrorAction = 'SilentlyContinue'
	}
	$null = New-ItemProperty @newItemParams
}

Write-Verbose -Message 'Starting CleanMgr.exe...'
Start-Process -FilePath CleanMgr.exe -ArgumentList '/sagerun:1' -NoNewWindow -Wait

Write-Verbose -Message 'Waiting for CleanMgr and DismHost processes...'
Get-Process -Name cleanmgr,dismhost -ErrorAction SilentlyContinue | Wait-Process

# if (Test-Path $env:SystemRoot\Logs\CBS\DeepClean.log) {
# 	if (Select-String -Path $env:SystemRoot\Logs\CBS\DeepClean.log -Pattern 'Total size of superseded packages:' -Quiet) {

# 	}
# }