function Find-TroubleshootingEvent
{
	[OutputType()]
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName	= (hostname),

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$EventId
	)
	try
	{
		@($ComputerName).foreach({
			$computer = $_
			$getEventParams = @{
				ComputerName = $computer
			}
			$logNames = @(Get-WinEvent @getEventParams -ListLog *).where({ $_.RecordCount }).LogName
			Write-Verbose -Message "Found log names: [$($logNames -join ',')]"
			$filterHashTable = @{
				LogName = $logNames	
			}
			if ($PSBoundParameters.ContainsKey('EventId'))
			{
				$filterHashTable.Id = $EventId
			}
			$selectProperties = @('*',@{Name = 'ServerName'; Expression = {$computer}})
			Get-WinEvent @getEventParams -FilterHashTable $filterHashTable | Select-Object -Property $selectProperties
		})		
	}
	catch
	{
		$PSCmdlet.ThrowTerminatingError($_)
	}
}