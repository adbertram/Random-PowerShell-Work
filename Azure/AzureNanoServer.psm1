#Requires -Module Azure
#Requires -Version 4

function Invoke-WindowsServer2016Download
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ -not (Test-Path -Path $_ -PathType Leaf) })]
		[string]$FilePath,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$DownloadUrl = 'http://care.dlservice.microsoft.com/dl/download/C/2/5/C257AD1A-45C1-48F9-B31C-5D37D6463123/10586.0.151029-1700.TH2_RELEASE_SERVER_OEMRET_X64FRE_EN-US.ISO'
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			$webClient = New-Object System.Net.WebClient
			$webClient.DownloadFile($DownloadUrl, $FilePath)
			Get-Item -Path $FilePath
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function New-AzureNanoServer
{
	<#
	.SYNOPSIS
		Comment-Synopsis
		
	.DESCRIPTION
		Effect on cmdlet behavior
		Content/format of valid parameter values
		[Optional] Default values
		[Optional] How to get parameter values
		[Optional] Interaction with other parameters
	
	http://www.aka.ms/nanoserver
	
	
	.EXAMPLE
		PS> function-name
	
		Comment-Example
		
	.PARAMETER ComputerName
		The name of the computer you'd like to run this function against.
	
	.PARAMETER Credential
		The PSCredential object to be used for authentication.  This is optional.
	
	.INPUTS
		None. You cannot pipe objects to function-name.
	
	.OUTPUTS
		output-type. function-name returns output-type-desc
		#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$AzureStorageContainer,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$AzureStorageAccount,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[securestring]$AdministratorPassword,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('\.iso$')]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[string]$WindowsServerImagePath
			
	)
	begin {
		$ErrorActionPreference = 'Stop'
		
		$storageAccount = Get-AzureStorageAccount -StorageAccountName $AzureStorageAccount -ErrorAction SilentlyContinue -ErrorVariable err
		if ($err.Exception.Message -like '*was not found*')
		{
			throw "The Azure storage account [$($AzureStorageAccount)] was not found."
		}
		if (-not ($storageAccount | Get-AzureStorageContainer | where { $_.Name -eq $AzureStorageContainer }))
		{
			throw "The Azure storage container [$($AzureStorageContainer)] was not found."	
		}
		
	}
	process {
		try
		{
			if (-not $PSBoundParameters.ContainsKey('WindowsServerImagePath')) {
				$downloadServer2016 = Read-Host -Prompt "The Windows Server 2016 ISO was not found at [$($ImagePath)]. Would you like to download it? (Y,N)"
				
				## Invoke the download function here
			}
			
			$winSrvImage = Mount-DiskImage -ImagePath $WindowsServerImagePath -PassThru
			$winSrvVolume = $winSrvImage | Get-Volume
			
			if (-not (Test-Path -Path "$($winSrvVolume.DriveLetter):\NanoServer\NanoServerImageGenerator.psm1" -PathType Leaf))
			{
				throw 'The required Nano Server Image Generator module was not found on the Windows server media.'
			}
			if (-not (Test-Path -Path "$($winSrvVolume.DriveLetter):\NanoServer\Convert-WindowsImage.ps1" -PathType Leaf))
			{
				throw 'The required PowerShell script [Convert-WindowsImage.ps1] was not found on the Windows server media.'
			}
			
			$params = @{
				'NanoServerImageGeneratorModuleFilePath' = "$($winSrvVolume.DriveLetter):\NanoServer\NanoServerImageGenerator.psm1"
				'MediaPath' = "$($winSrvVolume.DriveLetter):\"
				'TargetPath' = "$env:TEMP\NanoServer.vhd"
				'InstallGuestDrivers' = $true
				'ComputerName' = $ComputerName
				'AdministratorPassword' = $AdministratorPassword
			}
			
			$nanoServerVhd = New-NanoServerVhd @params
						
			## Sysprep the VHD??????

			$storageEndpoint = (Get-AzureStorageAccount -StorageAccountName $AzureStorageAccount).Endpoints[0].Trim('/')
			
			$container = Get-AzureStorageAccount -StorageAccountName $AzureStorageAccount | Get-AzureStorageContainer -Name $AzureStorageContainer
			
			$blobStorageUri = "$storageEndpoint/$($container.Name)/$($nanoServerVhd.Name)"
			Add-AzureVhd -LocalFilePath $nanoServerVhd.FullName -Destination $blobStorageUri
			
			Add-AzureVMImage -ImageName $($nanoServerVhd.Name) -MediaLocation $container.Name -OS 'Windows'

		}
		catch
		{
			Write-Error $_.Exception.Message
		}
		finally
		{
			$winSrvImage | Dismount-DiskImage
			Remove-Item -Path "$env:TEMP\NanoServer.vhd" -ErrorAction Ignore
		}
	}
}

function New-NanoServerVhd
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('\.psm1$')]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[string]$NanoServerImageGeneratorModuleFilePath,
	
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('\w{1}:\\$')]
		[ValidateScript({ Test-Path -Path $_ -PathType Container })]
		[string]$MediaPath,
	
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('\.vhd$')]
		[ValidateScript({ -not (Test-Path -Path $_ -PathType Leaf) })]
		[string]$TargetPath,
	
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[securestring]$AdministratorPassword,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[bool]$InstallGuestDrivers = $true
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			Import-Module -Name $NanoServerImageGeneratorModuleFilePath
			
			$params = @{
				'MediaPath' = $MediaPath
				'TargetPath' = $TargetPath
				'ComputerName' = $ComputerName
				'AdministratorPassword' = $AdministratorPassword
				'ForAzure' = $true
			}
			if ($InstallGuestDrivers)
			{
				$params.GuestDrivers = $true	
			}
			
			New-NanoServerImage @params
			
			Get-Item -Path $TargetPath
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}