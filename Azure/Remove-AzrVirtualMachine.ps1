#Requires -Module AzureRm.Compute

function Remove-AzrVirtualMachine
{
	<#
	.SYNOPSIS
		This function is used to remove any Azure VMs as well as any attached disks. By default, this function creates a job
		due to the time it takes to remove an Azure VM.
		
	.EXAMPLE
		PS> Login-AzureRmAccount -Credential (Get-KeyStoreCredential -Name 'svcOrchestrator')
		PS> Get-AzureRmVm -Name 'BAPP07GEN22' | Remove-AzrVirtualMachine
	
		This example removes the Azure VM BAPP07GEN22 as well as any disks attached to it.
		
	.PARAMETER VMName
		The name of an Azure VM. This has an alias of Name which can be used as pipeline input from the Get-AzureRmVM cmdlet.
	
	.PARAMETER ResourceGroupName
		The name of the resource group the Azure VM is a part of.
	
	.PARAMETER Wait
		If you'd rather wait for the Azure VM to be removed before returning control to the console, use this switch parameter.
		If not, it will create a job and return a PSJob back.
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias('Name')]
		[string]$VMName,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$ResourceGroupName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$Wait
		
	)
	process
	{
		try
		{
			$scriptBlock = {
				$commonParams = @{
					'Name' = $using:VMName;
					'ResourceGroupName' = $using:ResourceGroupName
				}
				$vm = Get-AzureRmVm @commonParams
				if ($vm.DataDiskNames.Count -gt 0)
				{
					Write-Verbose -Message 'Removing data disks...'
					$vm | Remove-AzureRmVMDataDisk | Update-AzureRmVM
				}
				Write-Verbose -Message 'Removing the Azure VM...'
				$vm | Remove-AzureRmVM -Force
				Write-Verbose -Message 'Removing the Azure network interface...'
				$vm | Remove-AzureRmNetworkInterface -Force
			}
			
			if ($Wait.IsPresent)
			{
				& $scriptBlock
			}
			else
			{
				$initScript = {
					$null = Login-AzureRmAccount -Credential (Get-KeyStoreCredential -Name 'Azure svcOrchestrator')
				}
				Start-Job -ScriptBlock $scriptBlock -InitializationScript $initScript
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}