#Requires -Version 4

function Get-Uptime
{
	<#
	.SYNOPSIS
		This function queries a local or remote computer to find the time it was started up and calculates how long it has
		been online.	
	
	.DESCRIPTION
		This function uses a computer's event log to search for the event ID of 6005 in the System log to find the time it was
		started up. Once it finds this ID, it then takes this time and gets the difference between the start time and the current
		time to calculate how long the computer has been online for.
	
		This function also includes a status output to show you if the computer(s) were queried successfully or not and also
		includes a MightNeedPathed property. This is set to True if the computer was determined to be up for longer than 30 days.
		Due to Microsoft's monthly patching cycle and being that a server is typically rebooted during this patching cycle, it's
		likely if a computer has been up for longer than 30 days it might need some patches applied.
	
		If the computer is offline, it will report as OFFLINE in the Status property. If it cannot query the computer for some
		reason (the event cannot be found perhaps), it will display ERROR in the Status property.
	
	.EXAMPLE
		PS> Get-UpTime
	
		This example will query the local computer to find the time it was started, calculate the difference and display the uptime
		in various formats.
	
	.EXAMPLE
		PS> Get-UpTime -ComputerName SERVER1
	
		This example will query the computer SERVER1 to find the time it was started, calculate the difference and display the uptime
		in various formats. If SERVER1 is offline, it will display OFFLINE in the Status property. If the function cannot
		find the start time it will display ERROR in the Status field.
	
	.PARAMETER ComputerName
		The name of the computer you'd like to run this function against. By default, it will run against the local computer.
		You may pass multiple names to this delimited by a comma.  You cannot include wildcards. You may also pass computer names
		to this property from the pipeline.
	
	.INPUTS
		String. You can pass computer name via the $ComputerName parameter to Get-Uptime.
	
	.OUTPUTS
		System.Management.Automation.PSCustomObject
	#>
	[OutputType('System.Management.Automation.PSCustomObject')]
	[CmdletBinding()]
	param
	(
		[Parameter(ValueFromPipeline)]
		[string[]]$ComputerName = $env:COMPUTERNAME
	)
	begin ## Use a begin block to only process this code one time if names passed from the pipeline
	{
		$today = Get-Date ## Get the current date/time in the begin block to prevent executing Get-Date numerous times
	}
	process
	{
		foreach ($computer in $ComputerName) ## ComputerName is a string collection so we must be able to process each object
		{
			try ## Wrap all code in a try/catch block to catch exceptions and to control code execution
			{
				## Build the soon-to-be object to output so all the properties are already here to populate
				$output = [Ordered]@{
					'ComputerName' = $computer
					'StartTime' = $null
					'Uptime (Months)' = $null
					'Uptime (Days)' = $null
					'Status' = $null
					'MightNeedPatched' = $false
				}
				
				## Test to ensure the computer is online. If not, set the Status to OFFLINE and throw an exception with terminates
				## the rest of the code.
				if (-not (Test-Connection -ComputerName $computer -Count 1 -Quiet))
				{
					$output.Status = 'OFFLINE'
					throw "The computer [$($computer)] is offline."
				}
				
				## Bild the hashtable for the -FilterHashTable parameter. We're querying the System event log for event ID 6005
				$filterHt = @{
					'LogName' = 'System'
					'ID' = 6005
				}
				## Find the first event (which will always be the most recent)
				$startEvent = Get-WinEvent -ComputerName $computer -FilterHashtable $filterHt | select -First 1
				
				## Set the status to be ERROR and throw an exception if we can't find the start event for some reason.
				if (-not $startEvent)
				{
					$output.Status = 'ERROR'
					throw "Unable to determine uptime for computer [$($computer)]"
				}
				## If no error, status is OK
				$output.Status = 'OK'
				
				## Set the StartTime property to a datetime type so that it can be sorted if we're runnning this on multiple computers.
				$output.StartTime = [dateTime]$startEvent.TimeCreated
				
				## Use a timespan object to get the difference between now and when the computer was started.
				$daysUp = [math]::Round((New-TimeSpan -Start $startEvent.TimeCreated -End $today).TotalDays, 2)
				$output.'Uptime (Days)' = $daysUp
				
				## If it's been up for longer than 30 days, set the MightNeedPatched property to $true.
				if ($daysUp -gt 30)
				{
					$output.'MightNeedPatched' = $true
				}
			}
			catch
			{
				## Write a warning to the console with the message thrown
				Write-Warning $_.Exception.Message
			}
			finally
			{
				## Regardless of an exception thrown or not, always output a PSCustomObject to show computer results.
				[pscustomobject]$output
			}
		}
	}
}