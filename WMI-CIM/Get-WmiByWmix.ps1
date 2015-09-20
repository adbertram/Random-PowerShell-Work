#Requires -Version 4

<#	
.SYNOPSIS
	This PowerShell script is an example of how you can query a WMI class. When ran, it will run through each
    computer and query the class provided.  Since some WMI object property names and values can be obcure it also
	has the ability to translate these obscure values to something more user-friendly. It includes error handling
	in addition to WMI query abilities as a best practice to control errors, handle them gracefully to prevent your
	script from erroring out prematurely and to provide good feedback to see what went wrong.

	Using this PowerShell script you can either query the local machine or any number of remote hosts.
.EXAMPLE
	PS> .\Get-WmiByWmix.ps1 -Class Win32_BIOS

		This simple example would query WMI on the localhost for all properties in the WIn32_BIOS WMI class in the
		namespace root\cimv2. It would return raw output from WMI.

	PS> .\Get-WmiByWmix.ps1 -Class Win32_ComputerSystem -ComputerName 'computer1','computer2'

		This example would first ping both computer1 and computer2 to ensure they are online.  Once confirmed, the
		script would then query the WMI class Win32_ComputerSystem on both computers and return all properties and
		their values.

	PS> .\Get-WmiByWmix.ps1 -Class Win32_OperatingSystem -ComputerName 'computer1' -
		
.PARAMETER Class
	The name of the WMI class you'd like to query.  This is a mandatory parameter.

.PARAMETER ComputerName
	The name of the computer you'd like to run this function against. This defaults to 'localhost'.  You can also
	specify either a single or multiple comma-separated remote hosts as well.

.PARAMETER Namespace
	The name of the WMI namespace

.PARAMETER FriendlyProperties
	WMI can return some obsure property names and values. Use this switch parameter to conver all of those values
	to something more user-friendly.

.PARAMETER Impersonation
	Specifies the impersonation level to use. Valid values are:
		0: Default. Reads the local registry for the default impersonation level , which is usually set to '3: Impersonate'
		1: Anonymous. Hides the credentials of the caller.
	 	2: Identify. Allows objects to query the credentials of the caller.
 		3: Impersonate. Allows objects to use the credentials of the caller.
		4: Delegate. Allows objects to permit other objects to use the credentials of the caller.

.PARAMETER Authentication
	Specifies the authentication level to be used with the WMI connection. Valid values are:
		-1: Unchanged
		0: Default
		1: None (No authentication in performed.)
		2: Connect (Authentication is performed only when the client establishes a relationship with the application.)
		3: Call (Authentication is performed only at the beginning of each call when the application receives the request.)
		4: Packet (Authentication is performed on all the data that is received from the client.)
		5: PacketIntegrity (All the data that is transferred between the client and the application is authenticated and verified.)
		6: PacketPrivacy (The properties of the other authentication levels are used, and all the data is encrypted.)
	
.INPUTS
	None. You cannot pipe objects to Get-WmiByWmix.ps1.

.OUTPUTS
	Selected.System.Management.ManagementObject,System.Management.Automation.PSCustomObject.
#>
[CmdletBinding()]
[OutputType()]
param
(
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$Class,
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string[]]$ComputerName = $env:COMPUTERNAME,
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[pscredential]$Credential,
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$Namespace = 'root\cimv2',
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[switch]$FriendlyProperties,
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[ValidateRange(0, 4)]
	[int]$Impersonation,
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[ValidateRange(0, 6)]
	[int]$Authentication
	
)
begin
{
	$FriendlyPropNames = @{
		'BuildNumber' = 'Build Number'
		'CodeSet' = 'Code Set'
		'CurrentLanguage' = 'Current Language'
		'IdentificationCode' = 'Identification Code'
		'InstallableLanguages' = 'Installable Languages'
		'LanguageEdition' = 'Language Edition'
		'OtherTargetOS' = 'Other Target OS'
		'SerialNumber' = 'Serial Number'
		'SMBIOSBIOSVersion' = 'SMBIOS BIOS Version'
		'SMBIOSMajorVersion' = 'SMBIOS Major Version'
		'SMBIOSMinorVersion' = 'SMBIOS Minor Version'
		'SMBIOSPresent' = 'SMBIOS Present'
		'BIOSVersion' = 'BIOS Version'
		'InstallDate' = 'Install Date'
		'ListOfLanguages' = 'List of Languages'
		'PrimaryBIOS' = 'Primary BIOS'
	}
	
	$FriendlyBiosChars = @{
		'28' = 'Int 14h, Serial Services are supported'
		'19' = 'EDD (Enhanced Disk Drive) Specification is supported'
		'4' = 'ISA is supported'
		'3' = 'BIOS Characteristics Not Supported'
		'38' = '1394 boot is supported'
		'27' = 'Int 9h, 8042 Keyboard services are supported'
		'2' = 'Unknown'
		'39' = 'Smart Battery supported'
		'26' = 'Int 5h, Print Screen Service is supported'
		'1' = 'Reserved'
		'25' = "Int 13h - 3.5' / 2.88 MB Floppy Services are supported"
		'0' = 'Reserved'
		'24' = "Int 13h - 3.5' / 720 KB Floppy Services are  supported"
		'12' = 'BIOS shadowing is allowed'
		'23' = "Int 13h - 5.25' /1.2MB Floppy Services are supported"
		'13' = 'VL-VESA is supported'
		'34' = 'AGP is supported'
		'22' = "Int 13h - 5.25' / 360 KB Floppy Services are supported"
		'10' = 'APM is supported'
		'35' = 'I2O boot is supported'
		'21' = "Int 13h - Japanese Floppy for Toshiba 1.2mb (3.5', 360 RPM) is supported"
		'11' = 'BIOS is Upgradeable (Flash)'
		'36' = 'LS-120 boot is supported'
		'20' = "Int 13h - Japanese Floppy for NEC 9800 1.2mb (3.5', 1k Bytes/Sector, 360 RPM) is supported"
		'16' = 'Selectable Boot is supported'
		'37' = 'ATAPI ZIP Drive boot is supported'
		'17' = 'BIOS ROM is socketed'
		'30' = 'Int 10h, CGA/Mono Video Services are supported'
		'14' = 'ESCD support is available'
		'31' = 'NEC PC-98'
		'15' = 'Boot from CD is supported'
		'9' = 'Plug and Play is supported'
		'32' = 'ACPI supported'
		'8' = 'PC Card (PCMCIA) is supported'
		'33' = 'USB Legacy is supported'
		'7' = 'PCI is supported'
		'6' = 'EISA is supported'
		'29' = 'Int 17h, printer services are supported'
		'18' = 'Boot From PC Card (PCMCIA) is supported'
		'5' = 'MCA is supported'
	}
	
	$FriendlyOsNames = @{
		'54' = 'HP MPE'
		'28' = 'IRIX'
		'19' = 'WINCE'
		'4' = 'DGUX'
		'55' = 'NextStep'
		'3' = 'ATTUNIX'
		'52' = 'MiNT'
		'38' = 'XENIX'
		'27' = 'Sequent'
		'2' = 'MACOS'
		'53' = 'BeOS'
		'41' = 'BSDUNIX'
		'39' = 'VM/ESA'
		'26' = 'SCO OpenServer'
		'1' = 'Other'
		'50' = 'IxWorks'
		'40' = 'Interactive UNIX'
		'25' = 'SCO UnixWare'
		'0' = 'Unknown'
		'61' = 'TPF'
		'51' = 'VxWorks'
		'43' = 'NetBSD'
		'24' = 'Reliant UNIX'
		'12' = 'OS/2'
		'60' = 'VSE'
		'42' = 'FreeBSD'
		'23' = 'DC/OS'
		'13' = 'JavaVM'
		'45' = 'OS9'
		'34' = 'TandemNT'
		'22' = 'OSF'
		'10' = 'MVS'
		'44' = 'GNU Hurd'
		'35' = 'BS2000'
		'21' = 'NetWare'
		'11' = 'OS400'
		'47' = 'Inferno'
		'36' = 'LINUX'
		'20' = 'NCR3000'
		'16' = 'WIN95'
		'46' = 'MACH Kernel'
		'37' = 'Lynx'
		'17' = 'WIN98'
		'49' = 'EPOC'
		'30' = 'SunOS'
		'14' = 'MSDOS'
		'48' = 'QNX'
		'31' = 'U6000'
		'15' = 'WIN3x'
		'9' = 'AIX'
		'58' = 'Windows 2000'
		'32' = 'ASERIES'
		'8' = 'HPUX'
		'59' = 'Dedicated'
		'33' = 'TandemNSK'
		'7' = 'OpenVMS'
		'56' = 'PalmPilot'
		'6' = 'Digital Unix'
		'57' = 'Rhapsody'
		'29' = 'Solaris'
		'18' = 'WINNT'
		'5' = 'DECNT'
	}
	
	$FriendlySwElement = @{
		'3' = 'Running'
		'2' = 'Executable'
		'1' = 'Installable'
		'0' = 'Deployable'
	}
}
process
{
	try
	{
		$connParams = @{}
		if ($PSBoundParameters.ContainsKey('Credential'))
		{
			$connParams.Credential = $Credential
		}
		foreach ($computer in $ComputerName)
		{
			try
			{
				$connParams.ComputerName = $computer
				if (-not (Test-Connection -ComputerName $computer -Quiet -Count 1))
				{
					throw "The computer [$computer] is offline and cannot be queried"
				}
				Write-Verbose -Message "The computer [$($computer)] is online. Proceeding..."
				$wmiParams = $connParams + @{
					'Namespace' = $Namespace
					'Class' = $Class
					'Property' = '*'
				}
				if ($PSBoundParameters.ContainsKey('Authentication'))
				{
					$wmiParams.Authentication = $Authentication
				}
				if ($PSBoundParameters.ContainsKey('Impersonation'))
				{
					$wmiParams.Impersonation = $Impersonation
				}
				Write-Verbose -Message "Querying the WMI class [$($Class)] in namespace [$($Namespace)] on computer [$($computer)]"
				if (-not $FriendlyProperties.IsPresent)
				{
					Get-WmiObject @wmiParams | Select-Object *
				}
				else
				{
					$output = [ordered]@{}
					(Get-WmiObject @wmiParams).psbase.psobject.baseobject.properties | foreach {
						if ($FriendlyPropNames[$_.Name])
						{
							$output[$FriendlyPropNames[$_.Name]] = $_.Value
						}
						elseif ($_.Value -and $_.Value.ToString().EndsWith('000000+000'))
						{
							$output[$_.Name] = [Management.ManagementDateTimeconverter]::ToDateTime($_.Value)
						}
						elseif ($_.Name -eq 'BIOSCharacteristics')
						{
							$output['BIOS Characteristics'] = $_.Value | foreach { $FriendlyBiosChars[[string]$_] }
						}
						elseif ($_.Name -eq 'TargetOperatingSystem')
						{
							$output['Target Operating System'] = $FriendlyOsNames[[string]$_.Value]
						}
						elseif ($_.Name -eq 'SoftwareElementState')
						{
							$output['Software Element State'] = $FriendlySwElement[[string]$_.Value]
						}
						else
						{
							$output[$_.Name] = $_.Value
						}
					}
					[pscustomobject]$output
				}
			}
			catch
			{
				Write-Error "Unable to query WMI on [$computer] - $($_.Exception.Message)"
			}
		}
	}
	catch
	{
		Write-Error $_.Exception.Message
	}
	finally
	{
		Write-Verbose -Message 'WMIX script by GoverLAN complete'
	}
}