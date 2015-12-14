function Checkpoint-OnlineVM
{
	<#
		.SYNOPSIS
			This function checks to see if a VM is running and if so, shuts it down and creates a checkpoint. If it's not running,
			it will go ahead and create the checkpoint.
	
		.PARAMETER VM
			A virtual machine.	

		.EXAMPLE
			PS> Get-VM -Name SERVER1 | Checkpoint-OnlineVM
	
			This will find the VM called SERVER 1. If it's running, it will shut it down and create a checkpoint. If it's not
			running, it will simply create a checkpoint.
	#>
	
	[CmdletBinding(SupportsShouldProcess,ConfirmImpact = 'High')]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.HyperV.PowerShell.VirtualMachine[]]$VM
	)
	process
	{
		foreach ($v in $VM)
		{
			if ($PSCmdlet.ShouldProcess($v.Name,'VM shutdown'))
			{
				$v | Stop-VM -Force -PassThru | Checkpoint-VM
			}
		}
	}
}