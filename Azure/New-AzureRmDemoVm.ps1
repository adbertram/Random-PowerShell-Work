#Requires -Version 4 -Modules @{'ModuleName' = 'AzureRm.Compute'; 'ModuleVersion' = '1.3.1'}

[CmdletBinding()]
param
(
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$VMName,

	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$VMResourceGroupName,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[ValidateScript({ $_ -in (Get-AzureRmLocation).DisplayName })]
	[string]$VMResourceGroupLocation,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[pscredential]$VMAdministratorCredential,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[ValidateScript({ $_ -in (Get-AzureRmVMSize -Location $VMResourceGroupLocation).Name })]
	[string]$vmSize,	

	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$StorageAccountName,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$StorageAccountResourceGroupName,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[ValidateScript({ $_ -in (Get-AzureRmLocation).DisplayName })]
	[string]$StorageAccountResourceGroupLocation,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[ValidateSet('Standard_LRS', 'Standard_GRS','Standard_RAGRS','Premium_LRS')]
	[string]$StorageAccountType,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$VNetName,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$VNetResourceGroupName,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[ValidateScript({ $_ -in (Get-AzureRmLocation).DisplayName })]
	[string]$VNetResourceGroupLocation,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[ValidatePattern('^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))$')]
	[string]$VNetAddressPrefix,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$VNicName,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$VNicResourceGroupName,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[ValidateScript({ $_ -in (Get-AzureRmLocation).DisplayName })]
	[string]$VNicResourceGroupLocation,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$SubnetName,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$SubnetAddressPrefix,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$OsDiskName,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[pscredential]$AzureSubscriptionCredential,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[ValidateScript({ $_ -in (Get-AzureRmLocation).DisplayName })]
	[string]$ImageLocation,
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$ImagePublisher = 'MicrosoftWindowsServer',
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$ImageVersion = 'Latest',
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$ImageSkuName = '2012-R2-Datacenter',
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[switch]$ProvisionVMAgent,
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[switch]$EnableAutoUpdate
)

begin
{
	try
	{
		$ErrorActionPreference = 'Stop'
		$azureCredential = Add-AzureRmAccount -Credential $AzureSubscriptionCredential
	}
	catch
	{
		$PSCmdlet.ThrowTerminatingError($_)
	}
}
process
{
	try
	{
		#region Create resource groups (if necessary)
		$resourceGroups = @(
			@{ 'Label' = $StorageAccountName; 'Location' = $StorageAccountResourceGroupLocation }
			@{ 'Label' = $VMResourceGroupName; 'Location' = $VMResourceGroupLocation }
			@{ 'Label' = $VNetResourceGroupName; 'Location' = $VNetResourceGroupLocation }
			@{ 'Label' = $VNicResourceGroupName; 'Location' = $VNicResourceGroupLocation }
		)
		
		foreach ($rg in $resourceGroups)
		{
			$rgName = $rg.Label
			$rgLocation = $rg.Location
			if ($rgName -notin (Get-AzureRmResourceGroup).ResourceGroupName)
			{
				Write-Verbose -Message "Creating resource group [$($rgName)] in location [$($rgLocation)]..."
				$null = New-AzureRmResourceGroup -Name $rgName -Location $rgLocation
			}
		}
		#endregion
		
		#region Storage account
		
		if ($StorageAccountName -notin (Get-AzureRmStorageAccount -ResourceGroupName $StorageAccountResourceGroupName).StorageAccountName)
		{
			$newStorageAcctParams = @{
				'Name' = $StorageAccountName.ToLower() ## Must be globally unique and all lowercase
				'ResourceGroupName' = $StorageAccountResourceGroupName
				'Type' = $StorageAccountType
				'Location' = $StorageAccountResourceGroupLocation
			}
			
			$storageAcct = New-AzureRmStorageAccount @newStorageAcctParams
			
		}
		else
		{
			$storageAcct = Get-AzureRmStorageAccount -ResourceGroupName $StorageAccountResourceGroupName
		}
		
		#endregion
		
		#region vNet
		if ($VNetName -notin (Get-AzureRmVirtualNetwork -ResourceGroupName $VNetResourceGroupName).Name)
		{
			$newSubnetParams = @{
				'Name' = $SubnetName
				'AddressPrefix' = $SubnetAddressPrefix
			}
			
			$subnet = New-AzureRmVirtualNetworkSubnetConfig @newSubnetParams
			
			$newVNetParams = @{
				'Name' = $VNetName
				'ResourceGroupName' = $VNetResourceGroupName
				'Location' = $VNetResourceGroupLocation
				'AddressPrefix' = $VNetAddressPrefix
			}
			
			$vNet = New-AzureRmVirtualNetwork @newVNetParams -Subnet $subnet
		}
		else
		{
			$vNet = Get-AzureRmVirtualNetwork -ResourceGroupName $VNetResourceGroupName
			if ($SubnetName -notin $vNet.Subnets)
			{
				$newSubnetParams = @{
					'Name' = $SubnetName
					'AddressPrefix' = $SubnetAddressPrefix
				}
				
				$subnet = New-AzureRmVirtualNetworkSubnetConfig @newSubnetParams
			}
		}
		
		#endregion
		
		#region vNic
		
		if ($VNicName -notin (Get-AzureRmNetworkInterface -ResourceGroupName $VNicResourceGroupName).Name)
		{
			$newVNicParams = @{
				'Name' = $VNicName
				'ResourceGroupName' = $VNicResourceGroupName
				'Location' = $VNicResourceGroupLocation
			}
			
			$vNic = New-AzureRmNetworkInterface @newVNicParams -SubnetId $subnet.Id
			
		}
		else
		{
			$vNic = Get-AzureRmNetworkInterface -ResourceGroupName $VNicResourceGroupName
		}

		#endregion
		
		$vmConfig = New-AzureRmVMConfig -VMName $VMName -VMSize $vmSize
		
		#region OS
		$newVmOsParams = @{
			'ComputerName' = $VMName
			'Credential' = $VMAdministratorCredential
			'ProvisionVMAgent' = $ProvisionVMAgent.IsPresent
			'EnableAutoUpdate' = $EnableAutoUpdate.IsPresent
		}
		$vm = Set-AzureRmVMOperatingSystem @newVmOsParams -VM $vmConfig
		
		if ($ImagePublisher -match 'Windows')
		{
			$osParams.Windows = $true
		}
		else
		{
			$osParams.Windows = $false
		}
		#endregion
		
		#region Source image
		$offer = Get-AzureRmVMImageOffer -Location $ImageLocation -PublisherName $ImagePublisher
		
		$newSourceImageParams = @{
			'PublisherName' = $ImagePublisher
			'Version' = $ImageVersion
			'Skus' = $ImageSkuName
		}
		$vm = Set-AzureRmVMSourceImage @newSourceImageParams -VM $vm -Offer $offer.Offer
		#endregion
		
		## Attach the NIC
		$vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $vNic.Id
		
		#region OS Disk
		## Build the storage account container
		$osDiskUri = '{0}vhds/{1}{2}.vhd' -f $storageAcct.PrimaryEndpoints.Blob.ToString(), $VMName,$OsDiskName
		
		## Create the OS disk
		$vm = Set-AzureRmVMOSDisk -Name $OsDiskName -CreateOption 'fromImage' -VM $vm -VhdUri $osDiskUri
		
		#endregion
		
		## Create the VM
		New-AzureRmVM -ResourceGroupName $VMResourceGroupName -Location $VMResourceGroupLocation -VM $vm
	}
	catch
	{
		$PSCmdlet.ThrowTerminatingError($_)
	}
}