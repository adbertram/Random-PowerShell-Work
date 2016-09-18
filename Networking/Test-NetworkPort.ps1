function Test-NetworkPort
{
<#
.SYNOPSIS
	This function tests for open TCP/UDP ports.
.DESCRIPTION
	This function tests any TCP/UDP port to see if it's open or closed.
.NOTES
	Known Issue: If this function is called within 10-20 consecutively on the same port
		and computer, the UDP port check will output $false when it can be
		$true.  I haven't figured out why it does this.
.PARAMETER Computername
	One or more remote, comma-separated computer names
.PARAMETER Port
	One or more comma-separated port numbers you'd like to test.
.PARAMETER Protocol
	The protocol (UDP or TCP) that you'll be testing
.PARAMETER TcpTimeout
	The number of milliseconds that the function will wait until declaring
	the TCP port closed.
.PARAMETER
	The number of millieconds that the function will wait until declaring
	the UDP port closed.
.EXAMPLE
	PS> Test-Port -Computername 'LABDC','LABDC2' -Protocol TCP 80,443
	
	This example tests the TCP network ports 80 and 443 on both the LABDC
	and LABDC2 servers.
#>
	[CmdletBinding(DefaultParameterSetName = 'TCP')]
	[OutputType([System.Management.Automation.PSCustomObject])]
	param (
		[Parameter(Mandatory)]
		[string]$ComputerName,
		
		[Parameter(Mandatory)]
		[int]$Port,
		
		[Parameter()]
		[ValidateSet('TCP', 'UDP')]
		[string]$Protocol = 'TCP',
		
		[Parameter(ParameterSetName = 'TCP')]
		[int]$TcpTimeout = 1000,
		
		[Parameter(ParameterSetName = 'UDP')]
		[int]$UdpTimeout = 1000
	)
	process
	{
		if ($Protocol -eq 'TCP')
		{
			$TcpClient = New-Object System.Net.Sockets.TcpClient
			$Connect = $TcpClient.BeginConnect($ComputerName, $Port, $null, $null)
			$Wait = $Connect.AsyncWaitHandle.WaitOne($TcpTimeout, $false)
			if (!$Wait)
			{
				$TcpClient.Close()
			}
			else
			{
				$TcpClient.EndConnect($Connect)
				$TcpClient.Close()
				$result = $true
			}
			$TcpClient.Close()
			$TcpClient.Dispose()
		}
		elseif ($Protocol -eq 'UDP')
		{
			$UdpClient = New-Object System.Net.Sockets.UdpClient
			$UdpClient.Client.ReceiveTimeout = $UdpTimeout
			$UdpClient.Connect($ComputerName, $Port)
			$a = new-object system.text.asciiencoding
			$byte = $a.GetBytes("$(Get-Date)")
			[void]$UdpClient.Send($byte, $byte.length)
			#IPEndPoint object will allow us to read datagrams sent from any source.
			Write-Verbose "$($MyInvocation.MyCommand.Name) - Creating remote endpoint"
			$remoteendpoint = New-Object system.net.ipendpoint([system.net.ipaddress]::Any, 0)
			try
			{
				#Blocks until a message returns on this socket from a remote host.
				Write-Verbose "$($MyInvocation.MyCommand.Name) - Waiting for message return"
				$receivebytes = $UdpClient.Receive([ref]$remoteendpoint)
				[string]$returndata = $a.GetString($receivebytes)
				If ($returndata)
				{
					$result = $true
				}
			}
			catch
			{
				Write-Verbose "$($MyInvocation.MyCommand.Name) - '$ComputerName' failed port test on port '$Protocol`:$Port' with error '$($_.Exception.Message)'"
			}
			$UdpClient.Close()
			$UdpClient.Dispose()
		}
		if ($result)
		{
			$true
		}
		else
		{
			$false
		}
	}
}