function Get-Shortcut {
	<#
	.SYNOPSIS
		This function searches for files matching a LNK and URL extension.
	.DESCRIPTION
		This function, by default, recursively searches for files matching a LNK and URL extensions containing
		a specific string inside the target path, name or both. If no folder path specified, it will 
		recursively search all user profiles and the all users profile.
	.NOTES
		Created on: 	6/23/2014
		Created by: 	Adam Bertram
	.EXAMPLE
		Get-Shortcut -TargetPath 'http:\\servername\local'
		This example would find all shortcuts (URL and LNK) in all user profiles that have a 
		target path that match 'http:\\servername\local'
	.EXAMPLE
		Get-Shortcut -TargetPath 'http:\\servername\local' -Name 'name'
		This example would find all shortcuts (URL and LNK) in all user profiles that have a 
		target path that match 'http:\\servername\local' and have a name containing the string "name"
	.EXAMPLE
		Get-Shortcut -TargetPath 'http:\\servername\local' -FilePath 'C:\Users\abertram\Desktop'
		This example would find all shortcuts (URL and LNK) in the 'C:\Users\abertram\Desktop file path 
		that have a target path that match 'http:\\servername\local' and have a name containing the 
		string "name"
	.PARAMETER TargetPath
		The string you'd like to search for inside the shortcut's target path
	.PARAMETER Name
		A string you'd like to search for inside of the shortcut's name
	.PARAMETER FilePath
		A string you'd like to search for inside of the shortcut's file path
	.PARAMETER FolderPath
		The folder path to search for shortcuts in.  You can specify multiple folder paths. This defaults to 
		the user profile root and the all users profile
	.PARAMETER NoRecurse
		This turns off recursion on the folder path specified searching subfolders of the FolderPath
	#>
	[CmdletBinding()]
	param (
		[string]$TargetPath,
		[string]$Name,
		[string]$FilePath,
		[string[]]$FolderPath,
		[switch]$NoRecurse
	)
	begin {
		function Get-RootUserProfileFolderPath {
			<#
			.SYNOPSIS
				Because sometimes the root user profile folder path can be different this function is a placeholder to find
				the root user profile folder path ie. C:\Users or C:\Documents and Settings for any OS.  It queries a registry value
				to find this path.
			#>
			[CmdletBinding()]
			param ()
			process {
				try {
					(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' -Name ProfilesDirectory).ProfilesDirectory
				} catch {
					Write-Log -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" -LogLevel '3'
					$false
				}
			}
		}
		function Get-AllUsersProfileFolderPath {
			<#
			.SYNOPSIS
				Because sometimes the all users profile folder path can be different this function is a placeholder to find
				the all users profile folder path ie. C:\ProgramData or C:\Users\All Users. It uses an environment variable
				to find this path.
			#>
			[CmdletBinding()]
			param ()
			process {
				try {
					$env:ALLUSERSPROFILE
				} catch {
					Write-Log -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" -LogLevel '3'
					$false
				}
			}
		}
	}
	process {
		try {
			if (!$FolderPath) {
				$FolderPath = (Get-RootUserProfileFolderPath), (Get-AllUsersProfileFolderPath)
			}
			
			$Params = @{
				'Include' = @('*.url', '*.lnk');
				'ErrorAction' = 'SilentlyContinue';
				'ErrorVariable' = 'MyError';
				'Force' = $true
			}
			
			if (!$NoRecurse) {
				$Params['Recurse'] = $true
			}
			
			$ShellObject = New-Object -ComObject Wscript.Shell
			[System.Collections.ArrayList]$Shortcuts = @()
			
			foreach ($Path in $FolderPath) {
				try {
					Write-Verbose -Message "Searching for shortcuts in $Path..."
					[System.Collections.ArrayList]$WhereConditions = @()
					$Params['Path'] = $Path
					if ($TargetPath) {
						$WhereConditions.Add('(($ShellObject.CreateShortcut($_.FullName)).TargetPath -like "*$TargetPath*")') | Out-Null
					}
					if ($Name) {
						$WhereConditions.Add('($_.Name -like "*$Name*")') | Out-Null
					}
					if ($FilePath) {
						$WhereConditions.Add('($_.FullName -like "*$FilePath*")') | Out-Null
					}
					if ($WhereConditions.Count -gt 0) {
						$WhereBlock = [scriptblock]::Create($WhereConditions -join ' -and ')
						Get-ChildItem @Params | where $WhereBlock
					} else {
						Get-ChildItem @Params
					}
					if ($NewShortcuts) {
						$Shortcuts.Add($NewShortcuts) | Out-Null
					}
				} catch {
					Write-Error -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
					$false
				}
			}
		} catch {
			Write-Error -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
			$false
		}
	}
}

function Set-Shortcut {
	<#
	.SYNOPSIS
		This function modifies a LNK or URL extension shortcut.
	.EXAMPLE
		PS> Get-Shortcut -TargetPath 'http:\\servername\local' | Set-Shortcut -TargetPath 'http:\\newserver\local'
		
		This example would find all shortcuts (URL and LNK) in all user profiles that have a 
		target path that match 'http:\\servername\local' and change that target path to 
		'http:\\newserver\local'
	.PARAMETER FilePath
		One or more file paths to the shortcut file
	.PARAMETER TargetPath
		The target path you'd like to set in the shortcut
	.PARAMETER Comment
		The description of the shortcut you'd like to change to
	#>
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	param (
		[Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[Alias('Fullname')]
		[string[]]$FilePath,
		[Parameter(Mandatory,ParameterSetName = 'TargetPath')]
		[string]$TargetPath,
		[Parameter(Mandatory, ParameterSetName = 'Comment')]
		[string]$Comment
	)
	process {
		try {
			$ShellObject = New-Object -ComObject Wscript.Shell
			foreach ($File in $FilePath) {
				try {
					$Shortcut = $ShellObject.CreateShortcut($File)
					if ($TargetPath) {
						$Shortcut.TargetPath = $TargetPath
					}
					if ($Comment) {
						$Shortcut.Description = $Comment
					}
					$Shortcut.Save()
				} catch {
					Write-Error -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
				}
			}
		} catch {
			Write-Error -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
		}
	}
}