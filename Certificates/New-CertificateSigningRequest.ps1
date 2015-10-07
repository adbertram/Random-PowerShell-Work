#Requires -RunAsAdministrator

#region function New-CertificateSigningRequest
function New-CertificateSigningRequest
{
	<#
		.SYNOPSIS
			This function creates a certificate signing request (CSR) based on various parameters passed to it. It was built to provide
			an easy way to create CSRs without the need for IIS or Exchange.
	
			The primary functionality is done with certreq.exe. The bulk of the function simply provides an intuitive interface
			for building the INF to pass to the certreq.exe utility.
	
		.PARAMETER SubjectHost
			This is the container name in the subject. It will be concatenated to the end of SubjectBasePath when the INF
			file is created.
	
		.PARAMETER FilePath
			The file path where you'd like to place the resulting certificate signing request file.  It should end in a .req
			extension.
	
		.PARAMETER SubjectBasePath
			This is a string that mimics the typical Country, state, city, organization, etc needed to create a CSR. By default,
			it is in a distinguished name format.
	
		.PARAMETER PrivateKeyNotExportable
			By default, the INF file is configured to allow the private key to be exported. Use this to override that.
	
		.PARAMETER KeyLength
			The key length of the certificate that will be created from this CSR. You may choose 1024, 2048, 4096, 8192 or 16384.
	
		.PARAMETER KeyUsage
			Any combination of the usage strings of 'Digital Signature','Key Encipherment','Non Repudiation','Data Encipherment',
			'Key Agreement','Key Cert Sign','Offline CRL','CRL Sign','Encipher Only'. These values will be added together to form
			their hex equivalent and placed into the INF file.
	
			This defaults to 'Digital Signature' and 'Key Encipherment'.
	
		.PARAMETER ProviderName
			They key provider to use. This defaults to Microsoft RSA SChannel Cryptographic Provider.
	
		.PARAMETER CertReqFilePath
			The file path to the certreq.exe file. Since this function relies on this file the path is defined here. This defaults
			to C:\Windows\System32\certreq.exe
	
		.EXAMPLE
			New-CertificateSigningRequest -SubjectHost myhost.local -FilePath C:\mycsr.req
	
			This example would create a C:\mycsr.req file.
	#>
	[OutputType('System.IO.FileInfo')]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$SubjectHost,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('\.req$')]
		[ValidateScript({ -not (Test-Path -Path $_ -PathType Leaf) })]
		[string]$FilePath,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$SubjectBasePath = 'C=US,S=California,L=Redwood City,O=GenomicHealth, Inc.,OU=IT,CN=',
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$PrivateKeyNotExportable,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet(1024, 2048, 4096, 8192, 16384)]
		[int]$KeyLength = 2048,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet(
					 'Digital Signature',
					 'Key Encipherment',
					 'Non Repudiation',
					 'Data Encipherment',
					 'Key Agreement',
					 'Key Cert Sign',
					 'Offline CRL',
					 'CRL Sign',
					 'Encipher Only'
					 )]
		[string[]]$KeyUsage = @('Digital Signature', 'Key Encipherment'),
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Microsoft RSA SChannel Cryptographic Provider')]
		[string]$ProviderName = 'Microsoft RSA SChannel Cryptographic Provider',
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('PKCS10', 'CMC')]
		[string]$RequestType = 'PKCS10',
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$CertReqFilePath = "$env:SystemRoot\system32\certreq.exe"
		
	)
	try
	{
		$keyUsageHexMappings = @{
			'Digital Signature' = 0x80
			'Key Encipherment' = 0x20
			'Non Repudiation' = 0x40
			'Data Encipherment' = 0x10
			'Key Agreement' = 0x08
			'Key Cert Sign' = 0x04
			'Offline CRL' = 0x02
			'CRL Sign' = 0x02
			'Encipher Only' = 0x01
		}
		
		#region Create the INF file
		$usageHex = $KeyUsage | foreach { $keyUsageHexMappings[$_] }
		[string]$KeyUsage = '0x{0:x}' -f [int]($usageHex | Measure-Object -Sum).Sum
		
		if ($PrivateKeyNotExportable.IsPresent)
		{
			$exportable = 'FALSE'
		}
		else
		{
			$exportable = 'TRUE'
		}
		
		$infContents = '
[NewRequest]
Subject = "{0}{1}"
Exportable = {2}
KeyLength = {3}
KeySpec = 1
KeyUsage = {4}
MachineKeySet = True
ProviderName = "{5}"
RequestType = {6}
'
		$infContents = ($infContents -f $SubjectBasePath, $SubjectHost, $exportable, $KeyLength, $KeyUsage, $ProviderName, $RequestType)
		$infFilePath = [system.IO.Path]::GetTempFileName()
		Remove-Item -Path $infFilePath -ErrorAction Ignore -Force
		$null = New-Item -Path $infFilePath -Value $infContents -Type File
		#endregion
		
		Start-Process -FilePath $CertReqFilePath -Args "-new `"$infFilePath`" `"$FilePath`"" -Wait -NoNewWindow
		Get-Item -Path $FilePath
	}
	catch
	{
		$PSCmdlet.ThrowTerminatingError($_)
	}
	finally
	{
		Remove-Item -Path $infFilePath -ErrorAction Ignore -Force	
	}
}
#endregion function New-CertificateSigningRequest