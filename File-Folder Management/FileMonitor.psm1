function Remove-FileMonitor {
	<#
	.SYNOPSIS
		This function removes a file monitor (permanent WMI event consumer)
	.PARAMETER InputObject
    	An object with Filter, Binding and Consumer properties
		that represents a file monitor retrieved from Get-FileMonitor
	.EXAMPLE
		PS> Get-FileMonitor 'CopyMyFile' | Remove-FileMonitor
	
		This example removes the file monitor called CopyMyFile.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory, ValueFromPipeline)]
		[System.Object]$InputObject
	)
	process {
		try {
			$InputObject.Filter | Remove-WmiObject
			$InputObject.Consumer | Remove-WmiObject
			Get-WmiObject -Class '__filtertoconsumerbinding' -Namespace 'root\subscription' -Filter "Filter = ""__eventfilter.name='$($InputObject.Filter.Name)'""" | Remove-WmiObject
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function New-FileMonitor {
	<#
	.SYNOPSIS
		This function creates a file monitor (permanent WMI event consumer)
	.PARAMETER Name
    	The name of the file monitor.  This will be the name of both the WMI event filter
		and the event consumer.
	.PARAMETER MonitorInterval
		The number of seconds between checks
	.PARAMETER FolderPath
		The complete path of the folder you'd like to monitor
	.PARAMETER ScriptFilePath
		The Powershell script that will execute if a file is detected in the folder
	.PARAMETER VbsScriptFilePath
		When the monitor is triggered it's impossible to execute a Powershell script directly.  A VBS script must be executed instead.
		This function will create the VBS automatically but it must be placed somewhere.  This is the file path to where the VBS
		script will be created.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$Name,

		[Parameter(Mandatory)]
		[string]$MonitorInterval,

		[Parameter(Mandatory)]
		[string]$FolderPath,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Modification', 'Creation')]
		[string]$EventType,

		[Parameter(Mandatory)]
		[ValidateScript({ Test-Path -Path $_ -PathType 'Leaf' })]
		[ValidatePattern('.*\.ps1')]
		[string]$ScriptFilePath,

		[ValidatePattern('.*\.vbs')]
		[string]$VbsScriptFilePath = "$($env:TEMP)\FileMonitor.vbs"
	)
	process {
		try {
			## Create the event query to monitor only the folder we want.  Also, set the monitor interval
			## to something like 10 seconds to check the folder every 10 seconds.
			$WmiEventFilterQuery = @'
SELECT * FROM __Instance{0}Event WITHIN {1}
WHERE targetInstance ISA 'CIM_DirectoryContainsFile'
and TargetInstance.GroupComponent = 'Win32_Directory.Name="{2}"'
'@ -f $EventType, $MonitorInterval, ($FolderPath -replace '\\+$').Replace('\', '\\')
			
			## Subscribe to the WMI event using the WMI filter query created above
			$WmiFilterParams = @{
				'Class'     = '__EventFilter'
				'Namespace' = 'root\subscription'
				'Arguments' = @{ Name = $Name; EventNameSpace = 'root\cimv2'; QueryLanguage = 'WQL'; Query = $WmiEventFilterQuery }
			}
			Write-Verbose -Message "Creating WMI event filter using query '$WmiEventFilterQuery'"
			$WmiEventFilterPath = Set-WmiInstance @WmiFilterParams
			
			## Create the VBS script that will then call the Powershell script.  A VBscript is needed since
			## WMI events cannot auto-trigger another PowerShell script.
			$VbsScript = "
				Set objShell = CreateObject(`"Wscript.shell`")`r`n
				objShell.run(`"powershell.exe -NonInteractive -NoProfile -WindowStyle Hidden -executionpolicy bypass -file `"`"$ScriptFilePath`"`"`")
			"
			Set-Content -Path $VbsScriptFilePath -Value $VbsScript
			
			## Create the WMI event consumer which will actually consume the event
			$WmiConsumerParams = @{
				'Class'     = 'ActiveScriptEventConsumer'
				'Namespace' = 'root\subscription'
				'Arguments' = @{ Name = $Name; ScriptFileName = $VbsScriptFilePath; ScriptingEngine = 'VBScript' }
			}
			Write-Verbose -Message "Creating WMI consumer using script file name $VbsScriptFilePath"
			$WmiConsumer = Set-WmiInstance @WmiConsumerParams
			
			$WmiFilterConsumerParams = @{
				'Class'     = '__FilterToConsumerBinding'
				'Namespace' = 'root\subscription'
				'Arguments' = @{ Filter = $WmiEventFilterPath; Consumer = $WmiConsumer }
			}
			Write-Verbose -Message "Creating WMI filter consumer using filter $WmiEventFilterPath"
			Set-WmiInstance @WmiFilterConsumerParams | Out-Null
		} catch {
			Write-Error $_.Exception.Message	
		}
	}
}

function Get-FileMonitor {
	<#
	.SYNOPSIS
		This function gets a file monitor (permanent WMI event consumer)
	.PARAMETER Name
    	The name of the file monitor.  This will be the name of both the WMI event filter
		and the event consumer.
	#>
	[CmdletBinding()]
	param (
		[string]$Name
	)
	process {
		try {
			$Monitor = @{ }
			$BindingParams = @{ 'Namespace' = 'root\subscription'; 'Class' = '__FilterToConsumerBinding' }
			$FilterParams = @{ 'Namespace' = 'root\subscription'; 'Class' = '__EventFilter' }
			$ConsumerParams = @{ 'Namespace' = 'root\subscription'; 'Class' = 'ActiveScriptEventConsumer' }
			if ($Name) {
				$BindingParams.Filter = "Consumer = 'ActiveScriptEventConsumer.Name=`"$Name`"'"
				$FilterParams.Filter = "Name = '$Name'"
				$ConsumerParams.Filter = "Name = '$Name'"
			}
			$Monitor.Binding = Get-WmiObject @BindingParams
			$Monitor.Filter = Get-WmiObject @FilterParams
			$Monitor.Consumer = Get-WmiObject @ConsumerParams
			if ($Monitor.Consumer -and $Monitor.Filter) {
				[pscustomobject]$Monitor
			} elseif (-not $Monitor.Consumer -and -not $Monitor.Filter) {
				$null
			} else {
				throw 'Mismatch between binding, filter and consumer names exists'	
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}