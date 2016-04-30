#Requires -Version 4
#Requires -Module AzureRm.Compute

function Copy-AzureItem
{
	<#
	.SYNOPSIS
		This function simplifies the process of uploading files to an Azure storage account. In order for this function to work you
		must have already logged into your Azure subscription with Login-AzureAccount. The file uploaded will be called the file
		name as the storage blob.
		
	.PARAMETER FilePath
		The local path of the file(s) you'd like to upload to an Azure storage account container.
	
	.PARAMETER ContainerName
		The name of the Azure storage account container the file will be placed in.
	
	.PARAMETER DestinationName
		The name of the file stored as an Azure blob. By default, it will be the same name as as the local file. Use this parameter
		to give it a different name once uploaded.
	
	.PARAMETER BlobType
		The type of blob you'd like the file to become when it gets uploaded to the storage account. For example, when
		uploading VHDs, you should only use Page.
	
	.PARAMETER ResourceGroupName
		The name of the resource group the storage account is in.
	
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
		[string]$ResourceGroupName,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$StorageAccountName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$DestinationName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Page', 'Block')]
		[string]$BlobType = 'Page'
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$saParams = @{
				'ResourceGroupName' = $ResourceGroupName
				'Name' = $StorageAccountName
			}
			
			$storageContainer = Get-AzureRmStorageAccount @saParams | Get-AzureStorageContainer -Container $ContainerName
			
			if (-not $PSBoundParameters.ContainsKey('DestinationName'))
			{
				$DestinationName = $FilePath | Split-Path -Leaf
			}
			
			## Use Add-AzureRmVhd if the file is a VHD. Set-AzureStorageBlobContent is known to corrupt the large VHD when uploading
			if ($FilePath.EndsWith('.vhd'))
			{
				$destination = ('{0}{1}/{2}' -f $storageContainer.Context.BlobEndPoint, $ContainerName, $DestinationName)
				$vhdParams = @{
					'ResourceGroupName' = $ResourceGroupName
					'Destination' = $destination
					'LocalFilePath' = $FilePath
				}
				Write-Verbose -Message "Uploading [$($vhdParams.LocalFilePath)] to [$($vhdParams.Destination)] in resource group [$($vhdParams.ResourceGroupName)]..."
				Add-AzureRmVhd @vhdParams
			}
			else
			{
				$bcParams = @{
					'File' = $FilePath
					'BlobType' = $BlobType
					'Blob' = $DestinationName
				}
				$storageContainer | Set-AzureStorageBlobContent @bcParams
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}