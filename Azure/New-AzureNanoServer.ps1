#Requires -Version 4

#region Download Windows Server 2016 TP4



#endregion

#region Copy the Nano Server module and conversion script from the Server 2016 ISO



#endregion

Import-Module "$nanoFolderPath\NanoServerImageGenerator.psm1"
New-NanoServerImage -MediaPath $winSrvDrivePath -BasePath $nanoFolderPath -TargetPath "$nanoFolderPath\Nano.vhd" -ComputerName NanoServer –GuestDrivers -AdministratorPassword p@$$w0rd1


#region Add necessary packages to the Nano VHD

#Add-WindowsPackage –Path E:\ –PackagePath C:\NanoServer\Packages\Microsoft-NanoServer-Compute-Package.cab
#Add-WindowsPackage –Path E:\ –PackagePath C:\NanoServer\Packages\Microsoft-NanoServer-FailoverCluster-Package.cab
#Add-WindowsPackage –Path E:\ –PackagePath C:\NanoServer\Packages\Microsoft-NanoServer-Guest-Package.cab
#Add-WindowsPackage –Path E:\ –PackagePath C:\NanoServer\Packages\Microsoft-NanoServer-OEM-Drivers-Package.cab
#Add-WindowsPackage –Path E:\ –PackagePath C:\NanoServer\Packages\Microsoft-NanoServer-Storage-Package.cab
#Add-WindowsPackage –Path E:\ –PackagePath C:\NanoServer\Packages\Microsoft-OneCore-ReverseForwarders-Package.cab

#endregion

## Sysprep the VHD

#region Ensure Azure is setup in PowerShell

Import-Module Azure
Add-AzureAccount
Select-AzureSubscription -Default $subscription

#endregion

#region Create storage account

## Check the Azure location
Get-AzureLocation | select name

## Check if the affinity group is there
$affinityGroup = 'somegroup'
Get-AffinityGroup -Name $affinityGroup -ea Ignore

New-AzureAffinityGroup -Name 'testgroup' -Location 'Central US'

Get-AzureStorageAccount -Name
New-AzureStorageAccount -StorageAccountName 'adamstorage123' -AffinityGroup testgroup

Get-AzureStorageAccount | Format-Table -Property Label
$storageAccountName = "jrprlabstor01"
Get-AzureStorageContainer

#endregion

#region Add the Azure VHD
$LocalVHD = "C:\NanoServer\NanoServer.vhd"

$storageEndpoint = (Get-AzureStorageAccount -StorageAccountName adamstorage123).Endpoints[0].Trim('/')

## Azure location --> Azure affinity group --> Azure storage account --> Azure storage container
Get-AzureStorageAccount | Get-AzureStorageContainer
$imagesContainer = 'testcontainer' ## ?????

$AzureVHD = "$storageEndpoint/$imagesContainer/nano.vhd"
Add-AzureVhd -LocalFilePath $LocalVHD -Destination $AzureVHD


Add-AzureVMImage -ImageName 'nano.vhd' -MediaLocation <VHDLocation> -OS 'Windows'

#Identify the URL for the container in the storage account
# we set in the previous command.

#endregion

