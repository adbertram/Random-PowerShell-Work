#Requires -Module DnsServer
#Requires -Version 3

<#
.SYNOPSIS
	This script tests a particular computer to see if it's dynamic DNS functionality is working.
.DESCRIPTION
	This script firsts check to ensure the any NIC on the specified computer has dynamic DNS enabled.  If a NIC is found, it then proceeds
	to find the client's primary DNS server.  This will be the DNS server the script calls for when checking server-side to see if
	it can update it's own record.  It then finds the client's primary DNS suffix.  This will be the zone the script checks on
	the server.

	If the computer record's timestamp is still within the no-refresh period of the zone, the test cannot happen because the server
	will disallow any updates to the timestamp.  However, the script will still return true because the record is still considered "healthy".
	
	It then tries to issue an "ipconfig /registerdns" on the computer via remoting.  If that fails, it then attempts to create a process
	via WMI.  It then waits a default of 10 seconds and checks the computer's DNS record at the server to see if the register DNS attempt
	worked.  If, after the retry interval time elapses, the record's timestamp still hasn't been updated, the script will return a failure.
.NOTES
	Created on: 	8/19/2014
	Created by: 	Adam Bertram
	Filename:		Test-ClientDynamicDns.ps1
.EXAMPLE
	PS> .\Test-ClientDynamicDns.ps1 -Computername COMPUTER1 -RetryInterval 20

	In this example, the script will test the computername COMPUTER1 and will retry 20 times every second to see if the
	client computer updated it's timestamp on it's DNS host record.
.EXAMPLE
	PS> .\Test-ClientDynamicDns.ps1 -Computername COMPUTER1

	In this example, the script will test the computername COMPUTER1 and will retry 10 times every second to see if the
	client computer updated it's timestamp on it's DNS host record.	
.PARAMETER Computername
 	The name of the computer you'd like to test dynamic DNS functionality on
.PARAMETER RetryInterval
	The total time you'd like the script to check the computer's host DNS record for a current timestamp
#>
[CmdletBinding()]
[OutputType('System.Management.Automation.PSCustomObject')]
param (
	[Parameter(Mandatory,
		ValueFromPipeline,
		ValueFromPipelineByPropertyName)]
	[ValidateScript({Test-Connection -ComputerName $_ -Quiet -Count 1})]
	[string]$Computername,
	[Parameter()]
	[int]$RetryInterval = 10
)

begin {
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	Set-StrictMode -Version Latest
	try {
		## http://www.leeholmes.com/blog/2009/11/20/testing-for-powershell-remoting-test-psremoting/
		function Test-PsRemoting {
			param (
				[Parameter(Mandatory = $true)]
				$computername
			)
			
			try {
				Write-Verbose "Testing for enabled remoting"
				$result = Invoke-Command -ComputerName $computername { 1 }
			} catch {
				return $false
			}
			
			## I’ve never seen this happen, but if you want to be
			## thorough….
			if ($result -ne 1) {
				Write-Verbose "Remoting to $computerName returned an unexpected result."
				return $false
			}
			$true
		}
		
		function Get-ClientPrimaryDns ($NicIndex) {
			Write-Verbose "Finding primary DNS server for client '$Computername'"
			$Result = Get-WmiObject -ComputerName $Computername -Class win32_networkadapterconfiguration -Filter "IPenabled = $true AND Index = $NicIndex"
			if ($Result) {
				$PrimaryDnsServer = $Result.DNSServerSearchOrder[0]
				Write-Verbose "Found computer '$Computername' primary DNS server as '$PrimaryDnsServer'"
				$PrimaryDnsServer
			} else {
				$false	
			}
		}
		
		function Get-ClientPrimaryDnsSuffix {
			$Registry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Computername)
			$RegistryKey = $Registry.OpenSubKey("SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", $true)
			$DnsSuffix = $RegistryKey.GetValue('NV Domain')
			if ($DnsSuffix) {
				Write-Verbose "Computer '$Computername' primary DNS suffix is '$DnsSuffix'"
				$DnsSuffix
			} else {
				Write-Warning "Could not find primary DNS suffix on computer '$Computername'"
				$false
			}
		}
		
		function Get-DynamicDnsEnabledNicIndex {
			$EnabledIndex = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $Computername -Filter { IPEnabled = 'True' } | where { $_.FullDNSRegistrationEnabled }
			if (!$EnabledIndex) {
				Write-Warning 'No NIC detected to have dynamic DNS enabled'
				$false
			} elseif ($EnabledIndex -is [array]) {
				Write-Warning 'Multiple NICs detected having dynamic DNS enabled.  This is not supported'
				$false
			} else {
				Write-Verbose "Found NIC with index '$($EnabledIndex.Index)' as dynamic DNS enabled"
				[int]$EnabledIndex.Index
			}
		}
		
		function Validate-IsInRefreshPeriod($Record) {
			if ($Record.Timestamp.AddDays($ZoneAging.NoRefreshInterval.Days) -lt (Get-Date)) {
				Write-Verbose 'The record is in the refresh period'
				$true
			} else {
				Write-Verbose 'The record is not in the refresh period'
				$false
			}
		}
		
		$ResultHash = @{ 'Computername' = $Computername; }
		
		$EnabledNicIndex = Get-DynamicDnsEnabledNicIndex
		if ($EnabledNicIndex -isnot [int]) {
			throw "Computer '$Computername' does not have dynamic DNS enabled on any interface or on more than 1 interface"
			exit
		}
		
		$PrimaryDnsServer = Get-ClientPrimaryDns $EnabledNicIndex
		if (! $PrimaryDnsServer) {
			throw "Could not find computer '$Computername' primary DNS server."
			exit
		}
		$DnsZone = Get-ClientPrimaryDnsSuffix
		if (! $DnsZone) {
			throw "Could not find computer '$Computername' primary DNS suffix."
			exit
		}
		$script:ZoneAging = Get-DnsServerZoneAging -Name $DnsZone -ComputerName $PrimaryDnsServer
		
		$Record = Get-DnsServerResourceRecord -ComputerName $PrimaryDnsServer -Name $Computername -RRType A -ZoneName $DnsZone -ea silentlycontinue
		if ($Record -and !($Record.TimeStamp)) {
			throw "The '$($Record.Hostname)' record is static and has no timestamp."
		} elseif (!$Record) {
			Write-Verbose "The '$Computername' record does not exist on the DNS server '$($PrimaryDnsServer)'."
		} elseif (!(Validate-IsInRefreshPeriod $Record)) {
			Write-Verbose "The '$($Record.Hostname)' record timestamp is still within the '$DnsZone' zone no-refresh period."
			$ResultHash.Result = $true
			[pscustomobject]$ResultHash
			exit
		}
} catch {
	Write-Error $_.Exception.Message
	break
}
}

process {
	try {
		## Need to round the time down to the nearest hour.  This is because when the DNS record's timestamp is updated it will
		## always do this. 
		$NowRoundHourDown = ((Get-Date).Date).AddHours((Get-Date).Hour)
		if (Test-PsRemoting $Computername) {
			Write-Verbose "Remoting already enabled on $Computername"
			Invoke-Command -ComputerName $Computername -ScriptBlock { ipconfig /registerdns } | Out-Null
		} else {
			Write-Warning "Remoting not enabled on $Computername. Will attempt to use WMI to create remote process"
			if (([WMICLASS]"\\$Computername\Root\CIMV2:Win32_Process").create("ipconfig /registerdns").ReturnValue -ne 0) {
				throw "Unable to successfully start remote process on '$Computername'"	
			}
		}
		Write-Verbose "Initiated DNS record registration on '$Computername'.  Waiting for record to update on DNS server.."
		## Wait at least 5 seconds before even starting to give the record a chance to update.
		Start-Sleep -Seconds 5
		for ($i = 0; $i -lt $RetryInterval; $i++) {
			$Record = Get-DnsServerResourceRecord -ComputerName $PrimaryDnsServer -Name $Computername -RRType A -ZoneName $DnsZone -ea SilentlyContinue
			if ($Record) {
				$Timestamp = $Record.Timestamp
			}
			if ($Timestamp -eq $NowRoundHourDown) {
				Write-Verbose "Host DNS record for '$Computername' matches current rounded time of $NowRoundHourDown"
				$ResultHash.Result = $true
				[pscustomobject]$ResultHash
				exit
			} else {
				Write-Verbose "Host DNS record timestamp '$Timestamp' for '$Computername' does not match current rounded time of '$NowRoundHourDown'. Trying again..."
			}
			Start-Sleep -Seconds 1
		}
		
		$ResultHash.Result = $false
		[pscustomobject]$ResultHash
	} catch {
		Write-Error $_.Exception.Message
	}
}