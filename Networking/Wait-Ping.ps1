function Wait-Ping
{
	<#
	.SYNOPSIS
		Wait-Ping holds execution control until a computer computer responds to ping. By default, it will wait for up to 5 minutes
		(600 seconds) and give up. If the computer becomes available to ping within that time, Wait-Ping will release control and
		allow code execution to continue.
		
	.EXAMPLE
		PS> Wait-Ping -ComputerName MYSERVER
	
		This example will ping MYSERVER. If MYSERVER responds, Wait-Ping will immediately return control. If MYSERVER does not respond,
		Wait-Ping will attempt to ping MYSERVER ever 10 seconds up to a maximum duration of 5 minutes. If MYSERVER comes back online
		during that time, Wait-Ping will release control. If 5 minutes is passed, Wait-Ping will release control with a warning
		stating the timeout was exceeded.
		
	.PARAMETER ComputerName
		The Netbios, DNS FQDN or IP address of the computer you'd like to ping. This is mandatory.
	
	.PARAMETER Offline
		Use this switch parameter to perform the opposite of waiting for a ping. This will reverse functionality and wait for
		ComputerName to go offline.
	
	.PARAMETER Timeout
		The maximum amount of seconds that you'd like to wait for ComputerName to become available. By default, this is set to
		600 seconds (5 minutes).
	
	.PARAMETER CheckEvery
		The interval at which ComputerName is pinged during the timeout period to check to see if ComputerName has become available
		to ping yet.
	#>
	[CmdletBinding()]
	[OutputType()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$Timeout = 600,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$CheckEvery = 10
		
	)
	try {
		$timer = [Diagnostics.Stopwatch]::StartNew();
		Write-Verbose -Message "Waiting for [$ComputerName] to become pingable";
		if ($Offline.IsPresent)
		{
			while (Test-Connection -ComputerName $ComputerName -Quiet -Count 1)
			{
				Write-Verbose -Message "Waiting for [$($ComputerName)] to go offline..."
				if ($timer.Elapsed.TotalSeconds -ge $Timeout)
				{
					throw "Timeout exceeded. Giving up on [$ComputerName] going offline";
				}
				Start-Sleep -Seconds 10;
			}
			Write-Verbose -Message "[$($ComputerName)] is now offline. We waited $([Math]::Round($timer.Elapsed.TotalSeconds, 0)) seconds";
		}
		else
		{
			while (-not (Test-Connection -ComputerName $ComputerName -Quiet -Count 1))
			{
				Write-Verbose -Message "Waiting for [$($ComputerName)] to become pingable..."
				if ($timer.Elapsed.TotalSeconds -ge $Timeout)
				{
					throw "Timeout exceeded. Giving up on ping availability to [$ComputerName]";
				}
				Start-Sleep -Seconds 10;
			}
			Write-Verbose -Message "Ping is now available on [$($ComputerName)]. We waited $([Math]::Round($timer.Elapsed.TotalSeconds, 0)) seconds";
		}
	}
	catch 
	{
		Write-Error -Message $_.Exception.Message
	}
	finally
	{
		if (Test-Path -Path Variable:\timer)
		{
			$timer.Stop()
		}
	}
}