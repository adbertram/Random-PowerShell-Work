#Requires -RunAsAdministrator

function Test-LocalComputer {
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
	param (
		[Parameter(Mandatory)]
		[string]$ComputerName
	)
	begin {
		$LocalComputerLabels = @(
		'.',
		'localhost',
		[System.Net.Dns]::GetHostName(),
		[System.Net.Dns]::GetHostEntry('').HostName
		)
	}
	process {
		try {
			if ($LocalComputerLabels -contains $ComputerName) {
				Write-Verbose -Message "The computer reference [$($ComputerName)] is a local computer"
				$true
			}
			else {
				Write-Verbose -Message "The computer reference [$($ComputerName)] is a remote computer"
				$false
			}
		}
		catch {
			throw $_
		}
	}
}

function New-CertificateSigningRequest {
	<#
	.SYNOPSIS
		This function creates a certificate signing request (CSR) based on various parameters passed to it. It was built to provide
		an easy way to create CSRs without the need for IIS or Exchange.

		The primary functionality is done with certreq.exe. The bulk of the function simply provides an intuitive interface
		for building the INF to pass to the certreq.exe utility.

	.PARAMETER SubjectHost
		This is the Common Name ("CN") value in the subject of the CSR

	.PARAMETER FilePath
		The file path at which to place the resulting certificate signing request file.  Typically the file extension is ".req".
		If running on a remote computer, this will be still be the local path. It the contents will simply get written
		from the remote computer back to the local path. No UNC paths please.

	.PARAMETER ComputerName
		This is the computername in which the resulting certificate created from this CSR will be placed. The INF file used
		for certreq.exe will be created locally, however, it will then be copied to this computer and generated on there
		in order to be able to be imported once the certificate is built.

	.PARAMETER Credential
		A pscredential used to connect to the computer. This is not required if in an Active Directory domain.

	.PARAMETER SubjectBasePath
		This is a string that mimics the typical Country, state, city, organization, etc needed to create a CSR. By default,
		it is in a distinguished name format of:  OU=IT,O=Company,L=City,S=StateFullName,C=US

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
		New-CertificateSigningRequest -SubjectHost myhost.dom.com -SubjectAlternateNameDNS myapp.dom.com,myothercname.dom.com -SubjectBasePath "OU=SomeDept, O=Some Company, L=MyCity, ST=SpelledOutState, C=US" -FilePath C:\mycsr.req
		Create a new certificate signing request at C:\mycsr.req.

	.Notes
	Notice that you can inspect the newly minted CSR (or any valid CSR) using a tool like openssl.exe.  For example, to see what are the fields/values in C:\temp\testCSR.req, use:

	openssl.exe req -noout -text -verify -in C:\temp\testCSR.req
	#>
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType('System.IO.FileInfo')]
	param (
		[ValidateNotNullOrEmpty()]
		[string]$SubjectHost,

		## One or more DNS entries to include in request so as to have additional SAN entries in the request (note:  SubjectHost DNS entry will already be added to the SAN field, as modern browsers are dropping support for using the Subject field for server identification)
		[string[]]$SubjectAlternateNameDNS,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$FilePath,

		[ValidateNotNullOrEmpty()]
		[string]$ComputerName = $env:COMPUTERNAME,

		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential,

		[ValidateNotNullOrEmpty()]
		[string]$SubjectBasePath,

		[ValidateNotNullOrEmpty()]
		[switch]$PrivateKeyNotExportable,

		[ValidateNotNullOrEmpty()]
		[ValidateSet(1024, 2048, 4096, 8192, 16384)]
		[int]$KeyLength = 2048,

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

		[ValidateNotNullOrEmpty()]
		[ValidateSet('Microsoft RSA SChannel Cryptographic Provider')]
		[string]$ProviderName = 'Microsoft RSA SChannel Cryptographic Provider',

		[ValidateNotNullOrEmpty()]
		[ValidateSet('PKCS10', 'CMC')]
		[string]$RequestType = 'PKCS10',

		[ValidateNotNullOrEmpty()]
		[string]$CertReqFilePath = "$env:SystemRoot\system32\certreq.exe"

	)

	begin {
		if (-not $PSBoundParameters.ContainsKey("SubjectHost")) {$oComputerSystem = Get-WmiObject -Class Win32_ComputerSystem; $SubjectHost = ($oComputerSystem.DNSHostName, $oComputerSystem.Domain -join ".").ToLower()}
		Write-Verbose "Using Subject Host of '$SubjectHost'"
		## is this request for the local computer?
		$bIsLocalComputer = Test-LocalComputer -ComputerName $ComputerName
	}
	process {
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
		$usageHex = $KeyUsage | Foreach-Object {$keyUsageHexMappings[$_]}
		[string]$KeyUsage = '0x{0:x}' -f [int]($usageHex | Measure-Object -Sum).Sum

		if ($PrivateKeyNotExportable.IsPresent) {
			$exportable = 'FALSE'
		}
		else {
			$exportable = 'TRUE'
		}

		## make a string with the contents to use for the INF
		$infContents = @"
[Version]
Signature = "`$Windows NT`$"

[NewRequest]
Subject = "CN=$($SubjectHost,$SubjectBasePath -join ',')"
Exportable = $exportable
KeyLength = $KeyLength
KeySpec = 1
KeyUsage = $KeyUsage
MachineKeySet = True
ProviderName = "$ProviderName"
ProviderType = 12
Silent = True
SMIME = False
RequestType = $RequestType

[Extensions]
2.5.29.17 = "{text}"
_continue_ = "dns=${SubjectHost}&"
"@
		## if Subject Alternate Name value(s) specified, add them
		if ($PSBoundParameters.ContainsKey("SubjectAlternateNameDNS")) {
			## see following reference for SAN syntax in .inf file for various OSes:  https://technet.microsoft.com/en-us/library/ff625722(v=ws.10).aspx
			$infContents += $SubjectAlternateNameDNS | Where-Object {$_ -ne $SubjectHost} | Foreach-Object {"`n_continue_ = 'dns=${_}&'" -replace "'", '"'}
		} ## end if

		if ($PSCmdlet.ShouldProcess("CN=$SubjectHost", "Create Certificate Signing Request with following as inf file contents")) {
			try {
				$infFilePath = [system.IO.Path]::GetTempFileName()
				Remove-Item -Path $infFilePath -ErrorAction Ignore -Force
				$null = New-Item -Path $infFilePath -Value $infContents -Type File
				#endregion

				if (-not $bIsLocalComputer) {
					$sessParams = @{'ComputerName' = $ComputerName}

					$tempReqFilePath = 'C:\certreq.req'
					$tempInfFilePath = "C:\$([System.IO.Path]::GetFileName($infFilePath))"

					if ($PSBoundParameters.ContainsKey('Credential')) {
						$sessParams.Credential = $Credential
					}

					$session = New-PSSession @sessParams
					$null = Send-File -Session $session -Path $infFilePath -Destination 'C:\'

					Invoke-Command -Session $session -ScriptBlock { Start-Process -FilePath $using:CertReqFilePath -Args "-new `"$using:tempInfFilePath`" `"$using:tempReqFilePath`"" }
					Invoke-Command -Session $session -ScriptBlock { Get-Content -Path $using:tempReqFilePath } | Out-File -PSPath $FilePath
				}
				else {Start-Process -FilePath $CertReqFilePath -Args "-new `"$infFilePath`" `"$FilePath`"" -Wait -NoNewWindow}
				Get-Item -Path $FilePath
			}
			catch {
				throw $_
			}
			finally {
				if (-not $bIsLocalComputer) {
					Invoke-Command -Session $session -ScriptBlock {Remove-Item -Path $using:tempReqFilePath, $using:tempInfFilePath -ErrorAction Ignore}
					Remove-PSSession -Session $session -ErrorAction Ignore
				} ## end if
				else {Remove-Item -Path $infFilePath -ErrorAction Ignore}
			}
		} ## end if
		else {
			Write-Output "`n$infContents"
		}
	}
}
