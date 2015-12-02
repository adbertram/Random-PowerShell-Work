# https://moveitsupport.ipswitch.com/SUPPORT/micentralapiwin/online-manual.htm

function Get-MOVEitApiVersion
{
	[CmdletBinding()]
	param
	()
	
	try
	{
		$Connection.GetAPIVersion()
	}
	catch
	{
		Write-Error $_.Exception.Message
	}
}

function Get-MOVEitCentralVersion
{
	[CmdletBinding()]
	param
	()
	
	try
	{
		$Connection.GetCentralVersion()
	}
	catch
	{
		Write-Error $_.Exception.Message
	}
}

function Test-MOVEitApiInstall
{
	[CmdletBinding()]
	param
	()
	
	Write-Verbose -Message 'Testing to ensure the MOVEit API COM object is available'
	
	try
	{
		$ErrorActionPrefBefore = $ErrorActionPreference
		
		$connection = new-object -comObject MICentralAPICOM.MICentralAPI
		if ($Error -and ($Error[0].Exception.Message -match '80040154 Class not registered'))
		{
			$false
		}
		else
		{
			$true
		}
	}
	catch
	{
		Write-Error $_.Exception.Message
	}
	finally
	{
		$ErrorActionPreference = $ErrorActionPrefBefore
	}
}

function Connect-MOVEitCentral
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName = $env:COMPUTERNAME,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
	)
	
	try
	{
		if (-not (Test-MOVEitApiInstall))
		{
			throw 'The MOVEit COM API was not found. Is it installed?'
		}
		
		$global:connection = New-Object -ComObject MICentralAPICOM.MICentralAPI
		$connection.SetHost($ComputerName)
		$connection.SetUser($Credential.UserName)
		$connection.SetPassword($Credential.GetNetworkCredential().Password)
		if (-not $connection.Connect())
		{
			throw $connection.GetErrorDescription()
		}
	}
	catch
	{
		Write-Error $_.Exception.Message
	}	
}

function Disconnect-MOVEitCentral
{
	[CmdletBinding()]
	param
	()
	try
	{
		$Connection.Disconnect()
	}
	catch
	{
		Write-Error $_.Exception.Message
	}
}

function Get-Task
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Running')]
		[string]$Type
		
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			if ($Type -eq 'Running')
			{
				$connection.ShowRunningTasks()
#				Sub DumpTaskStatus(oAPI, StatusXML, iii)
#				ShowMsg "===== " & oAPI.GetValue(StatusXML, "TaskName", iii) & _
#				" (" & _
#				oAPI.GetValue(StatusXML, "TaskID", iii)  & _
#				") ====="
#				ShowMsg "=  Started : " & oAPI.GetValue(StatusXML, "TimeStarted", iii) & _
#				" (" & _
#				oAPI.GetValue(StatusXML, "StartedBy", iii)  & _
#				")"
#				Dim ShortStatus
#				ShortStatus = oAPI.GetValue(StatusXML, "Status", iii)
#				if Len(ShortStatus) > 50 then ShortStatus = Mid(ShortStatus, 1, 50) & "..."
#				ShowMsg "=  Status  : " & ShortStatus
#				if oAPI.GetValue(StatusXML, "TotFileBytes", iii) > 0 then
#				ShowMsg "=  Transfer: " & oAPI.GetValue(StatusXML, "CurFileBytes", iii) & _
#				" of " & _
#				oAPI.GetValue(StatusXML, "TotFileBytes", iii)  & _
#				" bytes"
#				end if
#				End Sub
			}		
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Set-MaxTasks
{
	<#
	Sets the maximum number of running tasks to allow from this connected instance of MOVEit Central API. If at least this many 
	tasks are already running, Central will refuse to run a task submitted using StartTask() or StartNewTask(), and will return 
	error code 5120.

	Note that this value has no relation to the "Maximum Running Tasks" limit set on regular, scheduled tasks through MOVEit 
	Central Admin. Furthermore, multiple and concurrent instances of MOVEit Central API can set this value differently. 
	For example, one session may be working with a task submission limit of 2 tasks while a "high priority" MOVEit Central API 
	thread may be working without any task submission limit at all.
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[int]$Count,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$PassThru
	)
	try
	{
		$previousMaxTasks = $Connection.SetMaxTasks($Count)
		if ($PassThru.IsPresent)
		{
			$previousMaxTasks	
		}
	}
	catch
	{
		Write-Error $_.Exception.Message
	}
}

function New-MOVEitErrorRecord
{
	[CmdletBinding()]
	param
	()

	$exception = New-Object System.Management.ManagementException($Connection.GetErrorDescription())
	
	$errArgs = @($exception, $Connection.GetErrorCode(), 'NotSpecified', $null)
	$errRecord = New-Object System.Management.Automation.ErrorRecord -ArgumentList $errArgs
	throw $errRecord
}

function Resolve-MOVEitError
{
	[CmdletBinding()]
	param
	()
	
	if ($connection.GetErrorCode() -ne 0)
	{
		New-MOVEitErrorRecord
	}
}