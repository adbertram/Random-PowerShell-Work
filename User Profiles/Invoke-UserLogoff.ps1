
<#PSScriptInfo

.VERSION 1.0

.GUID 947c787b-1e06-4937-8022-1d3d39f267b0

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
 A simple script to remotely log off users from one or more remote computers. 

#> 

[OutputType('void')]
[CmdletBinding(SupportsShouldProcess)]
param
(
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string[]]$ComputerName,

	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$UserName
)

$ErrorActionPreference = 'Stop'

if (-not $PSBoundParameters.ContainsKey('ComputerName')) {
	$ComputerName = 'localhost'
}

foreach ($c in $ComputerName) {
	## Find the user's session ID
	$compArgs = $null
	if ($PSBoundParameters.ContainsKey('ComputerName')) {
		$compArgs = "/server:$c"	
	}
	$whereFilter = { '*' }
	if ($PSBoundParameters.ContainsKey('UserName')) {
		$whereFilter = [scriptblock]::Create("`$_ -match '$UserName'")
	}
	if ($sessions = ((quser $compArgs | Where-Object $whereFilter))) {
		$sessionIds = ($sessions -split ' +')[2]
		if ($PSCmdlet.ShouldProcess("UserName: $UserName", 'Logoff')) {
			$sessionIds | ForEach-Object {
				logoff $_ $compArgs
			}
		}
	} else {
		Write-Verbose -Message 'No users found matching criteria found.'
	}
}