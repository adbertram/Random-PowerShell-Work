# https://moveitsupport.ipswitch.com/SUPPORT/micentralapiwin/online-manual.htm

function Connect-MOVEitCentral
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName = $env:COMPUTERNAME
	)
	
	try
	{
		if (-not (Test-MOVEitApiInstall))
		{
			throw 'The MOVEit COM API was not found. Is it installed?'
		}
		
		Write-Verbose -Message "Attempting connection to the host [$($ComputerName)] using username [$($Credential.UserName)]"
		$global:connection = New-Object -ComObject MICentralAPICOM.MICentralAPI
		$global:connection.SetHost($ComputerName)
		$connection.SetUser($Credential.UserName)
		$connection.SetPassword($Credential.GetNetworkCredential().Password)
		if (-not $connection.Connect())
		{
			throw
		}
		else
		{
			$connection
		}
	}
	catch
	{
		Resolve-MOVEitError
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

function Get-Task
{
	[CmdletBinding(DefaultParameterSetName = 'None')]
	param
	(
		[Parameter(Mandatory, ParameterSetName = 'ById')]
		[ValidateNotNullOrEmpty()]
		[string]$TaskId,
		
		[Parameter(Mandatory, ParameterSetName = 'ByName')]
		[ValidateNotNullOrEmpty()]
		[string]$TaskName,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$Running
		
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			if ($Running.IsPresent)
			{
				$response = [xml]$connection.ShowRunningTasks()
				
				$xPath = '/Response/Output/Tasks/Task'
				if ($PSCmdlet.ParameterSetName -eq 'ById')
				{
					$xPath += "[TaskID=$TaskId]"
				}
				elseif ($PSCmdlet.ParameterSetName -eq 'ByName')
				{
					$xPath += "[TaskName=$TaskName]"
				}
				
				$response.SelectNodes($xPath)
			}		
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Start-Task
{
	[CmdletBinding(DefaultParameterSetName = 'None')]
	param
	(
		[Parameter(Mandatory, ParameterSetName = 'ById')]
		[ValidateNotNullOrEmpty()]
		[string]$TaskId,
		
		[Parameter(Mandatory, ParameterSetName = 'ByName')]
		[ValidateNotNullOrEmpty()]
		[string]$TaskName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[object[]]$Parameter,
		
		## This should be a collection of TaskParameter objects --could be PSCustomObjects
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$Wait,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$Timeout = 30
	)
	try
	{
		if ($PSCmdlet.ParameterSetName -eq 'ByName')
		{
			Write-Verbose -Message "Attempting to start task [$($TaskName)] by name."
			$params = $TaskName, 1 ## Use 1 for $true to represent passing a name instead of an ID
		}
		elseif ($PSCmdlet.ParameterSetName -eq 'ById')
		{
			Write-Verbose -Message "Attempting to start task [$($TaskID)] by ID."
			$params = $TaskId, 0
		}
		if ($PSBoundParameters.ContainsKey('Parameter'))
		{
			Write-Warning -Message 'The Parameter parameter is not implemented yet.'
			##$params += $Parameter
		}
		else
		{
			$params += ''
		}
		
		$task = $connection.StartTask($params[0], $params[1], $params[2])
		if (-not $task)
		{
			Resolve-MOVEitError
		}
		elseif ($Wait.IsPresent)
		{
			if ($PSCmdlet.ParameterSetName -eq 'ByName')
			{
				$TaskId = [regex]::Match($task, '(^\d+)\^').Groups[1].Value
			}
			Wait-Task -TaskId $TaskId -Timeout $Timeout
		}
	}
	catch
	{
		Write-Error $_.Exception.Message
	}
}

function Wait-Task
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$TaskId,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$Timeout = 10
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$timer = [system.diagnostics.stopwatch]::startNew()
			Write-Verbose -Message "Waiting for task ID [$($TaskId)] to finish."
			while ((Get-Task -Running -TaskId $TaskId) -and ($timer.Elapsed.TotalSeconds -lt $Timeout))
			{
				Start-Sleep -Seconds 1
			}
			if ($timer.Elapsed.TotalSeconds -ge $Timeout)
			{
				Write-Warning -Message "Operation timed out while waiting for task ID [$($TaskId)]"
			}
			else
			{
				Write-Verbose -Message "Task ID [$($TaskId)] has completed."
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