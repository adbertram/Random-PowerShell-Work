# .ExternalHelp C:\Dropbox\GitRepos\Random-PowerShell-Work\PowerShell Internals\Wait-Action-Help.xml

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
$ErrorActionPreference = 'Stop'
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
finally
{
	$ErrorActionPreference = 'Continue'
}