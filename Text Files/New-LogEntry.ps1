function New-LogEntry {
	<#
	.SYNOPSIS
		This function appends a row to a tab-separated text file with a timestamp, log message and a time
		interval.  This is used to provide an easy way to get new work log entries into your work log.
	
		You can use common time interval strings like 'for 3 hours', 'for 1 hour and 45 minutes', 'for 15 minutes', '1.5' or
		just use 'for 45', 'for 125' without a label as a shortcut to specify number of minutes.  However, always
		prepend the string with 'for' and a space and ensure it's at the end of your message.
	.EXAMPLE
		PS> New-LogEntry 'I worked on this thing for 3 hours'
		
		This example would append a row into your work log like this:
		01-05-2014 08:45AM<tab>I worked on this<tab>3
	.EXAMPLE
		PS> New-LogEntry 'I worked on this other thing' for 1 hour and 15 minutes
		
		This example would append a row into your work log like this:
		01-05-2014 08:45AM<tab>I worked on this other thing<tab>1.25
	.EXAMPLE
		PS> New-LogEntry 'I worked on this other thing' for 1.5 hours
		
		This example would append a row into your work log like this:
		01-05-2014 08:45AM<tab>I worked on this other thing<tab>1.5
	.PARAMETER FilePath
		The file path where you'd like to create and append your work log
	.PARAMETER Message
		The message you'd like to include with your time logged
	#>
	[CmdletBinding()]
	param (
		[Parameter(ValueFromRemainingArguments = $true)]
		[string]$Message
	)
	begin {
		$FilePath = 'C:\MyWorkLog.csv'
		
		function Convert-TimeStringToTimeSpan($TimeString) {
			$AllowedLabels = (New-TimeSpan).Psobject.Properties.Name
			## Add the singular values as well
			$AllowedLabels += $AllowedLabels | foreach { $_.TrimEnd('s') }
			## Attempt to split on the 'and' string in case it was something like 1 hour and 15 minutes
			$Values = $TimeString -split ' and '
			
			$Hours = 0
			foreach ($Value in $Values) {
				$Split = $Value.Split(' ')
				$Value = $Split[0]
				$Label = $Split[1]
				if ($AllowedLabels -notcontains $Label) {
					Write-Error "The label '$Label' is not a valid time label"
					return $false
				} elseif ($Value -notmatch '^\d+$') {
					Write-Error "The time value '$Value' is not a valid time interval"
					return $false
				} else {
					## Make the label plural (if it's not already) to match New-TimeSpan's property name
					if ($Label.Substring($Label.Length - 1, 1) -ne 's') {
						$Label = $Label + 's'
					}
					Write-Verbose "Passing the label $Label and value $Value to New-TimeSpan"
					## Convert the time to hours
					$Params = @{ $Label = $Value }
					$Hours += (New-TimeSpan @Params).TotalHours
				}
			}
			[math]::Round($Hours,2)
		}
	}
	process {
		try {
			## Join all of the message words together
			$Message = $Message -join ' '
			if (!(Test-Path $FilePath)) {
				Write-Verbose "The file '$FilePath' does not exist.  Creating a new file"
			}
			Write-Verbose "Appending a new row to the file at '$FilePath'"
			## Find the last instance of the string 'for' and everything after
			$Split = $Message -split ' for '
			$TimeString = $Split[$Split.Length-1]
			
			## Take the 'for' string at the end and convert it to a number of hours (if not already)
			if ($TimeString -match '\d+(\.\d{1,2})?$') {
				$Hours = $TimeString	
			} else {
				$Hours = Convert-TimeStringToTimeSpan -TimeString $TimeString
			}
			$ObjectParams = @{
				'DateTime' = (Get-Date)
				'Message' = $Message -replace "for $TimeString",''
				'Hours' = $Hours
			}
			[pscustomobject]$ObjectParams | Export-Csv -Path $FilePath -Append -NoTypeInformation -Delimiter "`t"
		} catch {
			Write-Error -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
			$false
		}
	}
}
