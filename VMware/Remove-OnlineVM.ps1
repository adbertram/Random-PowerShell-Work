function Remove-OnlineVM
{
	<#
	.SYNOPSIS
		This function is a wrapper for the PowerCLI's Remove-VM function gives you the option to force the VM
		to shutdown prior to removal.

	.PARAMETER VM
		A VM object from the Get-VM cmdlet.

	.EXAMPLE
		PS> Get-VM SERVER1 | Remove-OnlineVM -Shutdown

		This example is shutting down the SERVER1 VM (if it's on) and then removes the VM.
	#>
	
	[CmdletBinding(SupportsShouldProcess)]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl[]]$VM
	)
	process
	{
		foreach ($v in $VM)
		{
			$vmName = $v.Name
			if ($PSCmdlet.ShouldProcess($vmName, 'Remove VM'))
			{
				if ((vmware.vimautomation.core\Get-VM -Name $vmName).PowerState -eq 'PoweredOn')
				{
					Write-Verbose -Message "[$vmName)] is online. Shutting down now."
					$v | vmware.vimautomation.core\Stop-VM -Confirm:$false
				}
				$v | vmware.vimautomation.core\Remove-VM -Confirm:$false
			}
		}
	}
}