<#
	.SYNOPSIS
		This function downloads remote a remote SFTP server.

	.PARAMETER Server
		 A mandatory string parameter representing an IP address or hostname of the SSH server.

	.PARAMETER LocalFolderPath
		 A mandatory string parameter representing the local folder path to download the file into.

	.PARAMETER RemoteFilePath
		 A mandatory string parameter representing the path to the remote file inside of the session home folder.

	.PARAMETER Credentrial
		An mandatory pscredential parameter representing the username and password to use to connet to the SSH server.

	.PARAMETER Force
		 By default, the script will not overwrite any local files. Use this switch parameter to override that.

	.EXAMPLE
		PS> .\Get-FileViaSftp.ps1 -Server 192.168.0.2 -LocalFolderPath C:\ -RemoteFilePath file.txt -Credential (Get-Credential)

		This example will connect to the SSH server at 192.168.0.2 and download the file.txt in the root of the session home folder
		to the root of C on the local computer using the username/password inside of a credential.

#>
[OutputType([void])]
[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$Server,

	[Parameter(Mandatory)]
	[ValidateScript({ 
		if (-not (Test-Path -Path $_ -PathType Container)) {
			throw "The destination folder '$_' could not be found."
		} else {
			$true
		}
	})]
	[ValidateNotNullOrEmpty()]
	[string]$LocalFolderPath,

	[Parameter(Mandatory)]
	[ValidateScript({
		if ($_ -match '^\w:') {
			throw "DestinationPath is not valid. Use a relative path to the SFTP session. Do not start the path with 'C:\', for example."
		} else {
			$true
		}
	})]

	[ValidateNotNullOrEmpty()]
	[string]$RemoteFilePath,

	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[pscredential]$Credential,

	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[switch]$Force
)

try {

	# Ensure all of the required are present. If not, download from the PowerShell Gallery
	Write-Verbose -Message 'Checking for required modules...'
	$requiredModules = 'Posh-SSH'
	if (-not (Get-Module -Name $requiredModules -ListAvailable)) {
		Write-Verbose -Message "Installing required modules [$($requiredModules)]..."
		Install-module $requiredModules -Force -Confirm:$false
	}

	# Establish the SFTP connection
	Write-Verbose -Message "Creating SFTP session to [$($Server)] using username [$($Credential.username)]..."
	$session = New-SFTPSession -ComputerName $Server -Credential $Credential -AcceptKey

	# Download the file
	$getParams = @{
		SessionId = $session.SessionId
		LocalPath = $LocalFolderPath
		RemoteFile = $RemoteFilePath
	}
	if ($Force.IsPresent) {
		$getParams.Overwrite = $true
	}
	Get-SFTPFile @getParams

}
catch {
	Write-Host $_.Exception.Message -ForegroundColor Red	
} finally {
	if (Test-Path -Path variable:\session) {
		Write-Verbose -Message 'Disconnecting SFTP session...'
		if ($session = Get-SFTPSession -SessionId $session.SessionId) {
			$session.Disconnect()
		}
		Write-Verbose -Message 'Removing SFTP session...'
		$null = Remove-SftpSession -SftpSession $session
	}
}