<#
.SYNOPSIS
	This script executes a file but first checks to see if any reboot operations are pending. If so, it will
	reboot the computer to clear up any pending operations and then execute the file.
.EXAMPLE
	PS> .\Start-ScriptWithPendingOperationCheck.ps1 -FilePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -Arguments 'C:\MyScript.ps1'
	
	This example checks to see if any operations are pending a reboot.  If so, it immediately reboots the computer and at
	boot time it then executes the C:\MyScript.ps1 file as the local system account.
.PARAMETER FilePath
	The file path to the executable you'd like to run
.PARAMETER Arguments
 	The arguments to pass to the executable when ran
.PARAMETER Force
	If a reboot is pending, use this switch parameter if you'd like to force the reboot instead of prompting
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory)]
	[ValidateScript({ Test-Path -Path $_ -PathType 'Leaf' })]
	[string]$FilePath,
	[Parameter()]
	[string]$Arguments,
	[switch]$Force
)

begin {
	$ErrorActionPreference = 'Stop'
	Set-StrictMode -Version Latest
	
	function New-OnBootScheduledTask {
		<#
		.SYNOPSIS
			This function creates a scheduled task that executes at bootup inside the scheduled task root folder that
			runs as the local system account that deletes itself when finished.
		.EXAMPLE
			PS> New-OnBootScheduledTask -Name 'RunScript' -FilePath 'C:\Windows\notepad.exe' -Arguments 'C:\textfile.txt'
			
			This example creates a scheduled task that executed upon the next bootup time called RunScript that 
			runs notepad.exe and opens C:\textfile.txt
		.PARAMETER Name
			The name of the scheduled task
		.PARAMETER FilePath
		 	The executable file to run when the scheduled task is triggered.
		.PARAMETER Description
			The description of the scheduled task
		.PARAMETER Arguments
			The string of arguments that is passed to the file
		#>
		[CmdletBinding()]
		param (
			[Parameter(Mandatory)]
			[string]$Name,
			[Parameter(Mandatory)]
			[ValidateScript({Test-Path -Path $_ -PathType 'Leaf' })]
			[string]$FilePath,
			[Parameter()]
			[string]$Description,
			[Parameter()]
			[string]$Arguments
		)
		process {
			try {
				# attach the Task Scheduler com object
				$Service = new-object -ComObject ("Schedule.Service")
				# connect to the local machine.
				# http://msdn.microsoft.com/en-us/library/windows/desktop/aa381833(v=vs.85).aspx
				$Service.Connect()
				$RootFolder = $Service.GetFolder("\")
				
				$TaskDefinition = $Service.NewTask(0)
				$TaskDefinition.RegistrationInfo.Description = $Description
				$TaskDefinition.Settings.Enabled = $true
				$TaskDefinition.Settings.AllowDemandStart = $true
				$TaskDefinition.Settings.DeleteExpiredTaskAfter = 'PT0S'
				
				$Triggers = $TaskDefinition.Triggers
				#http://msdn.microsoft.com/en-us/library/windows/desktop/aa383915(v=vs.85).aspx
				$Trigger = $Triggers.Create(8) # Creates a "Boot" trigger
				$Trigger.Enabled = $true
				
				$TaskEndTime = [datetime]::Now.AddMinutes(30)
				$Trigger.EndBoundary = $TaskEndTime.ToString("yyyy-MM-dd'T'HH:mm:ss")
				
				# http://msdn.microsoft.com/en-us/library/windows/desktop/aa381841(v=vs.85).aspx
				$Action = $TaskDefinition.Actions.Create(0)
				$Action.Path = $FilePath
				$action.Arguments = $Arguments
				
				#http://msdn.microsoft.com/en-us/library/windows/desktop/aa381365(v=vs.85).aspx
				$RootFolder.RegisterTaskDefinition($Name, $TaskDefinition, 6, "System", $null, 5) | Out-Null
			} catch {
				Write-Error $_.Exception.Message
			}
		}
	}
	
	function Test-PendingReboot {
		<#
		.SYNOPSIS
			This function tests various registry values to see if the local computer is pending a reboot
		.NOTES
			Inspiration from: https://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542
		.EXAMPLE
			PS> Test-PendingReboot
			
			This example checks various registry values to see if the local computer is pending a reboot.
		#>
		[CmdletBinding()]
		param ()
		process {
			## If any registry value indicates a reboot is pending return True.
			try {
				$OperatingSystem = Get-WmiObject -Class Win32_OperatingSystem -Property BuildNumber, CSName
				
				# If Vista/2008 & Above query the CBS Reg Key
				If ($OperatingSystem.BuildNumber -ge 6001) {
					$PendingReboot = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing' -Name 'RebootPending' -ErrorAction SilentlyContinue
					if ($PendingReboot) {
						Write-Verbose -Message 'Reboot pending detected in the Component Based Servicing registry key'
						return $true
					}
				}
				
				# Query WUAU from the registry
				$PendingReboot = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Name 'RebootRequired' -ErrorAction SilentlyContinue
				if ($PendingReboot) {
					Write-Verbose -Message 'WUAU has a reboot pending'
					return $true
				}
				
				# Query PendingFileRenameOperations from the registry
				$PendingReboot = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
				if ($PendingReboot -and $PendingReboot.PendingFileRenameOperations) {
					Write-Verbose -Message 'Reboot pending in the PendingFileRenameOperations registry value'
					return $true
				}
			} catch {
				Write-Error $_.Exception.Message
			}
		}
	}
	
	function Request-Restart {
		## http://technet.microsoft.com/en-us/library/ff730939.aspx
		$Title = 'Restart Computer'
		$Message = "The computer is pending a reboot. Shall I reboot now and start the script when it comes back up?"
		$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Restart the computer now"
		$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Delay the restart until a later time"
		$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Yes, $No)
		$Result = $Host.ui.PromptForChoice($Title, $Message, $Options, 0)
		switch ($Result) {
			0 { $true }
			1 { $false }
		}
	}
}

process {
	try {
		Write-Verbose -Message 'Checking to see if there are any pending reboot operations'
		if (Test-PendingReboot) { ## Check if any reboot operations are pending
			Write-Verbose -Message 'Found a pending reboot operation'
			## Create an on-boot scheduled task to kick off the executable right after the machine comes back up
			$Params = @{
				'Name' = 'TemporaryBootAction';
				'FilePath' = $FilePath
			}
			if ($Arguments) {
				$Params.Arguments = $Arguments	
			}
			Write-Verbose -Message 'Creating a new on-boot scheduled task'
			New-OnBootScheduledTask @Params
			Write-Verbose 'Created on-boot scheduled task'
			if ($Force.IsPresent) { ## Force was used.  Reboot without prompting
				Write-Verbose -Message 'The force parameter was chosen.  Restarting computer now'
				Restart-Computer -Force
			} elseif (Request-Restart) { ## Force was not used so let's ask for a restart.
				Restart-Computer -Force ## User selected to restart anyway.
			} else { ## The user opted to forego the reboot. Go ahead and run the file
				Write-Verbose 'User cancelled the reboot operation but continuing to run script'
				& $FilePath $Arguments
			}
		} else { ## There is no reboot operations pending so just go ahead and run the file
			Write-Verbose -Message 'No reboot operations pending.  Running executable'
			& $FilePath $Arguments
		}
	} catch {
		Write-Error $_.Exception.Message
	}
}