<#
.SYNOPSIS
	This script calls the SCCM console's remote tools clients (CmRcViewer.exe) to start a SCCM
	remote tools console from Powershell.
.NOTES
	Created on: 	12/9/2014
	Created by: 	Adam Bertram
	Filename:		Connect-CmRemoteTools.ps1
	Requirements:	An available SCCM 2012 site server and the SCCM console installed
					Permissions to connect to the remote computer
.EXAMPLE
	PS> .\Connect-CmRemoteTools.ps1 -Computername MYCOMPUTER

	This example would bring up the SCCM remote tools console window connecting to the computer called MYCOMPUTER
.PARAMETER Computername
 	The name of the computer you'd like to use remote tools to connect to
.PARAMETER
	The name of the SCCM site server holding the site database
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory,
		ValueFromPipeline,
		ValueFromPipelineByPropertyName)]
	[ValidateScript({Test-Connection -ComputerName $_ -Quiet -Count 1})]
	[string]$Computername,
	[ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1 })]
	[string]$SiteServer = 'CONFIGMANAGER'
)

begin {
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	Set-StrictMode -Version Latest
}

process {
	try {
		## Find the path of the admin console to get the path of the remote tools client
		if (!$env:SMS_ADMIN_UI_PATH -or !(Test-Path "$($env:SMS_ADMIN_UI_PATH)\CmRcViewer.exe")) {
			throw "Unable to find the SCCM remote tools exe.  Is the console installed?"
		} else {
			$RemoteToolsFilePath = "$($env:SMS_ADMIN_UI_PATH)\CmRcViewer.exe"
		}
		
		& $RemoteToolsFilePath $Computername "\\$SiteServer"
		
	} catch {
		Write-Error $_.Exception.Message
	}
}