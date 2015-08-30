<#
.SYNOPSIS
	This script creates a scheduled task on a local or remote system to execute a Powershell script 
	based on a number of criteria.  It is useful if you have a central server that you create multiple
	different scheduled tasks on.
.NOTES
	Created on: 	1/20/15
	Created by: 	Adam Bertram
	Filename:		New-ScheduledScript.ps1
	Credits:		http://blogs.technet.com/b/heyscriptingguy/archive/2015/01/16/use-powershell-to-create-scheduled-task-in-new-folder.aspx
.EXAMPLE
	PS> New-ScheduledScript.ps1 -ScriptFilePath C:\callfromvbs.ps1 -LocalScriptFolderPath 'C:\' -TaskTriggerOptions @{'Daily' = $true; 'At' = '3Am'} -TaskName 'Test' -TaskRunAsUser 'lab.local\administrator' -TaskRunAsPassword 'mypassword' -Computername labdc.lab.local
	
	This script would copy the C:\callfromvbs.ps1 to the C:\ of labdc.lab.local.  It would then create a scheduled task on labdc.lab.local
	named Test that ran daily at 3AM under the lab.local\administrator credentials.
.PARAMETER ScriptFilePath
	The remote or local file path of the Powershell script
.PARAMETER ScriptParameters
	Any parameters to execute with the script
.PARAMETER LocalScriptFolderPath
	If this script is copying a Powershell script from somewhere else, this is the folder path where the
	script will be copied to and referenced to run in the scheduled task.
.PARAMETER TaskTriggerOptions
	A hashtable of parameters that will be passed to the New-ScheduledTaskTrigger cmdlet.  For available options, visit
	http://technet.microsoft.com/en-us/library/jj649821.aspx.
.PARAMETER TaskName
	The name of the scheduled task
.PARAMETER TaskRunAsUser
	The username that the task will run under
.PARAMETER TaskRunAsPassword
	The password to the runas user
.PARAMETER Computername
	The name of the system in which the scheduled task will be created (if not the local system)
.PARAMETER PowershellRunAsArch
	If your task scheduler machine is 64 bit this enforces the script to run under the 32 bit or 64 bit
	Powershell host.  By default, it will always run as 64 bit.
#>
[CmdletBinding()]
[OutputType([bool])]
param (
	[Parameter(Mandatory,
			   ValueFromPipeline,
			ValueFromPipelineByPropertyName)]
	[ValidatePattern('.*\.ps1$')]
	[string]$ScriptFilePath,
	[string]$ScriptParameters,
	[Parameter(Mandatory)]
	[string]$LocalScriptFolderPath,
	[Parameter(Mandatory)]
	[hashtable]$TaskTriggerOptions,
	[Parameter(Mandatory)]
	[string]$TaskName,
	[Parameter(Mandatory)]
	[string]$TaskRunAsUser,
	[Parameter(Mandatory)]
	[string]$TaskRunAsPassword,
	[ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1})]
	[string]$Computername = 'localhost',
	[ValidateSet('x86', 'x64')]
	[string]$PowershellRunAsArch
)

begin {
	$ErrorActionPreference = 'Stop'
	Set-StrictMode -Version Latest
	## http://www.leeholmes.com/blog/2009/11/20/testing-for-powershell-remoting-test-psremoting/
	function Test-PsRemoting {
		param (
			[Parameter(Mandatory)]
			$computername
		)
		
		try {
			$errorActionPreference = "Stop"
			$result = Invoke-Command -ComputerName $computername { 1 }
		} catch {
			return $false
		}
		
		## I’ve never seen this happen, but if you want to be
		## thorough….
		if ($result -ne 1) {
			Write-Verbose "Remoting to $computerName returned an unexpected result."
			return $false
		}
		$true
	}
	
	function Get-ComputerArchitecture {
		if ((Get-CimInstance -ComputerName $Computername Win32_ComputerSystem -Property SystemType).SystemType -eq 'x64-based PC') {
			'x64'
		} else {
			'x86'	
		}
	}
	
	function Get-PowershellFilePath {
		## If user wants to run the script under the x86 host and the machine is x64
		if (($PowershellRunAsArch -eq 'x86') -and ((Get-ComputerArchitecture) -eq 'x64')) {
			if ($Computername -eq 'localhost') {
				## If it's the localhost no need to do a WinRM query
				"$($PsHome.Replace('System32','SysWow64'))\powershell.exe"
			} else {
				Invoke-Command -ComputerName $Computername -ScriptBlock { "$($PsHome.Replace('System32','SysWow64'))\powershell.exe" }
			}
		} else {
			## If the machine is 32 bit anyway or if it's 64 bit and the user wants 64 bit just use $PsHome
			if ($Computername -eq 'localhost') {
				## If it's the localhost no need to do a WinRM query
				"$PsHome\powershell.exe"
			} else {
				Invoke-Command -ComputerName $Computername -ScriptBlock { "$PsHome\powershell.exe" }
			}
		}
	}
	
	function New-MyScheduledTask {
		try {
			$PowershellFilePath = Get-PowershellFilePath
			if ($Computername -ne 'localhost') {
				$ScriptBlock = {
					$Action = New-ScheduledTaskAction -Execute $using:PowershellFilePath -Argument "-NonInteractive -NoLogo -NoProfile -File $using:ScriptFilePath $using:ScriptParameters"
					$TaskTriggerOptions = $using:TaskTriggerOptions
					$Trigger = New-ScheduledTaskTrigger @TaskTriggerOptions
					$RunAsUser = $using:TaskRunAsUser
					$Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Settings (New-ScheduledTaskSettingsSet);
					Register-ScheduledTask -TaskName $using:TaskName -InputObject $Task -User $using:TaskRunAsUser -Password $using:TaskRunAsPassword
				}
				$Params = @{
					'Scriptblock' = $ScriptBlock
					'Computername' = $Computername
				}
				Invoke-Command @Params
			} else {
				$Action = New-ScheduledTaskAction -Execute $PowershellFilePath -Argument "-NonInteractive -NoLogo -NoProfile -File $ScriptFilePath"
				$Trigger = New-ScheduledTaskTrigger @TaskTriggerOptions
				$Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Settings (New-ScheduledTaskSettingsSet);
				Register-ScheduledTask -TaskName $TaskName -InputObject $Task -User $TaskRunAsUser -Password $TaskRunAsPassword
			}
		} catch {
			Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
			$false
		}
	}
	
	function Get-UncPath ($HostName,$LocalPath) {
		$NewPath = $LocalPath -replace (":", "$")
		if ($NewPath.EndsWith("\")) {
			$NewPath = [Regex]::Replace($NewPath, "\\$", "")
		}
		"\\$HostName\$NewPath"
	}
	
	try {
		if (($Computername -ne 'localhost') -and !(Test-PsRemoting -computername $Computername)) {
			throw "PS remoting not available on the computer $Computername"
		}
		## Ensure there's no trailing slash
		$LocalScriptFolderPath = $LocalScriptFolderPath.TrimEnd('\')
	} catch {
		Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
		exit
	}
}

process {
	try {
		## If we're not creating a task on the local computer or if the script to execute is not on the local computer
		## copy to the task scheduler system and change the script to execute to a local path
		if ($ScriptFilePath.StartsWith('\\') -or ($Computername -ne 'localhost')) {
			Copy-Item -Path $ScriptFilePath -Destination (Get-UncPath -HostName $Computername -LocalPath $LocalScriptFolderPath)
			$ScriptFilePath = "$LocalScriptFolderPath\$($ScriptFilePath | Split-Path -Leaf)"
		}
		New-MyScheduledTask | Out-Null
		$true
	} catch {
		Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
		$false
	}
}