#requires -Version 4
[CmdletBinding()]
param
(
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[ValidatePattern('^\w+\.\w+\.\w+$')]
	[string]$Name,
	
	[Parameter()]
	[switch]$NetBiosFallback,
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[ValidateRange(1, [int]::MaxValue)]
	[int]$Timeout = 60,
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$Server
	
)

begin
{
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	Clear-DnsClientCache
}

process
{
	try
	{
		$resolveParams = @{
			Name = $Name
			ErrorAction = 'SilentlyContinue'
		}
		if ($NetBiosFallback.IsPresent)
		{
			$resolveParams.NetBiosFallback = $true
		}
		else
		{
			$resolveParams.DnsOnly = $true
		}
		if ($PSBoundParameters.ContainsKey('Server'))
		{
			$resolveParams.Server = $Server
		}
		$timer = [Diagnostics.Stopwatch]::StartNew()
		while (-not (Resolve-DnsName @resolveParams))
		{
			if ($timer.Elapsed.TotalSeconds -ge $Timeout)
			{
				throw "Timeout exceeded. Giving up on DNS record availability for [$($Name)]"
			}
			Start-Sleep -Seconds 10
		}
	}
	catch
	{
		throw $_
	}
	finally
	{
		$timer.Stop()
	}
}