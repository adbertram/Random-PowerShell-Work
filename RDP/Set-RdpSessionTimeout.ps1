function Set-RdpSessionTimeout
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('ActiveButIdle', 'Disconnected', 'Active')]
		[string]$SessionType,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateRange(1, [int]::MaxValue)]
		[int]$Timeout, ## in seconds
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
	)
	try
	{
		$baseRegKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
		switch ($SessionType)
		{
			'ActiveButIdle' {
				$valueName = 'MaxIdleTime'
			}
			'Disconnected' {
				$valueName = 'MaxDisconnectionTime'
			}
			'Active' {
				$valueName = 'MaxConnectionTime'
			}
			default
			{
				throw 'Unknown session type chosen.'
			}
		}
		$setParams = @{
			'Path' = $baseRegKey
			'Name' = $valueName
			'Value' = (($Timeout * 60) * 1000)
		}
		
		$icmParams = @{
			'ComputerName' = $ComputerName
		}
		if ($PSBoundParameters.ContainsKey('Credential'))
		{
			$icmParams.Credential = $Credential
		}
		Invoke-Command @icmParams -ScriptBlock {
			Set-ItemProperty @using:setParams
			Get-Service -Name termservice | Restart-Service -Force
		}
	}
	catch
	{
		$PSCmdlet.ThrowTerminatingError($_)
	}
}