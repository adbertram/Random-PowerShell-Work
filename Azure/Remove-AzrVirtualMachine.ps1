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
				param ($VMName,
					
					$ResourceGroupName)
				$commonParams = @{
					'Name' = $VMName;
					'ResourceGroupName' = $ResourceGroupName
				}
				$vm = Get-AzureRmVm @commonParams
				
				Write-Verbose -Message 'Removing the Azure VM...'
				$vm | Remove-AzureRmVM -Force
				Write-Verbose -Message 'Removing the Azure network interface...'
				$vm | Remove-AzureRmNetworkInterface -Force
				
				## Remove the OS disk
				Write-Verbose -Message 'Removing OS disk...'
				$osDiskUri = $vm.StorageProfile.OSDisk.VirtualHardDisk.Uri
				$osDiskStorageAcct = Get-AzureRmStorageAccount -Name $osDiskUri.Split('/')[2].Split('.')[0]
				$osDiskStorageAcct | Remove-AzureStorageBlob -Container $osDiskUri.Split('/')[-2] -Blob $osDiskUri.Split('/')[-1] -ea Ignore
				
				## Remove any other attached disks
				if ($vm.DataDiskNames.Count -gt 0)
				{
					Write-Verbose -Message 'Removing data disks...'
					foreach ($uri in $vm.StorageProfile.DataDisks.VirtualHardDisk.Uri)
					{
						$dataDiskStorageAcct = Get-AzureRmStorageAccount -Name $uri.Split('/')[2].Split('.')[0]
						$dataDiskStorageAcct | Remove-AzureStorageBlob -Container $uri.Split('/')[-2] -Blob $uri.Split('/')[-1] -ea Ignore
					}
				}
			}
			
			if ($Wait.IsPresent)
			{
				& $scriptBlock -VMName $VMName -ResourceGroupName $ResourceGroupName
			}
			else
			{
				$initScript = {
					$null = Login-AzureRmAccount -Credential (Get-KeyStoreCredential -Name 'Azure svcOrchestrator')
				}
				Start-Job -ScriptBlock $scriptBlock -InitializationScript $initScript -ArgumentList @($VMName, $ResourceGroupName)
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}