#Requires -Version 3

<#
.SYNOPSIS
	This finds a local or remote computer(s)' local administrator account and changes it to a random password.
.DESCRIPTION
	This finds a local or remote computer(s)' local administrator account, generates a random password,  
	changes the local administrator password to that random password then records the password into an output file.
.NOTES
	Created on: 	7/19/2014
	Created by: 	Adam Bertram
	Filename:		Set-RandomPasswordToLocalUserAccount.ps1
	Credits:		http://support.microsoft.com/kb/2962486
	Todos:			Add multiple user support	
.EXAMPLE
	.\SetRandomPasswordToLocalUserAccount.ps1 -ComputerName 'COMPUTER1','COMPUTER2' -PasswordFilePath 'C:\passwords.txt'

	This sets the local administrator account's password on COMPUTER1 and COMPUTER2 to a randomly generated password
	and stores the history in a file called passwords.txt
.EXAMPLE
	.\SetRandomPasswordToLocalUserAccount.ps1 -ComputerName 'COMPUTER1','COMPUTER2' -PasswordFilePath 'C:\passwords.txt' -EncryptionKey 'key'

	This sets the local administrator account's password on COMPUTER1 and COMPUTER2 to a randomly generated password
	and stores encrypted passwords in a file called passwords.txt
.EXAMPLE
	.\SetRandomPasswordToLocalUserAccount.ps1 -ComputerName 'COMPUTER1','COMPUTER2' -PasswordFilePath 'C:\passwords.txt' -EncryptionKey 'key' -PasswordLength 100

	This sets the local administrator account's password on COMPUTER1 and COMPUTER2 to a randomly generated 100 character password
	and stores encrypted passwords in a file called passwords.txt
.PARAMETER Computername
 	One or more computer names you'd like to change the local administrator password on. If no computer name is selected
	then change the local administrator password on the local computer.
.PARAMETER PasswordLength
	The length of the password the new local adminsitrator password will be
.PARAMETER PasswordFilePath
	The file path to the output file where your passwords are stored
.PARAMETER EncryptionKey
	The encryption key you'd like applied to all password strings being being written to the password file
.PARAMETER
	If the administrator account is disabled, use this parameter to enable it.  If this param is not used and the administrator
	account is disabled, it will be skipped.
#>
[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline,
				   ValueFromPipelineByPropertyName)]
		[ValidateScript({ Test-Connection $_ -Quiet -Count 1 })]
		[string[]]$Computername = 'localhost',
		[Parameter()]
		[ValidateRange(20, 120)]
		[int]$PasswordLength = 50,
		[Parameter(Mandatory)]
		[string]$PasswordFilePath,
		[Parameter()]
		[string]$EncryptionKey,
		[Parameter()]
		[switch]$EnableAccount
	)

begin {
	function Create-RandomPassword {
		<#
			.NOTES
			Author: Microsoft
		#>
		Param (
			[Parameter(Mandatory = $true)]
			[ValidateRange(20, 120)]
			[Int]$PasswordLength
		)
		
		$Password = [System.Web.Security.Membership]::GeneratePassword($PasswordLength, $PasswordLength / 4)
		
		#This should never fail, but I'm putting a sanity check here anyways
		if ($Password.Length -ne $PasswordLength) {
			throw new Exception("Password returned by GeneratePassword is not the same length as required. Required length: $($PasswordLength). Generated length: $($Password.Length)")
		}
		
		return $Password
	}
	
	function Set-Encryption ($UnencryptedPassword, $EncryptionKey) {
		try {
			$PasswordSecureString = ConvertTo-SecureString -AsPlainText -Force -String $UnencryptedPassword
			
			$Sha256 = new-object System.Security.Cryptography.SHA256CryptoServiceProvider
			$SecureString = $Sha256.ComputeHash([System.Text.UnicodeEncoding]::Unicode.GetBytes($EncryptionKey))
			
			ConvertFrom-SecureString -Key $SecureString -SecureString $PasswordSecureString
		} catch {
			Write-Error "Error creating encryption key" -ErrorAction Stop
			$_.Exception.Message
		}
	}
	
	function ConvertTo-CleartextPassword {
		<#
		.SYNOPSIS
			This function can be used to decrypt passwords that were stored encrypted by the function Invoke-PasswordRoll.
		.NOTES
			Author: Microsoft
			Version: 1.0
		.DESCRIPTION
			This function can be used to decrypt passwords that were stored encrypted by the function Invoke-PasswordRoll.
		.PARAMETER EncryptedPassword
			The encrypted password that was stored in a TSV file.
		.PARAMETER EncryptionKey
			The password used to do the encryption.
		.EXAMPLE
			. .\Invoke-PasswordRoll.ps1    #Loads the functions in this script file
			ConvertTo-CleartextPassword -EncryptionKey "Password1" -EncryptedPassword 76492d1116743f0423413b16050a5345MgB8AGcAZgBaAHUAaQBwADAAQgB2AGgAcABNADMASwBaAFoAQQBzADEAeABjAEEAPQA9AHwAZgBiAGYAMAA1ADYANgA2ADEANwBkADQAZgAwADMANABjAGUAZQAxAGIAMABiADkANgBiADkAMAA4ADcANwBhADMAYQA3AGYAOABkADcAMQA5ADQAMwBmAGYANQBhADEAYQBjADcANABkADIANgBhADUANwBlADgAMAAyADQANgA1ADIAOQA0AGMAZQA0ADEAMwAzADcANQAyADUANAAzADYAMAA1AGEANgAzADEAMQA5ADAAYwBmADQAZAA2AGQA"

			Decrypts the encrypted password which was stored in the TSV file.
		#>
		Param (
			[Parameter(Mandatory)]
			[String]$EncryptedPassword,
			
			[Parameter(Mandatory)]
			[String]$EncryptionKey
		)
		
		$Sha256 = new-object System.Security.Cryptography.SHA256CryptoServiceProvider
		$SecureStringKey = $Sha256.ComputeHash([System.Text.UnicodeEncoding]::Unicode.GetBytes($EncryptionKey))
		
		[SecureString]$SecureStringPassword = ConvertTo-SecureString -String $EncryptedPassword -Key $SecureStringKey
		Write-Output ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($SecureStringPassword)))
	}
	
	## The System.Web is not a default assembly.  This must be loaded in order to generate the random password
	Add-Type -AssemblyName "System.Web" -ErrorAction Stop
}

process {
	foreach ($Computer in $Computername) {
		try {
			$Properties = @{
				ComputerName = $Computer
				Username = ''
				Password = ''
				PasswordType = ''
				Result = ''
				EnabledAccount = ''
			}
			if (!(Test-Connection -ComputerName $Computer -Quiet -Count 1)) {
				Write-Warning "Computer '$Computer' is not online"
				$Properties.Result = 'Offline'
				[pscustomobject]$Properties | Export-Csv -Path $PasswordFilePath -Delimiter "`t" -Append -NoTypeInformation
			} else {
				$LocalUsers = Get-WmiObject -ComputerName $Computer -Class Win32_UserAccount -Filter "LocalAccount=true"
				Write-Verbose "Found $($LocalUsers.Count) local users on $Computer"
				foreach ($LocalUser in $LocalUsers) {
					Write-Verbose "--Checking username $($LocalUser.Name) for administrator account"
					$oUser = [ADSI]"WinNT://$Computer/$($LocalUser.Name), user"
					$Sid = $oUser.objectSid.ToString().Replace(' ', '')
					if ($Sid.StartsWith('1500000521') -and $Sid.EndsWith('4100')) {
						Write-Verbose "--Username $($LocalUser.Name)|SID '$Sid' is the local administrator account"
						$LocalAdministrator = $LocalUser
						break
					}
				}
				
				$Properties.UserName = $LocalAdministrator.Name
				Write-Verbose "Creating random password for $($LocalAdministrator.Name)"
				$Password = Create-RandomPassword -PasswordLength $PasswordLength
				if ($EncryptionKey) {
					$Properties.PasswordType = 'Encrypted'
					$Properties.Password = (Set-Encryption $Password $EncryptionKey)
				} else {
					$Properties.Password = $Password
					$Properties.PasswordType = 'Unencrypted'
				}
					
				$oUser.psbase.Invoke("SetPassword", $Password)
				$Properties.Result = 'Success'
				
				
				Write-Verbose "Checking to ensure local administrator '$($LocalAdministrator.Name)' is enabled"
				if ($LocalAdministrator.Disabled) {
					Write-Verbose "Local administrator '$($LocalAdministrator.Name)' is disabled.  Enabling..."
					$Properties.EnabledAccount = 'True'
					$LocalAdministrator.Disabled = $false
					$LocalAdministrator.Put() | Out-Null
				} else {
					$Properties.EnabledAccount = 'False'
					Write-Verbose "Local administrator '$($LocalAdministrator.Name)' is already enabled."
				}
				
				[pscustomobject]$Properties | Export-Csv -Path $PasswordFilePath -Delimiter "`t" -Append -NoTypeInformation
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}