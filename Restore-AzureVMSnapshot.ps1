<#
.SYNOPSIS
	Restores a blob copy (snapshot) of all disks used by an Azure VM
.NOTES
	Created on: 	7/6/2014
	Created by: 	Adam Bertram
	Filename:		Restore-AzureVmSnapshot.ps1
	Credits:		http://bit.ly/1r1umit
	Requirements:	Azure IaaS VM
.EXAMPLE
	Restore-AzureVmSnapshot -AzureVM CCM1 -ServiceName CLOUD
	This example will create a blob copy of all disks in the VM CCM1, Service name CLOUD
.EXAMPLE
	Create-AzureVmSnapshot -AzureVM 'CCM1','CCM2' -Overwrite
	This example creates blob copies for all disks in the VMs CCM1 and CCM2 using the default
	service name parameter and if any existing copies are detected, automatically overwrite them.
.PARAMETER AzureVM
	The name of the Azure VM.  Multiple VM names are supported.
.PARAMETER ServiceName
	The name of your Azure cloud service.
.PARAMETER VmExportConfigFolderPath
	The VM has to be removed in order to restore the snapshot.  This is the directory on the local
	computer that will house the export VM configuration XMLs to be used to restore the VM afterwards.
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory,
			   ValueFromPipeline)]
	[string[]]$AzureVM,
	[string]$ServiceName = 'ADBCLOUD',
	[string]$VmExportConfigFolderPath = 'C:\ExportedVMs'
)

begin {
	Set-StrictMode -Version Latest
	try {
		## Ensure the module is available and import it
		$AzureModuleFilePath = "$($env:ProgramFiles)\Microsoft SDKs\Windows Azure\PowerShell\ServiceManagement\Azure\Azure.psd1"
		if (!(Test-Path $AzureModuleFilePath)) {
			Write-Error 'Azure module not found'
		} else {
			Import-Module $AzureModuleFilePath
		}
		
		$script:BackupContainer = 'backups'
		
		## Ensure a path to store the VM configurations to reprovision the VM later
		if (!(Test-Path $VmExportConfigFolderPath -PathType Container)) {
			New-Item -Path $VmExportConfigFolderPath -ItemType Directory | Out-Null
		}
		
		function Restore-Snapshot([Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVMModel.OSVirtualHardDisk]$Disk) {
			$DiskName = $Disk.DiskName
			$DiskUris = $Disk.MediaLink
			$StorageAccount = $DiskUris.Host.Split('.')[0]
			$Blob = $Disk.MediaLink.Segments[-1]
			$Container = $Disk.MediaLink.Segments[-2].TrimEnd('/')
			
			While ((Get-AzureDisk -DiskName $DiskName).AttachedTo) {
				Write-Verbose "Waiting for $DiskName to detach..."
				Start-Sleep 5
			}
			Remove-AzureDisk -DiskName $DiskName -DeleteVHD
			
			$BlobCopyParams = @{
				'SrcContainer' = $BackupContainer;
				'SrcBlob' = $Blob;
				'DestContainer' = $Container;
				'Force' = $true
			}
			Start-AzureStorageBlobCopy @BlobCopyParams
			Get-AzureStorageBlobCopyState -Container $Container -Blob $Blob -WaitForComplete
			Add-AzureDisk -DiskName $DiskName -MediaLocation $DiskUris.AbsoluteUri -OS 'Windows'
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
			
			## Export the VM's configuration
			$VmExportPath = "$VmExportConfigFolderPath\$($Vm.Name).xml"
			$Vm | Export-AzureVM -Path $VmExportPath
			
			## Remove the VM
			Remove-AzureVM -ServiceName $Vm.ServiceName -Name $Vm.Name
			
			## Restore a snapshot of OS disk
			Restore-Snapshot -Disk $OsDisk
			
			## Restore snapshots of all data disks
			$DataDisks = $Vm | Get-AzureDataDisk
			if ($DataDisks) {
				Write-Verbose "Data disks found on VM.  Restoring..."
				foreach ($DataDisk in $DataDisks) {
					Restore-Snapshot -Disk $DataDisk
				}
			}
			
			Import-AzureVM -Path $VmExportPath | New-AzureVM -ServiceName $Vm.ServiceName
			While ((Get-AzureVM -Name $Vm.Name).Status -ne 'ReadyRole') {
				Write-Verbose "Waiting for $($Vm.Name) to become available again..."
				Start-Sleep 5
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