#Requires -Version 3
function Get-PSModulePath {
	<#
	.SYNOPSIS
		This gets the PSModulePath registry value
	.NOTES
		Created on: 	7/9/2014
		Created by: 	Adam Bertram
	.EXAMPLE
		Get-PSModulePath -FolderPath 'C:\Folder'
		This gets the PSModulePath registry value.
	#>
	[CmdletBinding()]
	param ()
	
	begin {
		Set-StrictMode -Version Latest
		try {
			
		} catch {
			Write-Error $_.Exception.Message
		}
	}
	
	process {
		try {
			$RegKey = 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment'
			(Get-ItemProperty -Path $RegKey -Name PSModulePath).PSModulePath
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Add-PSModulePath {
	<#
	.SYNOPSIS
		This adds a directory to the PSModulePath registry value and ensure it is unique.
	.NOTES
		Created on: 	7/9/2014
		Created by: 	Adam Bertram
	.EXAMPLE
		Add-PSModulePath -FolderPath 'C:\Folder'
		This example adds the folder 'C:\Folder' to the end of the PSModulePath registry value.
	.PARAMETER FolderPath
	 	The path to the folder you'd like to add.  Multiple paths allowed
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string[]]$FolderPath
	)
	
	begin {
		Set-StrictMode -Version Latest
		try {
			$RegKey = 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment'
			$Path = (Get-ItemProperty -Path $RegKey -Name PSModulePath).PSModulePath
		} catch {
			Write-Error $_.Exception.Message
		}
	}
	
	process {
		try {
			[System.Collections.ArrayList]$Array = $Path.Split(';')
			foreach ($i in $FolderPath) {
				$Array.Add($i) | Out-Null
			}
			Set-ItemProperty -Path $RegKey -Name PSModulePath -Value (($Array | Select-Object -Unique) -join ';')
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Remove-PSModulePath {
	<#
	.SYNOPSIS
		This removes a directory from the PSModulePath registry value
	.NOTES
		Created on: 	7/9/2014
		Created by: 	Adam Bertram
	.EXAMPLE
		Remove-PSModulePath -FolderPath 'C:\Folder'
		This example removes the folder 'C:\Folder' from the PSModulePath registry value.
	.PARAMETER FolderPath
	 	The path to the folder you'd like to remove. Multiple folders are allowed
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string[]]$FolderPath
	)
	
	begin {
		Set-StrictMode -Version Latest
		try {
			$RegKey = 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment'
			$Path = (Get-ItemProperty -Path $RegKey -Name PSModulePath).PSModulePath
			$FolderPath = $FolderPath.ToLower()
		} catch {
			Write-Error $_.Exception.Message
		}
	}
	
	process {
		try {
			[System.Collections.ArrayList]$Array = $Path.Split(';')
			$Array = $Array.ToLower()
			foreach ($i in $FolderPath) {
				if ($Array -contains $i) {
					$Array.Remove($i)
				}
			}
			Set-ItemProperty -Path $RegKey -Name PSModulePath -Value ($Array -join ';')
			
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}