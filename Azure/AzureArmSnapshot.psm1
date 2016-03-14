#Requires -Module AzureRM.Compute
#Requires -Version 4

Set-StrictMode -Version Latest

## Authenticate to Azure when the module is loaded
$null = Login-AzureRMAccount

$Defaults = @{
	'VMResourceGroupName' = ''
	'SnapshotStorageContainerName' = ''
	'SnapshotStorageAccountName' = ''
	'SnapshotStorageAccountResourceGroupName' = ''
}

function New-AzureVmSnapshot
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory,ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$VMName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ResourceGroupName = $Defaults.VMResourceGroupName
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
		
		try
		{
			$sg = Get-AzureRmStorageAccount -ResourceGroupName $Defaults.SnapshotStorageAccountResourceGroupName -Name $Defaults.SnapshotStorageAccountName
			if (($sg | Get-AzureStorageContainer).Name -notcontains $Defaults.SnapshotStorageContainerName)
			{
				throw "The snapshot storage account container [$($Defaults.SnapshotStorageContainerName)] does not exist."	
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
		
	}
	process {
		try
		{
			$vm = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName
			
			Write-Verbose -Message 'Stopping VM...'
			$stopVmResult = $vm | Stop-AzureRmVM -Force
			
			#region Create an image
			Save-AzureRmVMImage -ResourceGroupName $resourceGroupName -Name $vmName -DestinationContainerName snapshots
			(gc C:\testimage.json -Raw | ConvertFrom-Json).resources.properties.storageprofile.osdisk.name
			
			#endregion
			
			#region Remove the VM
			
			#endregion
			
			#region Recreate the VM
			
			#endregion
			
			#region Reattach the VHD to the new VM
			
			#endregion
			
			
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Restore-AzureVmSnapshot
{
	[CmdletBinding()]
	param
	(
		
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
				
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

# Set variable values
$resourceGroupName = "SnapshotDemo"
$location = "West US"
$vmName = "SnapshotDemo"
$vmSize = "Standard_A1"
$vnetName = "SnapshotDemo"
$nicName = "snapshotdemo98"
$dnsName = "snapshotdemo"
$diskName = "SnapshotDemo"
$storageAccount = "snapshotdemo5062"
$storageAccountKey = "<Insert Storage Account Key Here>"
$subscriptionName = "Visual Studio Enterprise with MSDN"
$publicIpName = "SnapshotDemo"

$diskBlob = "$diskName.vhd"
$backupDiskBlob = "$diskName-backup.vhd"
$vhdUri = "https://$storageAccount.blob.core.windows.net/vhds/$diskBlob"
$subnetIndex = 0

# login to Azure
Add-AzureRmAccount
Set-AzureRMContext -SubscriptionName $subscriptionName

# create backup disk if it doesn't exist
Stop-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName -Force -Verbose

$ctx = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageAccountKey
$blobCount = Get-AzureStorageBlob -Container vhds -Context $ctx | where { $_.Name -eq $backupDiskBlob } | Measure | % { $_.Count }

if ($blobCount -eq 0)
{
	$copy = Start-AzureStorageBlobCopy -SrcBlob $diskBlob -SrcContainer "vhds" -DestBlob $backupDiskBlob -DestContainer "vhds" -Context $ctx -Verbose
	$status = $copy | Get-AzureStorageBlobCopyState
	$status
	
	While ($status.Status -eq "Pending")
	{
		$status = $copy | Get-AzureStorageBlobCopyState
		Start-Sleep 10
		$status
	}
}

# delete VM
Remove-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName -Force -Verbose
Remove-AzureStorageBlob -Blob $diskBlob -Container "vhds" -Context $ctx -Verbose
Remove-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $resourceGroupName -Force -Verbose
Remove-AzureRmPublicIpAddress -Name $publicIpName -ResourceGroupName $resourceGroupName -Force -Verbose

# copy backup disk
$copy = Start-AzureStorageBlobCopy -SrcBlob $backupDiskBlob -SrcContainer "vhds" -DestBlob $diskBlob -DestContainer "vhds" -Context $ctx -Verbose
$status = $copy | Get-AzureStorageBlobCopyState
$status

While ($status.Status -eq "Pending")
{
	$status = $copy | Get-AzureStorageBlobCopyState
	Start-Sleep 10
	$status
}

# recreate VM
$vnet = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroupName

$pip = New-AzureRmPublicIpAddress -Name $publicIpName -ResourceGroupName $resourceGroupName -DomainNameLabel $dnsName -Location $location -AllocationMethod Dynamic -Verbose
$nic = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $resourceGroupName -Location $location -SubnetId $vnet.Subnets[$subnetIndex].Id -PublicIpAddressId $pip.Id -Verbose
$vm = New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize
$vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id
$vm = Set-AzureRmVMOSDisk -VM $vm -Name $diskName -VhdUri $vhdUri -CreateOption attach -Windows

New-AzureRmVM -ResourceGroupName $resourceGroupName -Location $location -VM $vm -Verbose