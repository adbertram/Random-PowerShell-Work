<#
.SYNOPSIS
	This script imports a certificate into any certificate store on a local computer
.NOTES
	Created on: 	8/6/2014
	Created by: 	Adam Bertram
	Filename:		Import-Certificate.ps1
.EXAMPLE
	PS> .\Import-Certificate.ps1 -Location LocalMachine -StoreName My -FilePath C:\certificate.cer

	This example will import the certificate.cert certificate into the Personal store for the 
	local computer
.EXAMPLE
	PS> .\Import-Certificate.ps1 -Location CurrentUser -StoreName TrustedPublisher -FilePath C:\certificate.cer

	This example will import the certificate.cer certificate into the Trusted Publishers store for the 
	currently logged on user
.PARAMETER Location
 	This is the location (either CurrentUser or LocalMachine) where the store is located which the certificate
	will go into
.PARAMETER StoreName
	This is the certificate store that the certificate will be placed into
.PARAMETER FilePath
	This is the path to the certificate file that you'd like to import
#>
[CmdletBinding()]
[OutputType()]
param (
	[Parameter(Mandatory)]
	[ValidateSet('CurrentUser', 'LocalMachine')]
	[string]$Location,
	[Parameter(Mandatory)]
	[ValidateScript({
		if ($Location -eq 'CurrentUser') {
			(Get-ChildItem Cert:\CurrentUser | select -ExpandProperty name) -contains $_
		} else {
			(Get-ChildItem Cert:\LocalMachine | select -ExpandProperty name) -contains $_
		}
	})]
	[string]$StoreName,
	[Parameter(Mandatory)]
	[ValidateScript({Test-Path $_ -PathType Leaf })]
	[string]$FilePath
)

begin {
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	Set-StrictMode -Version Latest
	try {
		[void][System.Reflection.Assembly]::LoadWithPartialName("System.Security")
	} catch {
		Write-Error $_.Exception.Message
	}
}

process {
	try {
		$Cert = Get-Item $FilePath
		$Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $Cert
		foreach ($Store in $StoreName) {
			$X509Store = New-Object System.Security.Cryptography.X509Certificates.X509Store $Store, $Location
			$X509Store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
			$X509Store.Add($Cert)
			$X509Store.Close()
		}
	} catch {
		Write-Error $_.Exception.Message
	}
}