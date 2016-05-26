#Requires -Version 4 -Module DhcpServer

[CmdletBinding(DefaultParameterSetName = 'Default')]
param (
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string[]]$DhcpServer,

	[Parameter(ParameterSetName = 'HostName')]
	[ValidateNotNullOrEmpty()]
	[string[]]$HostName,
	
	[Parameter(ParameterSetName = 'MacAddress')]
	[ValidateNotNullOrEmpty()]
	[string[]]$MacAddress,

	[Parameter(ParameterSetName = 'IpAddress')]
	[ValidateNotNullOrEmpty()]
	[ipaddress[]]$IpAddress
)

begin
{
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	Set-StrictMode -Version Latest
}

process
{
	try
	{
		if (-not $PSBoundParameters.ContainsKey('DhcpServer'))
		{
			if ($DhcpServer = Get-DhcpServerInDC)
			{
				$DhcpServer = $DhcpServer.DnsName
			}
		}
		
		@($DhcpServer).foreach({
			
			try
			{
				$srv = $_
				if (-not (Test-Connection -ComputerName $srv -Quiet -Count 1))
				{
					throw "The DHCP server [$($srv)] is not available."
				}
				
				$leaseParams = @{
					'ComputerName' = $srv
				}
				
				if ($PSBoundParameters.ContainsKey('MacAddress')) {
					$leaseParams.ClientId = $MacAddress
				}
				
				@(Get-DhcpServerv4Scope -ComputerName $srv).foreach({
					if ($PSBoundParameters.ContainsKey('Ipaddress')) {
						$leaseParams.IpAddress = $IpAddress
					}
					else
					{
						$leaseParams.ScopeId = $_.ScopeId	
					}
					
					$leases = Get-DhcpServerv4Lease @leaseParams
					if ($PSBoundParameters.ContainsKey('HostName')) {
						@($leases).where({$_.Hostname -in $HostName})
					}
					
				})
			}
			catch
			{
				Write-Error -Message $_.Exception.Message
			}
			
		})
	}
	catch
	{
		Write-Error -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
	}
}