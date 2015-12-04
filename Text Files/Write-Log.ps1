function Start-Log
{
	<#
	.SYNOPSIS
		This function creates the initial log file and sets a few global variables
		that are common among the session.  Call this function at the very top of your
		installer script.

	.PARAMETER  FilePath
		The file path where you'd like to place the log file on the file system.  If no file path
		specified, it will create a file in the system's temp directory named the same as the script
		which called this function with a .log extension.

	.EXAMPLE
		PS C:\> Start-Log -FilePath 'C:\Temp\installer.log

	.NOTES

	#>
	[CmdletBinding()]
	param (
		[ValidateScript({ Split-Path $_ -Parent | Test-Path })]
		[string]$FilePath
	)
	
	try
	{
		if (!(Test-Path $FilePath))
		{
			## Create the log file
			New-Item $FilePath -Type File | Out-Null
		}
		
		## Set the global variable to be used as the FilePath for all subsequent Write-Log
		## calls in this session
		$global:ScriptLogFilePath = $FilePath
	}
	catch
	{
		Write-Error $_.Exception.Message
	}
}

function Write-Log
{
	<#
	.SYNOPSIS
		This function creates or appends a line to a log file

	.DESCRIPTION
		This function writes a log line to a log file in the form synonymous with 
		ConfigMgr logs so that tools such as CMtrace and SMStrace can easily parse 
		the log file.  It uses the ConfigMgr client log format's file section
		to add the line of the script in which it was called.

	.PARAMETER  Message
		The message parameter is the log message you'd like to record to the log file

	.PARAMETER  LogLevel
		The logging level is the severity rating for the message you're recording. Like ConfigMgr
		clients, you have 3 severity levels available; 1, 2 and 3 from informational messages
		for FYI to critical messages that stop the install. This defaults to 1.

	.EXAMPLE
		PS C:\> Write-Log -Message 'Value1' -LogLevel 'Value2'
		This example shows how to call the Write-Log function with named parameters.

	.NOTES

	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Message,
		
		[Parameter()]
		[ValidateSet(1, 2, 3)]
		[int]$LogLevel = 1
	)
	
	try
	{
		$TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
		## Build the line which will be recorded to the log file
		$Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
		$LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)", $LogLevel
		$Line = $Line -f $LineFormat
		
		if (-not (Test-Path Variable:\ScriptLogFilePath))
		{
			Write-Verbose $Message
		}
		else
		{
			Add-Content -Value $Line -Path $ScriptLogFilePath
		}
	}
	catch
	{
		Write-Error $_.Exception.Message
	}
}