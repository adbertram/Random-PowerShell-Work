function Backup-VM
{
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
		[string]$FolderPath,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Server,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
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