#Requires -Version 3

<#
.NOTES
	Created on: 			5/21/2014 1:33 PM
	Created by: 			Adam Bertram
	Filename:   			Send-WolProxyRequest.ps1
	General Requirements: 	Read access to a System Center Configuration Manager database
	Requirements:  
		Wake On LAN Command Line Utility (http://www.depicus.com/wake-on-lan/wake-on-lan-cmd.aspx)
	Todos:	
		Remove the dependency on wolcmd.exe.  Use the Net.Sockets.UdpClient object instead.
		Speed this up by using jobs
.DESCRIPTION
	This script is designed to send a WOL magic packet to a specified computer.  If the specified computer is not
	on the same network as the originatnating computer, it will attempt to find a "proxy" Windows computer to
	initiate the WOL send.  This gets around traditional network multicasting requirements.

	This script currently requires access to a System Center Configuration Manager database.  This 
	script uses it to find the various network information about the specified computer to wake.

	This script uses a text file to store known good candidates to be used as WOL proxies.  It can either
	be prepopulated with Windows PCs or as you use this script more the script will populate it with
	all of the WOL proxies it picks as to speed up the selection process.
.EXAMPLE
	.\Send-WolProxyRequest.ps1 -Computername COMPUTERNAME    
.EXAMPLE
    .\Send-WolProxyRequest.ps1 -Computername COMPUTERNAME -UsePsRemoting
.PARAMETER Computername
 	This computer name that you'd like to attempt to wake up.
.PARAMETER ConfigMgrSite
	The site code of your ConfigMgr site
.PARAMETER ConfigMgrSiteServer
	The computer name of your ConfigMgr site server hosting your database
.PARAMETER WolCmdFilePath
	The file path where the wolcmd.exe utility is located
.PARAMETER UsePsRemoting
	Use this switch if you'd like to use Powershell remoting to kick off the WOL attempt on the WOL proxy 
	rather than using WMI to initiate the remote process
.PARAMETER KnownGoodWolProxyHostsFilePath
	The file path to the text file that contains any Windows computers that were previously
	found to be suitable WOL proxies.
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory = $True,
			ValueFromPipeline = $True,
			ValueFromPipelineByPropertyName = $True)]
	[string]$Computername,
	[Parameter(Mandatory = $False,
			ValueFromPipeline = $False,
			ValueFromPipelineByPropertyName = $False)]
	[string]$ConfigMgrSite = 'UHP',
	[Parameter(Mandatory = $False,
			ValueFromPipeline = $False,
			ValueFromPipelineByPropertyName = $False)]
			[ValidateScript({ Test-Connection $_ -Quiet -Count 1 })]
	[string]$ConfigMgrSiteServer = 'CONFIGMANAGER',
	[Parameter(Mandatory = $False,
			ValueFromPipeline = $False,
			ValueFromPipelineByPropertyName = $False)]
			[ValidateScript({ Test-Path $_ })]
	[string]$WolCmdFilePath = 'wolcmd.exe',
	[Parameter(Mandatory = $False,
			ValueFromPipeline = $False,
			ValueFromPipelineByPropertyName = $False)]
	[switch]$UsePsRemoting = $false,
	[Parameter(Mandatory = $False,
			   ValueFromPipeline = $False,
			   ValueFromPipelineByPropertyName = $False)]
	[string]$KnownGoodWolProxyHostsFilePath = "$($env:USERPROFILE)\desktop\KnownGoodWolProxies.txt"
)

begin {
	
	function ConvertTo-DecimalIP {
	  <#
	    .Synopsis
	      Converts a Decimal IP address into a 32-bit unsigned integer.
	    .Description
	      ConvertTo-DecimalIP takes a decimal IP, uses a shift-like operation on each octet and returns a single UInt32 value.
		http://www.indented.co.uk/2010/01/23/powershell-subnet-math/
	    .Parameter IPAddress
	      An IP Address to convert.
	  #>
		
		[CmdLetBinding()]
		param (
			[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
			[Net.IPAddress]$IPAddress
		)
		
		process {
			$i = 3; $DecimalIP = 0;
			$IPAddress.GetAddressBytes() | ForEach-Object { $DecimalIP += $_ * [Math]::Pow(256, $i); $i-- }
			
			return [UInt32]$DecimalIP
		}
	}
	
	function ConvertTo-DottedDecimalIP {
	  <#
	    .Synopsis
	      Returns a dotted decimal IP address from either an unsigned 32-bit integer or a dotted binary string.
	    .Description
	      ConvertTo-DottedDecimalIP uses a regular expression match on the input string to convert to an IP address.
		http://www.indented.co.uk/2010/01/23/powershell-subnet-math/
	    .Parameter IPAddress
	      A string representation of an IP address from either UInt32 or dotted binary.
	  #>
		
		[CmdLetBinding()]
		param (
			[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
			[String]$IPAddress
		)
		
		process {
			Switch -RegEx ($IPAddress) {
				"([01]{8}.){3}[01]{8}" {
					return [String]::Join('.', $($IPAddress.Split('.') | ForEach-Object { [Convert]::ToUInt32($_, 2) }))
				}
				"\d" {
					$IPAddress = [UInt32]$IPAddress
					$DottedIP = $(For ($i = 3; $i -gt -1; $i--) {
						$Remainder = $IPAddress % [Math]::Pow(256, $i)
						($IPAddress - $Remainder) / [Math]::Pow(256, $i)
						$IPAddress = $Remainder
					})
					
					return [String]::Join('.', $DottedIP)
				}
				default {
					Write-Error "Cannot convert this format"
				}
			}
		}
	}
	
	function Get-NetworkAddress {
	  	<#
	    .Synopsis
	      Takes an IP address and subnet mask then calculates the network address for the range.
	    .Description
	      Get-NetworkAddress returns the network address for a subnet by performing a bitwise AND 
	      operation against the decimal forms of the IP address and subnet mask. Get-NetworkAddress 
	      expects both the IP address and subnet mask in dotted decimal format.
		http://www.indented.co.uk/2010/01/23/powershell-subnet-math/
	    .Parameter IPAddress
	      Any IP address within the network range.
	    .Parameter SubnetMask
	      The subnet mask for the network.
	  	#>
		
		[CmdLetBinding()]
		param (
			[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
			[Net.IPAddress]$IPAddress,
			
			[Parameter(Mandatory = $true, Position = 1)]
			[Alias("Mask")]
			[Net.IPAddress]$SubnetMask
		)
		
		process {
			[pscustomobject]@{ 'NetworkAddress' = (ConvertTo-DottedDecimalIP ((ConvertTo-DecimalIP $IPAddress) -band (ConvertTo-DecimalIP $SubnetMask))) }
		}
	}
	
	function ConvertTo-Mask {
	  <#
	    .Synopsis
	      Returns a dotted decimal subnet mask from a mask length.
	    .Description
	      ConvertTo-Mask returns a subnet mask in dotted decimal format from an integer value ranging 
	      between 0 and 32. ConvertTo-Mask first creates a binary string from the length, converts 
	      that to an unsigned 32-bit integer then calls ConvertTo-DottedDecimalIP to complete the operation.
	    .Parameter MaskLength
	      The number of bits which must be masked.
	  #>
		
		[CmdLetBinding()]
		param (
			[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
			[Alias("Length")]
			[ValidateRange(0, 32)]
			$MaskLength
		)
		
		Process {
			return ConvertTo-DottedDecimalIP ([Convert]::ToUInt32($(("1" * $MaskLength).PadRight(32, "0")), 2))
		}
	}
	
	function Get-NetworkRange([String]$IP, [String]$Mask) {
		if ($IP.Contains("/")) {
			$Temp = $IP.Split("/")
			$IP = $Temp[0]
			$Mask = $Temp[1]
		}
		
		if (!$Mask.Contains(".")) {
			$Mask = ConvertTo-Mask $Mask
		}
		
		$DecimalIP = ConvertTo-DecimalIP $IP
		$DecimalMask = ConvertTo-DecimalIP $Mask
		
		$Network = $DecimalIP -band $DecimalMask
		$Broadcast = $DecimalIP -bor ((-bnot $DecimalMask) -band [UInt32]::MaxValue)
		
		for ($i = $($Network + 1); $i -lt $Broadcast; $i++) {
			ConvertTo-DottedDecimalIP $i
		}
	}
	
	function Get-OfflineComputerNetworkInformation ($Computername) {
		$WmiQuery = "SELECT DISTINCT * 
		FROM SMS_R_System AS sys 
		JOIN SMS_G_System_NETWORK_ADAPTER_CONFIGURATION AS net ON net.ResourceID = sys.ResourceID 
		WHERE sys.Name = '$ComputerName' AND
		net.IPAddress IS NOT NULL"
		
		$WmiParams = @{
			'ComputerName' = $ConfigMgrSiteServer
			'Namespace' = "root\sms\site_$ConfigMgrSite"
			'Query' = $WmiQuery
		}
		
		## Query all network interfaces on the local machine and parse out IP address, subnet mask and the MAC
		Write-Verbose "Querying site server '$ConfigMgrSiteServer' with query '$WmiQuery'"
		try {
			$Output = @{ }
			$NetworkInfo = Get-WmiObject @WmiParams
			if (!$NetworkInfo) {
				throw "Computer '$Computername' could not be found in the SCCM database"
			} else {
				$NetworkInfo | foreach {
					$Output.IPAddress = [string]([regex]'\b(?:\d{1,3}\.){3}\d{1,3}\b').Matches($_.net.IPAddress)
					$Output.SubnetMask = [string]([regex]'\b(?:\d{1,3}\.){3}\d{1,3}\b').Matches($_.net.IPSubnet)
					$Output.MACAddress = [string](($_.net.MACAddress.replace(":", "")).replace("-", "")).replace(".", "")
				}
			}
			[pscustomobject]$Output
		} catch {
			Write-Error $_.Exception.Message
		}
	}
	
	function Get-LocalIpNetwork {
		Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'True'" | where { $_.IPAddress -and $_.IPSubnet } | foreach {
			[pscustomobject]@{ 'LocalIPNetwork' = (Get-NetworkAddress -IPAddress $_.IPAddress[0] -SubnetMask $_.IPSubnet[0]) }
		}
	}
	
	function Test-Ping {
		param ($ComputerName)
		try {
			$oPing = new-object system.net.networkinformation.ping;
			if (($oPing.Send($ComputerName, 200).Status -eq 'TimedOut')) {
				$false
			} else {
				$true
			}
		} catch [System.Exception] {
			$false
		}##endtry
	}
	
	function Test-Wmi ($IpAddress) {
		try {
			$Result = ([WMICLASS]"\\$IpAddress\Root\CIMV2:Win32_Process").create("hostname")
			if ($Result.ReturnValue -eq 0) {
				$true
			} else {
				$false	
			}
		} catch {
			$false
		}
	}
	
	function Validate-IsValidHost ($IpAddress) {
		try {
			Write-Verbose "Testing $IpAddress Ping"
			if (Test-Ping -ComputerName $IpAddress) {
				Write-Verbose "Testing $IpAddress Ping - Success"
				## Assume if the C$ share is available, it's a Windows computer we can
				## copy the wolcmd utility to and run.  This could be better.
				Write-Verbose "Testing $IpAddress SMB share file copy and removal"
				## Create a temp text file and try to copy it over to test access
				$TestFilePath = "$($env:SystemDrive)\testcopy.txt"
				Add-Content -Path $TestFilePath -Value '' -Force
				Copy-Item -Path $TestFilePath -Destination "\\$IpAddress\c$" -Force
				Remove-Item -Path "\\$IpAddress\c$\testcopy.txt" -Force
				## If it hasn't thrown an error yet then we've confirmed we can copy and delete a file from it
				Write-Verbose "Testing $IpAddress SMB share file copy and removal - Success"
				Write-Verbose "Testing $IpAddress remote WMI process creation"
				if (Test-Wmi -IpAddress $IpAddress) {
					Write-Verbose "Testing $IpAddress remote WMI process creation - Success"
					Write-Verbose "All tests passed. $IpAddress is a good WOL proxy"
					$true
				} else {
					throw 'Remote process could not be created with WMI'
				}
			} else {
				throw 'Host is offline'
			}
		} catch {
			Write-Warning "Test failed with error '$($_.Exception.Message)' for $IpAddress"
			$false
		}
	}
	
	function Get-WolProxy ($IpAddress, $SubnetMask) {
		## Check if any known good WOL proxy exists before scanning all the IPs
		## in that network
		$IpNetwork = Get-NetworkAddress -IPAddress $IpAddress -SubnetMask $SubnetMask
		$KnownGoodWolProxy = Get-KnownGoodWolProxy -IpNetwork $IpNetwork.NetworkAddress
		if ($KnownGoodWolProxy) {
			return $KnownGoodWolProxy
		} else {
			$HostIps = Get-NetworkRange -IP $IpAddress -Mask $SubnetMask
			foreach ($Ip in $HostIps) {
				Write-Verbose "Checking $Ip if good candidate for WOL proxy..."
				## Check to see if our WOL proxy PC is online
				if (Validate-IsValidHost -IpAddress $Ip) {
					Write-Verbose "WOL Proxy found: $Ip"
					
					## Add this computer to the known good proxy list for later
					New-KnownGoodWolProxy -HostProxy @{ 'IpAddress' = $Ip; 'SubnetMask' = $SubnetMask }
					
					return $Ip
				} else {
					Write-Verbose "IP address '$Ip' will not work as a WOL proxy"	
				}
			}
			$false
		}
	}
	
	## WOL proxy Windows hosts that are online and accessible
	function New-KnownGoodWolProxy ([hashtable]$HostProxy) {
		if (!(Get-KnownGoodWolProxy $HostProxy.IpAddress)) {
			Write-Verbose "The '$($HostProxy.IpAddress)' host is not yet in the known good WOL proxy host file."
			## Create IP network from IP address and subnet mask
			$IpNetwork = Get-NetworkAddress -IPAddress $HostProxy.IpAddress -SubnetMask $HostProxy.SubnetMask
			Write-Verbose "Adding IP Address: $($HostProxy.IpAddress) IP Network: $IpNetwork SubnetMask: $($HostProxy.SubnetMask) to known good WOL proxy host file"
			[pscustomobject]@{
				'IpAddress' = $HostProxy.IpAddress;
				'IpNetwork' = $IpNetwork.NetworkAddress;
				'SubnetMask' = $HostProxy.SubnetMask
			} | Export-Csv -Path $KnownGoodWolProxyHostsFilePath -Append -NoTypeInformation
		}
		
	}
	
	function Remove-KnownGoodWolProxy ($IpAddress) {
		$NewCsvContents = Import-Csv -Path $KnownGoodWolProxyHostsFilePath | where { $_.IpAddress -ne $IpAddress }
		##TODO: This removes the row and headers if only 1 row exists
		$NewCsvContents | Export-Csv -Path $KnownGoodWolProxyHostsFilePath -NoTypeInformation
	}
	
	## Searches the known good WOL proxy file for an accessible host in the IP network specified
	function Get-KnownGoodWolProxy ([string]$IpNetwork) {
		if (!(Test-Path $KnownGoodWolProxyHostsFilePath)) {
			Write-Verbose "Known good WOL proxy host file at '$KnownGoodWolProxyHostsFilePath' does not exist"
			$false
		} else {
			$Hosts = Import-Csv -Path $KnownGoodWolProxyHostsFilePath | where { $_.IpNetwork -eq $IpNetwork }
			if (!$Hosts) {
				Write-Verbose "No known good WOL proxy hosts found in IP network '$IpNetwork'"
				$false
			} else {
				$HostsOnNet = $Hosts | where { $_.IpNetwork -eq $IpNetwork }
				if ($HostsOnNet) {
					Write-Verbose "$(($HostsOnNet | measure -Sum -ea silentlycontinue).Count) (unknown accessibility) known good WOL proxy hosts found on IP network '$IpNetwork'"
					Write-Verbose 'Checking previously known good WOL proxy hosts if still usable'
					$AccessibleHost = $HostsOnNet | where { Validate-IsValidHost $_.IpAddress } | select -First 1 -ExpandProperty IpAddress
					if ($AccessibleHost) {
						Write-Verbose "Found hostname '$AccessibleHost' still to be a good WOL proxy host"
						$AccessibleHost
					} else {
						Remove-KnownGoodWolProxy -IpAddress $_.IpAddress
					}
				} else {
					Write-Verbose "No accessible, known good WOL proxy hosts on the '$IpNetwork' found"
				}
			}
		}
	}
	
	function Send-WolPacketLocally ($MacAddress, $IpNetwork, $SubnetMask) {
		& $WolCmdFilePath $MacAddress $IPNetwork $SubnetMask $WolUdpPort 2>&1> $null
	}
	
	function Invoke-WolProxy ($IpAddress, $OfflineMacAddress, $OfflineIpNetwork, $OfflineSubnetMask) {
		## Remove the dependency on wolcmd.exe.  Use the Net.Sockets.UdpClient object instead.
		## Copy wolcmd to the remote proxy computer
		Write-Verbose "Copying $WolCmdFilePath to \\$IpAddress\c`$..."
		Copy-Item $WolCmdFilePath "\\$IpAddress\c$" -Force
		
		$WolCmdString = "C:\$($WolCmdFilePath | Split-Path -Leaf) $OfflineMacAddress $OfflineIPNetwork $OfflineSubnetMask $WolUdpPort"
		Write-Verbose "Initiating the string `"$WolCmdString`"..."
		Write-Verbose "Connecting to $IpAddress and attempting WOL proxy function via WMI RPC method..."
		$Result = ([WMICLASS]"\\$IpAddress\Root\CIMV2:Win32_Process").create($WolCmdString)
		if ($Result) {
			Write-Verbose "Waiting for process ID $($Result.ProcessID) on IP $IpAddress..."
			while (Get-Process -Id $Result.ProcessID -ComputerName $IpAddress -ErrorAction 'SilentlyContinue') {
				sleep 1
			}
			Write-Verbose "Process ID $($Result.ProcessID) has exited"
		} else {
			Write-Warning "Failed to initiate WMI process creation on '$IpAddress'.  Exit code was '$($NewProcess.ReturnValue)'"
		}
		#}
		## Cleanup all files copied to the proxy computer
		Write-Verbose 'Cleaning up file remnants on WOL proxy computer...'
		if (Test-Path "\\$IpAddress\c`$\$($WolCmdFilePath | Split-Path -Leaf)") {
			Remove-Item -Path "\\$IpAddress\c`$\$($WolCmdFilePath | Split-Path -Leaf)" -Force
		}
	}
	
	if (Test-Connection -ComputerName $Computername -Quiet -Count 1) {
		Write-Verbose -Message "The computer $Computername is already online"
		return
	}
	
	## Find all of the IP/subnet masks on the local computer
	$LocalIPAddressNetworks = Get-LocalIpNetwork
	Write-Verbose "Found $($LocalIPAddressNetworks.Count) local IP networks"
	
	## Common WOL UDP ports are 7 and 9
	$WolUdpPort = 9
	
	$OfflineComputerNetwork = Get-OfflineComputerNetworkInformation $Computername
	
}
process {
	try {
		## TODO: Make this run in parallel by jobs of a foreach -parallel workflow loop
		foreach ($Network in $OfflineComputerNetwork) {
			Write-Verbose "Processing IP address $($Network.IPAddress)..."
			Write-Verbose "Checking the remote network to see if it's on any local IP network..."
			$RemoteIpNetwork = Get-NetworkAddress -IPAddress $Network.IpAddress -SubnetMask $Network.SubnetMask
			if ($LocalIPNetworks.LocalIPNetwork -contains $RemoteIpNetwork.NetworkAddress) {
				Write-Verbose 'IP found to be on local subnet. No WOL proxy needed. Sending WOL directly to the intended machine...'
				Send-WolPacketLocally -MacAddress $Network.MacAddress -IpNetwork $RemoteIpNetwork.NetworkAddress -SubnetMask $Network.SubnetMask
			} else {
				Write-Verbose 'IP not found to be on local subnet. Getting WOL proxy computer...'
				$WolProxy = Get-WolProxy -IpAddress $Network.IPAddress -SubnetMask $Network.SubnetMask
				if (!$WolProxy) {
					Write-Warning "Unable to find a WOL proxy for '$Computername'"
				} else {
					Invoke-WolProxy -OfflineIpNetwork $RemoteIpNetwork.NetworkAddress -OfflineMacAddress $Network.MacAddress -OfflineSubnetMask $Network.SubnetMask -IpAddress $WolProxy
				}
			}
		}
	} catch {
		Write-Error $_.Exception.Message
	}
}