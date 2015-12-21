function Backup-VM
{
	<#
	.SYNOPSIS
		This function takes input from Get-VM, checks if a VM is online and if so, shuts it down. Once shut down, it will then export
		the VM to the path specified in the FolderPath parameter. It will then bring the VM back up when done.	
	
	.EXAMPLE
		PS> Get-VM | Backup-VM -FolderPath C:\VMBackups
	
		This example backs up all VMs returned by Get-VM and create OVA files with the VM names in the C:\VMBackups folder.
		
	.PARAMETER VM
		A VM object that represents the VM to be backed up. This can be populated via Get-VM or by providing any number of
		VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl objects separated by a comma.
	
	.PARAMETER FolderPath
		The path to where the VM's OVA file will be created.
	
	.INPUTS
		VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl
	
	.OUTPUTS
		None.
	#>
	[CmdletBinding(SupportsShouldProcess)]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl[]]
		$VM,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path $_ -PathType Container })]
		[string]$FolderPath
	)
	process
	{
		foreach ($v in $VM)
		{
			$vmName = $v.Name
			if ($v.PowerState -eq 'PoweredOn')
			{
				if ($PSCmdlet.ShouldProcess($vmName, 'Shutdown VM'))
				{
					Write-Verbose -Message "[$($vmName)] is online. Shutting down."
					$null = Shutdown-VMGuest -VM $v -Confirm:$false
					while ((Get-VM -Name $vmName).PowerState -ne 'PoweredOff') {
						Start-Sleep -Seconds 1
						Write-Verbose -Message "Waiting for [$($vmName)] to shutdown."
					}
					Write-Verbose -Message "[$($vmName)] has shut down."
				}
			}
			#Export the VM in OVA format creating a file
			Export-VApp -Destination $FolderPath -VM $v -Format OVA
			
			$v | Start-VM
		}
	}
}