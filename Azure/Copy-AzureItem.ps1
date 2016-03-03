#region function Copy-AzureItem
function Copy-AzureItem
{
	<#
	.SYNOPSIS
		This function simplifies the process of uploading files to an Azure storage account. In order for this function to work you
		must have already logged into your Azure subscription with Login-AzureAccount. The file uploaded will be called the file
		name as the storage blob.
	
	.EXAMPLE
		PS> Get-ChildItem -Path C:\Folder | Copy-AzureItem -ContainerName mycontainer -ResourceGroupName myresources -StorageAccountName mysa
		
		This example would upload all files in the C:\Folder directory to the container named mycontainer in your Azure storage account.
	
	.PARAMETER FilePath
		The local path of the file(s) you'd like to upload to an Azure storage account container.
	
	.PARAMETER ContainerName
		The name of the Azure storage account container the file will be placed in.
	
	.PARAMETER ResourceGroupName
		The name of the resource group the storage account is in.
        
    .PARAMETER BlobType
        The blob type to create when the file gets to Azure.
	
	.PARAMETER StorageAccountName
		The name of the storage account the container that will hold the file is in.
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[Alias('FullName')]
		[string]$FilePath,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ContainerName,
        
        [Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$BlobType = 'Page',
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ResourceGroupName,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$StorageAccountName
	)
	process
	{
		try
		{
			$saParams = @{
				'ResourceGroupName' = $ResourceGroupName
				'Name' = $StorageAccountName
			}
			
			$scParams = @{
				'Container' = $ContainerName
			}
			
			$bcParams = @{
				'File' = $FilePath
				'Blob' = ($FilePath | Split-Path -Leaf)
			}
			Get-AzureRmStorageAccount @saParams | Get-AzureStorageContainer @scParams | Set-AzureStorageBlobContent @bcParams
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function Copy-AzureItem