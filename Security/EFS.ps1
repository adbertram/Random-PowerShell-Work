#requires -Version 4 -RunAsAdministrator

function Enable-FileEncryption
{
	<#
	.SYNOPSIS
		This function enables EFS file encryption on a file.
	
	.EXAMPLE
		PS> Get-Item -Path 'C:\File.txt' | Enable-FileEncryption
	
		This example finds the C:\File.txt with Get-Item, passes it through the pipeline to Enable-FileEncryption which will
		then EFS encrypt the file.
	
	.EXAMPLE
		PS> Get-ChildItem -Path 'C:\Folder' | Enable-FileEncryption
	
		This example will encrypt every folder in C:\Folder.
		
	.PARAMETER File
		A System.IO.FileInfo object that will be encrypted.
	#>
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory,ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[System.IO.FileInfo]$File
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			$File.Encrypt()	
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function Disable-FileEncryption
{
	<#
	.SYNOPSIS
		This function disables EFS file encryption on a file.
	
	.EXAMPLE
		PS> Get-Item -Path 'C:\File.txt' | Disable-FileEncryption
	
		This example finds the C:\File.txt with Get-Item, passes it through the pipeline to Disable-FileEncryption which will
		then EFS decrypt the file.
	
	.EXAMPLE
		PS> Get-ChildItem -Path 'C:\Folder' | Disable-FileEncryption
	
		This example will decrypt every folder in C:\Folder.
		
	.PARAMETER File
		A System.IO.FileInfo object that will be decrypted.
	#>
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[System.IO.FileInfo]$File
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			$File.Decrypt()		
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}