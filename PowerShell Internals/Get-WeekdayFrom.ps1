function Get-WeekdayFrom {
		<#
		.SYNOPSIS
			This function translate a loosely structured weekday reference to a structured Powershell
			[datetime] object.
		.PARAMETER Weekday
			An unstructured weekday string representing a date.  Possible values are:
			
			$Weekday (ie. Monday, Tuesday, etc) - This will get the upcoming weekday
			next $Weekday (ie. Next Sunday, Next Tuesday, etc) - This will get the upcoming weekday
			last $Weekday (ie. Last Sunday, Last Tuesday, etc) - This will get the last weekday
			
		.PARAMETER FromDate
			A [datetime] object. Used to provide the desired weekday result relative to the date 
			provided.
		#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[ValidatePattern('sunday|monday|tuesday|wednesday|thursday|friday|saturday')]
		[string]$Weekday,
	        [datetime]$FromDate
	)
	process {
		try {
			$Weekday = $Weekday.ToLower()
			## Use regex in case user specified 'last' or 'next'
			$DesiredWeekDay = [regex]::Matches($Weekday, 'sunday|monday|tuesday|wednesday|thursday|friday|saturday').Value
			if ($FromDate) {
				$Today = (Get-Date -Date "$fromDate").Date
			} else {
				$Today = (Get-Date).Date
			}
			if ($Weekday -match 'next') {
				## The user wants next week's weekday
				$Range = 1..7
			} elseif ($Weekday -match 'last') {
				## The user wants last week's weekday
				$Range = -1.. - 7
			} else {
				## The user didn't specify so assuming they just want the upcoming weekday
				$Range = 1..7
			}
			$Range | foreach {
				$Day = $Today.AddDays($_);
				if ($Day.DayOfWeek -eq $DesiredWeekDay) {
					$Day.Date
				}
			}
		} catch {
			Write-Error $_.Exception.Message
			$false
		}
	}
}
