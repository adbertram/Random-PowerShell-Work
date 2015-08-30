<#
.SYNOPSIS
	This finds the total hard drive free space for one or multiple hard drive partitions
.DESCRIPTION
	This finds the total hard drive free space for one or multiple hard drive partitions. It returns free space
	rounded to the nearest SizeOutputLabel parameter
.PARAMETER  DriveLetter
	This is the drive letter of the hard drive partition you'd like to query. By default, all drive letters are queried.
.PARAMETER  SizeOutputLabel
	In what size increments you'd like the size returned (KB, MB, GB, TB). Defaults to MB.
.PARAMETER  Computername
	The computername(s) you'd like to find free space on.  This defaults to the local machine.
.EXAMPLE
	PS C:\> Get-DriveFreeSpace -DriveLetter 'C','D'
	This example retrieves the free space on the C and D drive partition.
#>
[CmdletBinding()]
[OutputType([array])]
param
(
	[string[]]$Computername = 'localhost',
	[Parameter(ValueFromPipeline = $true,
			   ValueFromPipelineByPropertyName = $true)]
	[ValidatePattern('[A-Z]')]
	[string]$DriveLetter,
	[ValidateSet('KB','MB','GB','TB')]
	[string]$SizeOutputLabel = 'MB'
	
)

Begin {
	try {
		$WhereQuery = "SELECT FreeSpace,DeviceID FROM Win32_Logicaldisk"
		
		if ($PsBoundParameters.DriveLetter) {
			$WhereQuery += ' WHERE'
			$BuiltQueryParams = { @() }.Invoke()
			foreach ($Letter in $DriveLetter) {
				$BuiltQueryParams.Add("DeviceId = '$DriveLetter`:'")
			}
			$WhereQuery = "$WhereQuery $($BuiltQueryParams -join ' OR ')"
		}
		Write-Debug "Using WQL query $WhereQuery"
		$WmiParams = @{
			'Query' = $WhereQuery
			'ErrorVariable' = 'MyError';
			'ErrorAction' = 'SilentlyContinue'
		}
	} catch {
		Write-Error $_.Exception.Message
	}
}
Process {
	try {
		foreach ($Computer in $Computername) {
			$WmiParams.Computername = $Computer
			$WmiResult = Get-WmiObject @WmiParams
			if ($MyError) {
				throw $MyError
			}
			foreach ($Result in $WmiResult) {
				if ($Result.Freespace) {
					[pscustomobject]@{
						'Computername' = $Computer;
						'DriveLetter' = $Result.DeviceID;
						'Freespace' = [int]($Result.FreeSpace / "1$SizeOutputLabel")
					}
				}
			}
		}
	} catch {
		Write-Error $_.Exception.Message	
	}
	