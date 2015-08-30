<#
.SYNOPSIS
	This creates a blob copy (snapshot) of all disks used by an Azure VM
.NOTES
	Created on: 	7/5/2014
	Created by: 	Adam Bertram
	Filename:		Create-AzureVmSnapshot.ps1
	Credits:		http://bit.ly/1ouJKjR
	Requirements:	Azure IaaS VM
.EXAMPLE
	Create-AzureVmSnapshot -AzureVM CCM1 -ServiceName CLOUD
	This example will create a blob copy of all disks in the VM CCM1, Service name CLOUD
.EXAMPLE
	Create-AzureVmSnapshot -AzureVM 'CCM1','CCM2' -Overwrite
	This example creates blob copies for all disks in the VMs CCM1 and CCM2 using the default
	service name parameter and if any existing copies are detected, automatically overwrite them.
.PARAMETER AzureVM
	The name of the Azure VM.  Multiple VM names are supported.
.PARAMETER ServiceName
	The name of your Azure cloud service.
.PARAMETER Overwrite
	Use this switch to overwrite any existing blob copies without asking
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory,
		ValueFromPipeline)]
	[string[]]$AzureVM,
	[string]$ServiceName = 'ADBCLOUD',
	[switch]$Overwrite
)

begin {
	Set-StrictMode -Version Latest
	try {
		$AzureModuleFilePath = "$($env:ProgramFiles)\Microsoft SDKs\Windows Azure\PowerShell\ServiceManagement\Azure\Azure.psd1"
		if (!(Test-Path $AzureModuleFilePath)) {
			Write-Error 'Azure module not found'
		} else {
			Import-Module $AzureModuleFilePath	
		}
		
		$script:BackupContainer = 'backups'
		
		function New-Snapshot([Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVMModel.OSVirtualHardDisk]$Disk) {
			$Blob = $Disk.MediaLink.Segments[-1]
			$Container = $Disk.MediaLink.Segments[-2].TrimEnd('/')
			$BlobCopyParams = @{
				'SrcContainer' = $Container;
				'SrcBlob' = $Blob;
				'DestContainer' = $BackupContainer
			}
			if ($Overwrite.IsPresent) {
				$BlobCopyParams.Force = $true	
			}
			Start-AzureStorageBlobCopy @BlobCopyParams
			#Get-AzureStorageBlobCopyState -Container $BackupContainer -Blob $Blob -WaitForComplete
		}
		
		## Ensure the container is created to store the snapshot
		if (!(Get-AzureStorageContainer -Name $BackupContainer -ea SilentlyContinue)) {
			Write-Verbose "Container $BackupContainer not found.  Creating..."
			New-AzureStorageContainer -Name $BackupContainer -Permission Off
		}
		
	} catch {
		Write-Error $_.Exception.Message
		exit
	}
}

process {
	try {
		foreach ($Vm in $AzureVM) {
			$Vm = Get-AzureVM -ServiceName $ServiceName -Name $Vm
			if ($Vm.Status -ne 'StoppedVM') {
				if ($Vm.Status -eq 'ReadyRole') {
					Write-Verbose "VM $($Vm.Name) is started.  Bringing down into a provisioned state"
					## Bring the VM down in a provisioned state
					$Vm | Stop-AzureVm -StayProvisioned
				} elseif ($Vm.Status -eq 'StoppedDeallocated') {
					Write-Verbose "VM $($Vm.Name) is stopped but not in a provisioned state."
					## Bring up the VM and bring it back down in a provisioned state
					Write-Verbose "Starting up VM $($Vm.Name)..."
					$Vm | Start-AzureVm
					while ((Get-AzureVm -ServiceName $ServiceName -Name $Vm.Name).Status -ne 'ReadyRole') {
						sleep 5
						Write-Verbose "Waiting on VM $($Vm.Name) to be in a ReadyRole state..."
					}
					Write-Verbose "VM $($Vm.Name) now up.  Bringing down into a provisioned state..."
					$Vm | Stop-AzureVm -StayProvisioned
				}
				
			}
			
			$OsDisk = $Vm | Get-AzureOSDisk
			Get-AzureSubscription | Set-AzureSubscription -CurrentStorageAccountName ($OsDisk.MediaLink.Host.Split('.')[0])
			
			## Take snapshot of OS disk
			New-Snapshot -Disk $OsDisk
		
			## Take snapshots of all data disks
			$DataDisks = $Vm | Get-AzureDataDisk
			if ($DataDisks) {
				foreach ($DataDisk in $DataDisks) {
					New-Snapshot -Disk $DataDisk
				}
			}
		}
	} catch {
		Write-Error $_.Exception.Message
		exit
	}
}

end {
	try {
		
	} catch {
		Write-Error $_.Exception.Message
	}
}