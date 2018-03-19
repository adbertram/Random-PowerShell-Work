Set-StrictMode -Version Latest

function Get-WindowsUpdate {
	<#
		.SYNOPSIS
			This function retrieves a list of Microsoft updates based on a number of different criteria for a remote
			computer. It will retrieve these updates over a PowerShell remoting session. It uses the update source set
			at the time of query. If it's set to WSUS, it will only return updates that are advertised to the computer
			by WSUS.
	
		.EXAMPLE
			PS> Get-WindowsUpdate -ComputerName FOO

		.PARAMETER ComputerName
			 A mandatory string parameter representing the FQDN of a computer. This is only mandatory is Session is
			 not used.

		.PARAMETER Credential
			 A optoional pscredential parameter representing an alternate credential to connect to the remote computer.

		.PARAMETER Session
			 A mandatory PSSession parameter representing a PowerShell remoting session created with New-PSSession. This
			 is only mandatory if ComputerName is not used.
		
		.PARAMETER Installed
			 A optional boolean parameter set to either $true or $false depending on if you'd like to filter the resulting
			 updates on this criteria.

		.PARAMETER Hidden
			 A optional boolean parameter set to either $true or $false depending on if you'd like to filter the resulting
			 updates on this criteria.

		.PARAMETER Assigned
			A optional boolean parameter set to either $true or $false depending on if you'd like to filter the resulting
			updates on this criteria.

		.PARAMETER RebootRequired
			A optional boolean parameter set to either $true or $false depending on if you'd like to filter the resulting
			updates on this criteria.
	#>
	[OutputType([System.Management.Automation.PSObject])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ParameterSetName = 'ByComputerName')]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,

		[Parameter(ParameterSetName = 'ByComputerName')]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential,

		[Parameter(Mandatory, ParameterSetName = 'BySession')]
		[ValidateNotNullOrEmpty()]
		[System.Management.Automation.Runspaces.PSSession]$Session,
        
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('MicrosoftUpdate')]
		[string]$Source,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('True', 'False')]
		[string]$Installed = 'False',

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('True', 'False')]
		[string]$Hidden,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('True', 'False')]
		[string]$Assigned,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('True', 'False')]
		[string]$RebootRequired
	)
	begin {
		$ErrorActionPreference = 'Stop'
		if (-not $Session) {
			$sessParams = @{
				ComputerName = $ComputerName
			}
			if ($PSBoundParameters.ContainsKey('Credential')) {
				$sessParams.Credential = $Credential
			}
			$Session = New-PSSession @sessParams
		}
	}
	process {
		try {
			$criteriaParams = @{}

			## Had to set these to string values because if they're boolean they will have a $false value even if
			## they aren't set.  I needed to check for a $null value.ided
			@('Installed', 'Hidden', 'Assigned', 'RebootRequired').where({ (Get-Variable -Name $_).Value }).foreach({
					$criteriaParams[$_] = if ((Get-Variable -Name $_).Value -eq 'True') {
						$true 
					} else {
						$false 
					}
				})
			$query = NewUpdateCriteriaQuery @criteriaParams
			Write-Verbose -Message "Using the update criteria query: [$($Query)]..."
			$searchParams = @{
				Session = $Session
				Query   = $query
			}
			if ($PSBoundParameters.ContainsKey('Source')) {
				$searchParams.Source = $Source
			}
			SearchWindowsUpdate @searchParams
		} catch {
			Write-Error $_.Exception.Message
		} finally {
			## Only clean up the session if it was generated from within this function. This is because updates
			## are stored in a variable to be used again by other functions, if necessary.
			if (($PSCmdlet.ParameterSetName -eq 'ByComputerName') -and (Test-Path Variable:\session)) {
				$session | Remove-PSSession
			}
		}
	}
}

function Install-WindowsUpdate {
	<#
		.SYNOPSIS
			This function retrieves all updates that are targeted at a remote computer, download and installs any that it
			finds. Depending on how the remote computer's update source is set, it will either read WSUS or Microsoft Update
			for a compliancy report.

			Once found, it will download each update, install them and then read output to detect if a reboot is required
			or not.
	
		.EXAMPLE
			PS> Install-WindowsUpdate -ComputerName FOO.domain.local

		.EXAMPLE
			PS> Install-WindowsUpdate -ComputerName FOO.domain.local,FOO2.domain.local			
		
		.EXAMPLE
			PS> Install-WindowsUpdate -ComputerName FOO.domain.local,FOO2.domain.local -ForceReboot

		.PARAMETER ComputerName
			 A mandatory string parameter representing one or more computer FQDNs.

		.PARAMETER Credential
			 A optional pscredential parameter representing an alternate credential to connect to the remote computer.
		
		.PARAMETER ForceReboot
			 An optional switch parameter to set if any updates on any computer targeted needs a reboot following update
			 install. By default, computers are NOT rebooted automatically. Use this switch to force a reboot.
		
		.PARAMETER AsJob
			 A optional switch parameter to set when activity needs to be sent to a background job. By default, this function 
			 waits for each computer to finish. However, if this parameter is used, it will start the process on each
			 computer and immediately return a background job object to then monitor yourself with Get-Job.
	#>
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('MicrosoftUpdate')]
		[string]$Source,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$ForceReboot,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$AsJob
	)
	begin {
		$ErrorActionPreference = 'Stop'

		$scheduledTaskName = 'Windows Update Install'

	}
	process {
		try {
			$getParams = @{}
			if ($PSBoundParameters.ContainsKey('Credential')) {
				$getParams.Credential = $Credential
			}
			if ($PSBoundParameters.ContainsKey('Source')) {
				$getParams.Source = $Source
			}
			@($ComputerName).foreach({
					$getParams.ComputerName = $_
					if (-not (Get-WindowsUpdate @getParams)) {
						Write-Verbose -Message 'No updates needed to install. Skipping computer...'
					} else {
						$installProcess = {
							param($ComputerName, $TaskName, $Credential, $ForceReboot)
							$VerbosePreferences = 'Continue'
							try {
								$sessParams = @{ ComputerName = $ComputerName }
								if ($Credential) {
									$sessParams.Credential = $Credential
								}
							
								$session = New-PSSession @sessParams

								$scriptBlock = {
									$updateSession = New-Object -ComObject 'Microsoft.Update.Session'
									$objSearcher = $updateSession.CreateUpdateSearcher()
									if ($using:Source -eq 'MicrosoftUpdate') {
										$objSearcher.ServerSelection = 3
									}
									if ($updates = ($objSearcher.Search('IsInstalled=0'))) {
										$updates = $updates.Updates

										$downloader = $updateSession.CreateUpdateDownloader();
										$downloader.Updates = $updates;
										$downloadResult = $downloader.Download();
										if ($downloadResult.ResultCode -ne 2) {
											exit $downloadResult.ResultCode;
										}

										$installer = New-Object -ComObject Microsoft.Update.Installer;
										$installer.Updates = $updates;
										$installResult = $installer.Install();
										if ($installResult.RebootRequired) {
											exit 7;
										} else {
											$installResult.ResultCode
										}
									} else {
										exit 6;
									}
								}
							
								$taskParams = @{
									Session     = $session
									Name        = $TaskName
									Scriptblock = $scriptBlock
									PassThru    = $true
								}
								Write-Verbose -Message 'Creating scheduled task...'
								if (-not ($task = NewWindowsUpdateScheduledTask @taskParams)) {
									throw "Failed to create scheduled task."
								}

								Write-Verbose -Message "Starting scheduled task [$($task.TaskName)]..."

								$icmParams = @{
									Session      = $session
									ScriptBlock  = { Start-ScheduledTask -TaskName $args[0] }
									ArgumentList = $task.TaskName
									Verbose      = $true
								}
								Invoke-Command @icmParams
                                
								$waitParams = @{
									ComputerName = $_
								}
								if ($Credential) {
									$waitParams.Credential = $Credential
								}
								Wait-ScheduledTask @waitParams -Name $task.TaskName

								$installResult = GetWindowsUpdateInstallResult -Session $session

								if ($installResult -eq 'NoUpdatesNeeded') {
									Write-Verbose -Message "No updates to install"
								} elseif ($installResult -eq 'RebootRequired') {
									if ($ForceReboot) {
										Restart-Computer -ComputerName $ComputerName -Force -Wait;
									} else {
										Write-Warning "Reboot required but -ForceReboot was not used."
									}
								} else {
									throw "Updates failed. Reason: [$($installResult)]"
								}
							
							} catch {
								$PSCmdlet.ThrowTerminatingError($_)
							} finally {
								Remove-ScheduledTask @getParams -Name $TaskName
							}
						}

						$blockArgs = $_, $scheduledTaskName, $Credential, $ForceReboot.IsPresent
						if ($AsJob.IsPresent) {
							Start-Job -ScriptBlock $installProcess -Name "$_ - Windows Update Install" -ArgumentList $blockArgs
						} else {
							Invoke-Command -ScriptBlock $installProcess -ArgumentList $blockArgs
						}
					}
				})
		} catch {
			Write-Error $_.Exception.Message
		} finally {
			# Remove any sessions created. This is done when processes aren't invoked under a PS job
			$sessParams = @{
				ComputerName = $ComputerName
			}
			if ($PSBoundParameters.ContainsKey('Credential')) {
				$sessParams.Credential = $Credential
			}
			@(Get-PSSession @sessParams).foreach({
					Remove-PSSession -Session $_
				})
		}
	}
}

function GetWindowsUpdateInstallResult {
	[OutputType([string])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[System.Management.Automation.Runspaces.PSSession]$Session,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ScheduledTaskName = 'Windows Update Install'
	)

	$sb = { (Get-ScheduledTask -TaskName $args[0] | Get-ScheduledTaskInfo).LastTaskResult }
	$resultCode = Invoke-Command -Session $Session -ScriptBlock $sb -ArgumentList $ScheduledTaskName
	switch -exact ($resultCode) {
		0   {
			'Installed'
			break
		}
		1   {
			'InProgress'
			break
		}
		2   {
			'Installed'
			break
		}
		3   {
			'InstalledWithErrors'
			break
		}
		4   {
			'Failed'
			break
		}
		5   {
			'Aborted'
			break
		}
		6   {
			'NoUpdatesNeeded'
			break
		}
		7   {
			'RebootRequired'
			break
		}
		267009 {
			'TimedOut'
			break
		}
		default {
			"Unknown exit code [$($_)]"
		}
	}
}

function NewUpdateCriteriaQuery {
	[OutputType([string])]
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[bool]$Installed,

		[Parameter()]
		[bool]$Hidden,

		[Parameter()]
		[bool]$Assigned,

		[Parameter()]
		[bool]$RebootRequired
	)

	$conversion = @{
		Installed      = 'IsInstalled'
		Hidden         = 'IsHidden'
		Assigned       = 'IsAssigned'
		RebootRequired = 'RebootRequired'
	}

	$queryElements = @()
	$PSBoundParameters.GetEnumerator().where({ $_.Key -in $conversion.Keys }).foreach({
			$queryElements += '{0}={1}' -f $conversion[$_.Key], [int]$_.Value
		})
	$queryElements -join ' and '
}

function SearchWindowsUpdate {
	[OutputType()]
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[string]$Query,
        
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Source,

		[Parameter()]
		[System.Management.Automation.Runspaces.PSSession]$Session
	)

	$scriptBlock = {
		$objSession = New-Object -ComObject 'Microsoft.Update.Session'
		$objSearcher = $objSession.CreateUpdateSearcher()
		if ($using:Source -eq 'MicrosoftUpdate') {
			$objServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
			$objSearcher.ServerSelection = 3
			$objServiceManager.Services | Where-Object { $_.Name -eq 'Microsoft Update' } | Foreach {
				$objSearcher.ServiceID = $_.ServiceID
			}
		}
		if ($updates = ($objSearcher.Search($args[0]))) {
			$updates = $updates.Updates
			## Save the updates needed to the file system for other functions to pick them up to download/install later.
			$updates | Export-CliXml -Path "$env:TEMP\Updates.xml"
			$updates
		}
		
	}
	Invoke-Command -Session $Session -ScriptBlock $scriptBlock -ArgumentList $Query
}

function NewWindowsUpdateScheduledTask {
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[System.Management.Automation.Runspaces.PSSession]$Session,

		[Parameter(Mandatory)]
		[string]$Name,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[scriptblock]$Scriptblock,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$PassThru
	)

	if (TestWindowsUpdateScheduledTask -Session $Session -Name $Name) {
		Write-Verbose -Message "A windows update install task already exists. Removing..."
		Remove-ScheduledTask -ComputerName $Session.ComputerName -Name $Name
	}

	$createStartSb = {
		$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $args[1]
		$principal = New-ScheduledTaskPrincipal -UserId $args[3] -LogonType Password
		$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -Hidden
		$task = New-ScheduledTask -Action $action -Settings $settings -Principal $principal
		$regTask = Register-ScheduledTask -InputObject $task -TaskName $args[0]
		if ($args[2].IsPresent) {
			$regTask
		}
	}

	$psArgs = '-NonInteractive -NoProfile -Command "{0}"' -f $Scriptblock.ToString()

	$icmParams = @{
		Session      = $Session
		ScriptBlock  = $createStartSb
		ArgumentList = $Name, $psArgs, $PassThru
	}
	if ($PSBoundParameters.ContainsKey('Credential')) {
		$icmParams.ArgumentList += $Credential.UserName	
	} else {
		$icmParams.ArgumentList += 'SYSTEM'
	}
	
	Invoke-Command @icmParams
	
}

function TestWindowsUpdateScheduledTask {
	[OutputType([bool])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[System.Management.Automation.Runspaces.PSSession]$Session,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	$testScriptBlock = {
		if (Get-ScheduledTask -TaskName $args[0] -ErrorAction Ignore) {
			$true
		} else {
			$false
		}
	}

	Invoke-Command -Session $Session -ScriptBlock $testScriptBlock -ArgumentList $Name
}

function Wait-WindowsUpdate {
	<#
		.SYNOPSIS
			This function looks for any currently running background jobs that were created by Install-WindowsUpdate
			and continually waits for all of them to finish before returning control to the console.
	
		.EXAMPLE
			PS> Wait-WindowsUpdate
		
		.PARAMETER Timeout
			 An optional integer parameter representing the amount of seconds to wait for the job to finish.
	
	#>
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$Timeout = 3600
	)
	process {
		try {
			if ($updateJobs = (Get-Job -Name '*Windows Update Install*').where({ $_.State -eq 'Running'})) {
				$timer = Start-Timer
				while ((Microsoft.PowerShell.Core\Get-Job -Id $updateJobs.Id | Where-Object { $_.State -eq 'Running' }) -and ($timer.Elapsed.TotalSeconds -lt $Timeout)) {
					Write-Verbose -Message "Waiting for all Windows Update install background jobs to complete..."
					Start-Sleep -Seconds 3
				}
				Stop-Timer -Timer $timer
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Remove-ScheduledTask {
	<#
		.SYNOPSIS
			This function looks for a scheduled task on a remote system and, once found, removes it.
	
		.EXAMPLE
			PS> Remove-ScheduledTask -ComputerName FOO -Name Task1
		
		.PARAMETER ComputerName
			 A mandatory string parameter representing a FQDN of a remote computer.

		.PARAMETER Name
			 A mandatory string parameter representing the name of the scheduled task. Scheduled tasks can be retrieved
			 by using the Get-ScheduledTask cmdlet.

		.PARAMETER Credential
			 Specifies a user account that has permission to perform this action. The default is the current user.
			 
			 Type a user name, such as 'User01' or 'Domain01\User01', or enter a variable that contains a PSCredential
			 object, such as one generated by the Get-Credential cmdlet. When you type a user name, you will be prompted for a password.
	
	#>
	[OutputType([void])]
	[CmdletBinding(SupportsShouldProcess)]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential	
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$icmParams = @{
				ComputerName = $ComputerName
				ArgumentList = $Name
			}
			if ($PSBoundParameters.ContainsKey('Credential')) {
				$icmParams.Credential = $Credential
			}
			
			$sb = { 
				if ($task = Get-ScheduledTask -TaskName $args[0] -ErrorAction Ignore) {
					$task | Unregister-ScheduledTask -Confirm:$false
				}
			}

			if ($PSCmdlet.ShouldProcess("Remove scheduled task [$($Name)] from [$($ComputerName)]", '----------------------')) {
				Invoke-Command @icmParams -ScriptBlock $sb	
			}
		} catch {
			Write-Error -Message $_.Exception.Message
		}
	}
}

function Wait-ScheduledTask {
	<#
		.SYNOPSIS
			This function looks for a scheduled task on a remote system and, once found, checks to see if it's running.
			If so, it will wait until the task has completed and return control.
	
		.EXAMPLE
			PS> Wait-ScheduledTask -ComputerName FOO -Name Task1 -Timeout 120
		
		.PARAMETER ComputerName
			 A mandatory string parameter representing a FQDN of a remote computer.

		.PARAMETER Name
			 A mandatory string parameter representing the name of the scheduled task. Scheduled tasks can be retrieved
			 by using the Get-ScheduledTask cmdlet.

		.PARAMETER Timeout
			 A optional integer parameter representing how long to wait for the scheduled task to complete. By default,
			 it will wait 3600 seconds.

		.PARAMETER Credential
			 Specifies a user account that has permission to perform this action. The default is the current user.
			 
			 Type a user name, such as 'User01' or 'Domain01\User01', or enter a variable that contains a PSCredential
			 object, such as one generated by the Get-Credential cmdlet. When you type a user name, you will be prompted for a password.
	
	#>
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$Timeout = 3600, ## seconds

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$sessParams = @{
				ComputerName = $ComputerName
			}
			if ($PSBoundParameters.ContainsKey('Credential')) {
				$sessParams.Credential = $Credential
			}
			$session = New-PSSession @sessParams

			$scriptBlock = {
				$VerbosePreference = 'Continue'
				$timer = [Diagnostics.Stopwatch]::StartNew()
				while (((Get-ScheduledTask -TaskName $args[0]).State -ne 'Ready') -and ($timer.Elapsed.TotalSeconds -lt $args[1])) {
					Write-Verbose -Message "Waiting on scheduled task [$($args[0])]"
					Start-Sleep -Seconds 3
				}
				$timer.Stop()
				Write-Verbose -Message "We waited [$($timer.Elapsed.TotalSeconds)] seconds on the task [$($args[0])]"
			}

			Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $Name, $Timeout
		} catch {
			Write-Error -Message $_.Exception.Message
		} finally {
			if (Test-Path Variable:\session) {
				$session | Remove-PSSession
			}
		}
	}
}