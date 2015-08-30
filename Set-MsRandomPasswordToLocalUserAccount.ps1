function Invoke-PasswordRoll {
	<#
	.SYNOPSIS

	This script can be used to set the local account passwords on remote machines to random passwords. The username/password/server combination will be saved in a CSV file.
	The account passwords stored in the CSV file can be encrypted using a password of the administrators choosing to ensure clear-text account passwords aren't written to disk.
	The encrypted passwords can be decrypted using another function in this file: ConvertTo-CleartextPassword


	Function: Invoke-PasswordRoll
	Author: Microsoft
	Version: 1.0

	.DESCRIPTION

	This script can be used to set the local account passwords on remote machines to random passwords. The username/password/server combination will be saved in a CSV file.
	The account passwords stored in the CSV file can be encrypted using a password of the administrators choosing to ensure clear-text account passwords aren't written to disk.
	The encrypted passwords can be decrypted using another function in this file: ConvertTo-CleartextPassword

	.PARAMETER ComputerName

	An array of computers to run the script against using PowerShell remoting.

	.PARAMETER LocalAccounts

	An array of local accounts whose password should be changed.

	.PARAMETER TsvFileName

	The file to output the username/password/server combinations to.

	.PARAMETER EncryptionKey

	A password to encrypt the TSV file with. Uses AES encryption. Only the passwords stored in the TSV file will be encrypted, the username and servername will be clear-text.

	.PARAMETER PasswordLength

	The length of the passwords which will be randomly generated for local accounts.

	.PARAMETER NoEncryption

	Do not encrypt the account passwords stored in the TSV file. This will result in clear-text passwords being written to disk.
		
	.EXAMPLE

	. .\Invoke-PasswordRoll.ps1    #Loads the functions in this script file
	Invoke-PasswordRoll -ComputerName (Get-Content computerlist.txt) -LocalAccounts @("administrator","CustomLocalAdmin") -TsvFileName "LocalAdminCredentials.tsv" -EncryptionKey "Password1"

	Connects to all the computers stored in the file "computerlist.txt". If the local account "administrator" and/or "CustomLocalAdmin" are present on the system, their password is changed
	to a randomly generated password of length 20 (the default). The username/password/server combinations are stored in LocalAdminCredentials.tsv, and the account passwords are AES encrypted using the password "Password1".

	.EXAMPLE

	. .\Invoke-PasswordRoll.ps1    #Loads the functions in this script file
	Invoke-PasswordRoll -ComputerName (Get-Content computerlist.txt) -LocalAccounts @("administrator") -TsvFileName "LocalAdminCredentials.tsv" -NoEncryption -PasswordLength 40

	Connects to all the computers stored in the file "computerlist.txt". If the local account "administrator" is present on the system, its password is changed to a random generated
	password of length 40. The username/password/server combinations are stored in LocalAdminCredentials.tsv unencrypted.

	.NOTES
	Requirements: 
	-PowerShellv2 or above must be installed
	-PowerShell remoting must be enabled on all systems the script will be run against

	Script behavior:
	-If a local account is present on the system, but not specified in the LocalAccounts parameter, the script will write a warning to the screen to alert you to the presence of this local account. The script will continue running when this happens.
	-If a local account is specified in the LocalAccounts parameter, but the account does not exist on the computer, nothing will happen (an account will NOT be created).
	-The function ConvertTo-CleartextPassword, contained in this file, can be used to decrypt passwords that are stored encrypted in the TSV file.
	-If a server specified in ComputerName cannot be connected to, PowerShell will output an error message.
	-Microsoft advises companies to regularly roll all local and domain account passwords.

	#>
	[CmdletBinding(DefaultParameterSetName = "Encryption")]
	Param (
		[Parameter(Mandatory = $true)]
		[String[]]
		$ComputerName,
		
		[Parameter(Mandatory = $true)]
		[String[]]
		$LocalAccounts,
		
		[Parameter(Mandatory = $true)]
		[String]
		$TsvFileName,
		
		[Parameter(ParameterSetName = "Encryption", Mandatory = $true)]
		[String]
		$EncryptionKey,
		
		[Parameter()]
		[ValidateRange(20, 120)]
		[Int]
		$PasswordLength = 20,
		
		[Parameter(ParameterSetName = "NoEncryption", Mandatory = $true)]
		[Switch]
		$NoEncryption
	)
	
	
	#Load any needed .net classes
	Add-Type -AssemblyName "System.Web" -ErrorAction Stop
	
	
	#This is the scriptblock that will be executed on every computer specified in ComputerName
	$RemoteRollScript = {
		Param (
			[Parameter(Mandatory = $true, Position = 1)]
			[String[]]
			$Passwords,
			
			[Parameter(Mandatory = $true, Position = 2)]
			[String[]]
			$LocalAccounts,
			
			#This is here so I can record what the server name that the script connected to was, sometimes the DNS records get messed up, it can be nice to have this.
			[Parameter(Mandatory = $true, Position = 3)]
			[String]
			$TargettedServerName
		)
		
		$LocalUsers = Get-WmiObject Win32_UserAccount -Filter "LocalAccount=true" | Foreach { $_.Name }
		
		#Check if the computer has any local user accounts whose passwords are not going to be rolled by this script
		foreach ($User in $LocalUsers) {
			if ($LocalAccounts -inotcontains $User) {
				Write-Warning "Server: '$($TargettedServerName)' has a local account '$($User)' whos password is NOT being changed by this script"
			}
		}
		
		#For every local account specified that exists on this server, change the password
		$PasswordIndex = 0
		foreach ($LocalAdmin in $LocalAccounts) {
			$Password = $Passwords[$PasswordIndex]
			
			if ($LocalUsers -icontains $LocalAdmin) {
				try {
					$objUser = [ADSI]"WinNT://localhost/$($LocalAdmin), user"
					$objUser.psbase.Invoke("SetPassword", $Password)
					
					$Properties = @{
						TargettedServerName = $TargettedServerName
						Username = $LocalAdmin
						Password = $Password
						RealServerName = $env:computername
					}
					
					$ReturnData = New-Object PSObject -Property $Properties
					Write-Output $ReturnData
				} catch {
					Write-Error "Error changing password for user:$($LocalAdmin) on server:$($TargettedServerName)"
				}
			}
			
			$PasswordIndex++
		}
	}
	
	
	#Generate the password on the client running this script, not on the remote machine. System.Web.Security isn't available in the .NET Client profile. Making this call
	#    on the client running the script ensures only 1 computer needs the full .NET runtime installed (as opposed to every system having the password rolled).
	function Create-RandomPassword {
		Param (
			[Parameter(Mandatory = $true)]
			[ValidateRange(20, 120)]
			[Int]
			$PasswordLength
		)
		
		$Password = [System.Web.Security.Membership]::GeneratePassword($PasswordLength, $PasswordLength / 4)
		
		#This should never fail, but I'm putting a sanity check here anyways
		if ($Password.Length -ne $PasswordLength) {
			throw new Exception("Password returned by GeneratePassword is not the same length as required. Required length: $($PasswordLength). Generated length: $($Password.Length)")
		}
		
		return $Password
	}
	
	
	#Main functionality - Generate a password and remote in to machines to change the password of local accounts specified
	if ($PsCmdlet.ParameterSetName -ieq "Encryption") {
		try {
			$Sha256 = new-object System.Security.Cryptography.SHA256CryptoServiceProvider
			$SecureStringKey = $Sha256.ComputeHash([System.Text.UnicodeEncoding]::Unicode.GetBytes($EncryptionKey))
		} catch {
			Write-Error "Error creating TSV encryption key" -ErrorAction Stop
		}
	}
	
	foreach ($Computer in $ComputerName) {
		#Need to generate 1 password for each account that could be changed
		$Passwords = @()
		for ($i = 0; $i -lt $LocalAccounts.Length; $i++) {
			$Passwords += Create-RandomPassword -PasswordLength $PasswordLength
		}
		
		Write-Output "Connecting to server '$($Computer)' to roll specified local admin passwords"
		$Result = Invoke-Command -ScriptBlock $RemoteRollScript -ArgumentList @($Passwords, $LocalAccounts, $Computer) -ComputerName $Computer
		#If encryption is being used, encrypt the password with the user supplied key prior to writing to disk
		if ($Result -ne $null) {
			if ($PsCmdlet.ParameterSetName -ieq "NoEncryption") {
				$Result | Select-Object Username, Password, TargettedServerName, RealServerName | Export-Csv -Append -Path $TsvFileName -NoTypeInformation
			} else {
				#Filters out $null entries returned
				$Result = $Result | Select-Object Username, Password, TargettedServerName, RealServerName
				
				foreach ($Record in $Result) {
					$PasswordSecureString = ConvertTo-SecureString -AsPlainText -Force -String ($Record.Password)
					$Record | Add-Member -MemberType NoteProperty -Name EncryptedPassword -Value (ConvertFrom-SecureString -Key $SecureStringKey -SecureString $PasswordSecureString)
					$Record.PSObject.Properties.Remove("Password")
					$Record | Select-Object Username, EncryptedPassword, TargettedServerName, RealServerName | Export-Csv -Append -Path $TsvFileName -NoTypeInformation
				}
			}
		}
	}
}

function ConvertTo-CleartextPassword {
	<#
	.SYNOPSIS
	This function can be used to decrypt passwords that were stored encrypted by the function Invoke-PasswordRoll.

	Function: ConvertTo-CleartextPassword
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
		[Parameter(Mandatory = $true)]
		[String]
		$EncryptedPassword,
		
		[Parameter(Mandatory = $true)]
		[String]
		$EncryptionKey
	)
	
	$Sha256 = new-object System.Security.Cryptography.SHA256CryptoServiceProvider
	$SecureStringKey = $Sha256.ComputeHash([System.Text.UnicodeEncoding]::Unicode.GetBytes($EncryptionKey))
	
	[SecureString]$SecureStringPassword = ConvertTo-SecureString -String $EncryptedPassword -Key $SecureStringKey
	Write-Output ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($SecureStringPassword)))
}

Invoke-PasswordRoll -ComputerName a-w7x86-1 -LocalAccounts 'aidet' -NoEncryption -TsvFileName 'file.tsv'