<#
.SYNOPSIS
	This script is intended to migrate scheduled tasks from a Windows Server 2003 server to a Windows Server 2012 server.  It is
	intended to be ran locally on the source computer and will use remoting to connect to the destination server.		
.EXAMPLE
	PS> Move-ScheduledTask.ps1 -DestinationComputername LABDC

	This example will find all scheduled tasks on the local computer and replicate them on LABDC

.EXAMPLE
	PS> Move-ScheduledTask.ps1 -DestinationComputername LABDC -ExcludePaths '\MyFolder' -SkipDisabledTasks

	This example will find all enabled scheduled tasks not in the MyFolder task folder and replicate them
	on LABDC
.PARAMETER DestinationComputername
	The name of the computer that scheduled tasks will be migrated to
.PARAMETER ExcludePaths
	By default, this script excludes the default folder path '\Microsoft'.  Use this parameter to add any other folders
	you'd like to exclude.
.PARAMETER ExcludeTasks
	By default, this script will migrate all scheduled tasks from the localhost to $DestinationComputername.  Use this parameter
	to specify any scheduled tasks that you do not want created on $DestinationComputername.
.PARAMETER SkipDisabledTasks
	Use this switch parameter to skip all tasks that are disabled
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory)]
	[ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1 })]
	[string]$DestinationComputername,
	[string[]]$ExcludePaths,
	[string[]]$ExcludeTasks,
	[switch]$SkipDisabledTasks
)

function Get-MyScheduledTask ($Computername) {
	$ScriptBlock = {
		$Service = New-object -ComObject ("Schedule.Service")
		$Service.Connect()
		$Folders = [System.Collections.ArrayList]@()
		$Root = $Service.GetFolder("\")
		$Folders.Add($Root) | Out-Null
		$Root.GetFolders(0) | foreach { $Folders.Add($_) | Out-Null }
		foreach ($Folder in $Folders) {
			$Folder.GetTasks(0)
		}
	}
	if (-not $PSBoundParameters.ContainsKey('ComputerName')) {
		$ScriptBlock.Invoke()
	} else {
		Invoke-Command -ComputerName $Computername -ScriptBlock $ScriptBlock
	}
}

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

try {
	## Get all of the scheduled paths not intentionally excluded
	$SrcSchTasks = Get-MyScheduledTask | where { $ExcludePaths -notcontains $_.Path }
	Write-Verbose "Found $(@($SrcSchTasks).Count) scheduled tasks on [$DestinationComputername] to migrate."
	## If there's no scheduled tasks, exit
	if (!$SrcSchTasks) {
		throw "No scheduled tasks found on localhost"
	}
	
	## Always exclude these task folders
	$ExcludePaths += '\Microsoft'
	
	## Create a remote session with the destination server for reuse
	## Assuming your logged on user has permission to the destination computer here
	$DestSession = New-PSSession -ComputerName $DestinationComputername
	
	## Because I can't export out any user password from the source computer find all of the user accounts where a password
	## is needed and prompt the user to insert the credentials in this script and doing a lookup rather than prompting
	## the user over and over for the same password
	$UserAccountsAffected = $SrcSchTasks | foreach { ([xml]$_.xml).Task.Principals.Principal.UserId } | Select-Object -Unique
	if ($UserAccountsAffected) {
		$StoredCredentials = @{ }
		$UserAccountsAffected | foreach {
			$Password = Read-Host "What is the password for $($_)?"
			$StoredCredentials[$_] = $Password
		}
	}
	
	## Find all scheduled tasks on the destination server with the full path in order to not overwrite these later
	$BeforeDestSchTasks = Get-MyScheduledTask -Computername $DestinationComputername | Select-Object -ExpandProperty Path
	Write-Verbose "Found $(@($BeforeDestSchTasks).Count) scheduled tasks on destination computer pre-migration"
	
	foreach ($Task in $SrcSchTasks) {
		## Don't overwrite any existing scheduled tasks
		if ($BeforeDestSchTasks -contains $Task.Path) {
			Write-Warning "The task $($Task.Path) already exists on the destination computer"
		} elseif ($ExcludeTasks -contains $Task.Name) {
			Write-Verbose "Skipping the task $($Task.Name)"
		} else {
			## Skip a disabled task if the $SkipDisabledTasks param was set
			$xTask = [xml]$Task.xml
			if (($xTask.Task.Settings.Enabled -eq 'false') -and $SkipDisabledTasks.IsPresent) {
				Write-Verbose "Skipping disabled task $($Task.Path)"
			} else {
				## Find the user in the scheduled tasks and perform a hash table lookup from the passwords gathered earlier
				## to use for the password in the task created on $DestinationComputername
				$User = $xTask.Task.Principals.Principal.UserId
				$Password = $StoredCredentials[$User]
				$Path = $Task.Path | Split-Path -Parent
				## Use remoting to connect to the destination server.  I'm assuming this destination server is Win8+ or Win2012+ because
				## I'm using Register-ScheduledTask
				$taskName = $Task.Name
				Invoke-Command -Session $DestSession -ScriptBlock {
					Register-ScheduledTask -Xml $using:xTask -TaskName $using:taskName -TaskPath $using:Path -User $using:User -Password $using:Password | Out-Null
				}
			}
		}
	}
} catch {
	Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
} finally {
	if (Get-Variable -name DestSession -ErrorAction Ignore) {
		Remove-PSSession $DestSession
	}
}
