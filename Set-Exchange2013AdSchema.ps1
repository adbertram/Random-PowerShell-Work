#Requires -Module ActiveDirectory

<#
.SYNOPSIS
	This script is designed to expedite the AD schema extension for Exchange 2013.  It is an automated way to not only
	perform the schema change itself but also to confirm success as well.  This script is intended to be run on a domain-joined
	workstation under an account that is both in the Schema Admins group and the Enterprise Admins group.

	It will require the Exhcange 2013 media (eval or licensed)
.NOTES
	Created on: 	8/22/2014
	Created by: 	Adam Bertram
	Filename:		Set-Exchange2013AdSchema.ps1			
.EXAMPLE
	
.EXAMPLE
	
.PARAMETER ExchangeMediaFolderPath
	The path to where the contents of the Exchange 2013 media is located.  This is typically the ISO extracted. 	

#>
[CmdletBinding()]
[OutputType([bool])]
param (
	[Parameter(Mandatory)]
	[ValidateScript({Test-Path $_ -PathType 'Container'})] 
	[string]$ExchangeMediaFolderPath
)

begin {
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	Set-StrictMode -Version Latest
	
	function Test-GroupMembership {
		$RequiredGroups = 'Schema Admins', 'Enterprise Admins'
		$Username = whoami
		$Username = $Username.Split('\')[1]
		$Groups = (Get-ADUser -Identity $Username -Properties Memberof).MemberOf | foreach { $_.Split(',')[0].TrimStart('CN=') }
		if (($Groups | where { $RequiredGroups -contains $_ }).Count -ne 2) {
			$false
		} else {
			$true
		}
	}
	
	function Get-InstalledSoftwareInRegistry {
	<#
	.SYNOPSIS
		Retrieves a list of all software installed	
	.DESCRIPTION
		Retrieves a list of all software installed via the specified method
	.EXAMPLE
		Get-InstalledSoftware
		This example retrieves all software installed on the local computer
	.PARAMETER Computername
		Use this parameter if you'd like to query installed software on a remote computer
	#>
		[CmdletBinding()]
		param (
			[string]$Computername = 'localhost'
		)
		process {
			try {
				$ScriptBlock = {
					$UninstallKeys = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
					New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS | Out-Null
					$UninstallKeys += Get-ChildItem HKU: | where { $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' } | foreach { "HKU:\$($_.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Uninstall" }
					foreach ($UninstallKey in $UninstallKeys) {
						$Keys = Get-ItemProperty -Path "$UninstallKey\*" -ErrorAction SilentlyContinue
						foreach ($Key in ($Keys | where { $_.SystemComponent -ne '1' })) {
							$Key
						}
					}
				}
				if ($Computername -ne 'localhost') {
					Invoke-Command -ComputerName $Computername -ScriptBlock $ScriptBlock
				} else {
					& $ScriptBlock
				}
			} catch {
				$_.Exception.Message
			}
		}
	}
}

process {
	try {
		## Ensure the account this is being run under is in the appropriate groups
		if (-not (Test-GroupMembership)) {
			throw "The user is not in the proper groups"	
		}
		
		## Ensure .NET 4.5 and at least PSv3 is installed on the schema master
		$SchemaMaster = (Get-ADForest).SchemaMaster
		
		## Disable replication on the schema master to prevent any potential problems from replicating out
		
		## Perform the schema extension
		
		## Verify the extension was successful by checking the log file
		
		## Verify the extension was successful by checking for the msExch attribute on the user
		
		## Reenable replication
		
		## Ensure replication is successful
	} catch {
		Write-Error "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
	}
}

end {
	try {
		
	} catch {
		Write-Error "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
	}
}