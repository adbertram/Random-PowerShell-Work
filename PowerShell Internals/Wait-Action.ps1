<#PSScriptInfo
	.VERSION 1.0
	.GUID 389989f2-626a-45cc-aa5c-2df2f93cee03
	.AUTHOR Adam Bertram
	.COMPANYNAME Adam the Automator, LLC
	.PROJECTURI https://github.com/adbertram/Random-PowerShell-Work/blob/master/PowerShell%20Internals/Wait-Action.ps1
#>

<#
	.SYNOPSIS
		A script to wait for an action to finish.

	.DESCRIPTION
		This script executes a scriptblock represented by the Condition parameter continually while the result returns 
		anything other than $false or $null.

	.PARAMETER Condition
		 A mandatory scriptblock parameter representing the code to execute to check the action condition. This code 
		 will be continually executed until it returns $false or $null.
	
	.PARAMETER Timeout
		 A mandatory integer represneting the time (in seconds) to wait for the condition to complete.

	.PARAMETER ArgumentList
		 An optional collection of one or more objects to pass to the scriptblock at run time. To use this parameter, 
		 be sure you have a param() block in the Condition scriptblock to accept these parameters.

	.PARAMETER RetryInterval
		 An optional integer representing the time (in seconds) between the code execution in Condition.

	.EXAMPLE
		PS> Wait-Action -Condition { (Get-Job).State | where { $_ -ne 'Running' } -Timeout 10
		
		This example will wait for all background jobs to complete for up to 10 seconds.
#>

[OutputType([void])]
[CmdletBinding()]
param
(
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[scriptblock]$Condition,

	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[int]$Timeout,

	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[object[]]$ArgumentList,

	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[int]$RetryInterval = 5
)
try
{
	$timer = [Diagnostics.Stopwatch]::StartNew()
	while (($timer.Elapsed.TotalSeconds -lt $Timeout) -and (& $Condition $ArgumentList)) {
		Start-Sleep -Seconds $RetryInterval
		$totalSecs = [math]::Round($timer.Elapsed.TotalSeconds,0)
		Write-Verbose -Message "Still waiting for action to complete after [$totalSecs] seconds..."
	}
	$timer.Stop()
	if ($timer.Elapsed.TotalSeconds -gt $Timeout) {
		throw 'Action did not complete before timeout period.'
	} else {
		Write-Verbose -Message 'Action completed before timeout period.'
	}
}
catch
{
	Write-Error -Message $_.Exception.Message
}