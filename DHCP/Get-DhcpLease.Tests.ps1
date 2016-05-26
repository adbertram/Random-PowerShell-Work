describe 'Get-DhcpLease' {
	
	mock 'Get-DhcpServerv4Scope' {
		[pscustomobject]@{ 'ScopeId' = '10.10.10.0' }
	}
	
	mock 'Get-DhcpServerv4Lease' {
		return $null
	}
	
	mock 'Get-DhcpServerInDc' {
		@(
			[pscustomobject]@{ 'DNSName' = 'SRV1' }
			[pscustomobject]@{ 'DNSName' = 'SRV2' }
		)
	}
	
	it 'queries all DHCP servers in domain if no DHCP server passed' {
		
		@('SRV1', 'SRV2')
		{
			mock 'Test-Connection' {
				$true
			} -ParameterFilter { $Computername -eq $_ }
			
			& "$PSScriptRoot\Get-DhcpLease.ps1"
			
			Assert-MockCalled 'Test-Connection'
		}
	}
	
	it 'only queries DHCP server passed' {
		
		mock 'Test-Connection' {
			$true
		} -ParameterFilter { $Computername -eq 'SRV1' }
		
		& "$PSScriptRoot\Get-DhcpLease.ps1" -DhcpServer 'SRV1'
		
		Assert-MockCalled 'Test-Connection'
		
	}
	
	it 'limits leases to only those matching IP address' {
		
		mock 'Get-DhcpServerv4Lease' {
			return $null
		} -ParamterFilter { $IpAddress -eq '1.1.1.1' }
		
		& "$PSScriptRoot\Get-DhcpLease.ps1" -IpAddress '1.1.1.1' -DhcpServer 'SRV1'
		
		Assert-MockCalled 'Get-DhcpServerv4Lease'
	}
	
	it 'limits leases to only those matching hostname' {
		
		mock 'Get-DhcpServerv4Lease' {
			return [pscustomobject]@{ 'HostName' = 'SRV2' }
		} -ParamterFilter { $HostName -eq 'SRV2' }
		
		& "$PSScriptRoot\Get-DhcpLease.ps1" -HostName 'SRV2' -DhcpServer 'SRV1'
		
		Assert-MockCalled 'Get-DhcpServerv4Lease'
		
	}
	
	it 'limits leases to only those matching MAC address' {
		
		mock 'Get-DhcpServerv4Lease' {
			return $null
		} -ParamterFilter { $ClientId -eq '00:00' }
		
		& "$PSScriptRoot\Get-DhcpLease.ps1" -MacAddress '00:00' -DhcpServer 'SRV1'
		
		Assert-MockCalled 'Get-DhcpServerv4Lease'
		
	}
	
	it 'returns a non-terminating error if a DHCP server to be queried is offline' {
		
		mock 'Test-Connection' {
			return $false
		} -ParamterFilter {$ComputerName -eq 'SRV1'}
		
		& "$PSScriptRoot\Get-DhcpLease.ps1" -DhcpServer 'SRV1' -ev myErr -ea SilentlyContinue
		
		Assert-MockCalled 'Test-Connection'
		$myErr | should not be nullorempty
		
		
	}
}