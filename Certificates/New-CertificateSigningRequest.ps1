#Requires -RunAsAdministrator

function Test-LocalComputer
{
	<#	
			.SYNOPSIS
			This script detects if the a label indicates the local computer or not. A designation for local computer
			could be a number of labels such as ".", "localhost", the netbios name of the local computer or the FQDN
			of the local computer.  This function returns true if any of those labels match the local computer or false
			if it indicates a remote computer.

	.PARAMETER Label
		The label that's being tested if it represents the local machine or not.

			.EXAMPLE
			PS> Test-LocalComputer -Label localhost

			This example will return [bool]$true because localhost is an indicator of the local machine.

			.EXAMPLE
			PS> Test-LocalComputer -Label PC02
	
			This example will return [bool]$true if the NetBIOS name of the local computer is PC02. If not, it will return
			[bool]$false.

	.NOTES
		Created on: 	5/27/15
		Created by: 	Adam Bertram
	#>
	
	[CmdletBinding()]
	[OutputType([bool])]
	param
	(
		[Parameter(Mandatory)]
		[string]$ComputerName
	)
	begin
	{
		$LocalComputerLabels = @(
		'.',
		'localhost',
		[System.Net.Dns]::GetHostName(),
		[System.Net.Dns]::GetHostEntry('').HostName
		)
	}
	process
	{
		try
		{
			if ($LocalComputerLabels -contains $ComputerName)
			{
				Write-Verbose -Message "The computer reference [$($ComputerName)] is a local computer"
				$true
			}
			else
			{
				Write-Verbose -Message "The computer reference [$($ComputerName)] is a remote computer"
				$false
			}
		}
		catch
		{
			throw $_
		}
	}
}

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
		extension. If running on a remote computer, this will be still be the local path. It the contents will simply get written
		from the remote computer back to the local path. No UNC paths please.
	
	.PARAMETER ComputerName
		This is the computername in which the resulting certificate created from this CSR will be placed. The INF file used
		for certreq.exe will be created locally, however, it will then be copied to this computer and generated on there
		in order to be able to be imported once the certificate is built.
	
	.PARAMETER Credential
		A pscredential used to connect to the computer. This is not required if in an Active Directory domain.

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
		to C:\Windows\System32\certreq.exe. If running on a remote computer, this will still be the local path only on the remote
		computer. No UNC paths please.

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
		[string]$FilePath,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName = $env:COMPUTERNAME,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$SubjectBasePath = 'C=US,S=State,L=City,O=Company,OU=IT,CN=',
		
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
	process
	{
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
			
			$infContents = '[Version]
Signature = "$Windows NT$"
[NewRequest]
Subject = "{0}{1}"
Exportable = {2}
KeyLength = {3}
KeySpec = 1
KeyUsage = {4}
MachineKeySet = True
ProviderName = "{5}"
ProviderType = 12
Silent = True
SMIME = False
RequestType = {6}'
			
			$infContents = ($infContents -f $SubjectBasePath, $SubjectHost, $exportable, $KeyLength, $KeyUsage, $ProviderName, $RequestType)
			$infFilePath = [system.IO.Path]::GetTempFileName()
			Remove-Item -Path $infFilePath -ErrorAction Ignore -Force
			$null = New-Item -Path $infFilePath -Value $infContents -Type File
			#endregion
			
			if (-not (Test-LocalComputer -ComputerName $ComputerName))
			{
				$sessParams = @{
					'ComputerName' = $ComputerName
				}
				
				$tempReqFilePath = 'C:\certreq.req'
				$tempInfFilePath = "C:\$([System.IO.Path]::GetFileName($infFilePath))"
				
				if ($PSBoundParameters.ContainsKey('Credential'))
				{
					$invParams.Credential = $Credential
					$sessParams.Credential = $Credential
				}
				
				$session = New-PSSession @sessParams
				$null = Send-File -Session $session -Path $infFilePath -Destination 'C:\'
				
				Invoke-Command -Session $session -ScriptBlock { Start-Process -FilePath $using:CertReqFilePath -Args "-new `"$using:tempInfFilePath`" `"$using:tempReqFilePath`"" }
				
				Invoke-Command -Session $session -ScriptBlock { Get-Content -Path $using:tempReqFilePath } | Out-File -PSPath $FilePath
			}
			else
			{
				Start-Process -FilePath $CertReqFilePath -Args "-new `"$infFilePath`" `"$FilePath`"" -Wait -NoNewWindow
			}
			Get-Item -Path $FilePath
		}
		catch
		{
			throw $_
		}
		finally
		{
			Invoke-Command -Session $session -ScriptBlock {
				Remove-Item -Path $using:tempReqFilePath -ErrorAction Ignore
				Remove-Item -Path $using:tempInfFilePath -ErrorAction Ignore
			}
			Remove-PSSession -Session $session -ErrorAction Ignore
		}
	}
}