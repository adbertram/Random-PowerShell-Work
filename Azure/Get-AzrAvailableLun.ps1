#Requires -Version 4

function Get-AzrAvailableLun
{
	<#
	.SYNOPSIS
		This function looks at an Azure ARM VM object and finds the next available LUN. It is typically used to find the next
		available LUN to use for attaching a new data disk to a VM.
		
	.EXAMPLE
		PS> $vm = Get-AzureRmVm -Name 'BAPP07GEN25' -ResourceGroupName 'BDT007'
		PS> Get-AzrAvailableLun -VM $vm
		
		This example would look at the VM object and return the next available LUN number for the VM BAPP07GEN25.
		
	.PARAMETER VM
		An Azure VM object
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]$VM
	)
	process
	{
		$luns = $VM.StorageProfile.DataDisks
		if ($luns.Count -eq 0)
		{
			Write-Verbose -Message "No data disks found attached to VM: [$($VM.Name)]"
			0
		}
		else
		{
			Write-Verbose -Message "Finding the next available LUN for VM: [$($VM.Name)]"
			$lun = ($luns.Lun | Measure-Object -Maximum).maximum + 1
			Write-Verbose -Message "Next available LUN is: [$($lun)]"
			$lun
		}
	}
}