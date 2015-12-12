function Remove-OnlineVM
{
	<#
		.SYNOPSIS
			This function is a wrapper for the Hyper-V module's Remove-VM function gives you the option to force the VM
			to shutdown prior to removal.
	
		.PARAMETER VM
			A VM object from the Get-VM cmdlet that will be targeted to install Integaation Services on.
	
		.PARAMETER Server
			The Hyper-V host that the VM is running on.
	
		.PARAMETER Credential
			A optional PSCredential object to use if you'd like to authenticate with other credentials.
	
		.EXAMPLE
			PS> Get-VM SERVER1 | Remove-OnlineVM -Shutdown
	
			This example is shutting down the SERVER1 VM (if it's on) and then removes the VM.
	#>
	
	[CmdletBinding(SupportsShouldProcess)]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.HyperV.PowerShell.VirtualMachine[]]$VM,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias('ComputerName')]
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
			if ($PSCmdlet.ShouldProcess($vmName,'Remove VM'))
			{
				if ((Get-VM -ComputerName $Server -Name $vmName).State -eq 'Running')
				{
					Write-Verbose -Message "[$vmName)] is online. Shutting down now."
					$v | Stop-VM -Force
				}
				$v | Remove-VM -Force
			}
		}
	}
}