function Deploy-Vnc
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1 })]
		[string]$ComputerName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path $_ -PathType Container })]
		[string]$InstallerFolder = '\\MEMBERSRV1\ToolShare'
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			## Ensure the C$ share is available
			if (-not (Test-Path -Path "\\$ComputerName\c$"))
			{
				throw "The c`$ share is not available on computer [$($ComputerName)]"
			}
			else
			{
				Write-Verbose -Message "c$ share is available on [$($ComputerName)]"
			}
			
			$installFolderName = $InstallerFolder.Split('\')[-1]
			
			## Check if our installer and INF is already on the remote computer
			if (Test-Path -Path "\\$ComputerName\c$\$installFolderName")
			{
				Write-Verbose -Message "VNC install folder already exists at \\$ComputerName\c$\$installFolderName"
				
				## Generate file hashes for all files within the remote VNC install folder and the files on the remote client.
				$sourceHashes = Get-ChildItem -Path $InstallerFolder | foreach { (Get-FileHash -Path $_.FullName).Hash }
				$destHashes = Get-ChildItem -Path "\\$ComputerName\c$\$installFolderName" | foreach { (Get-FileHash -Path $_.FullName).Hash }
				if (Compare-Object -ReferenceObject $sourceHashes -DifferenceObject $destHashes)
				{
					Write-Verbose -Message 'Remote computer VNC installer contents does not match source. Overwriting...'
					## Copy the VNC installer folder to the remote computer
					Copy-Item -Path $InstallerFolder -Destination "\\$ComputerName\c$" -Recurse
				}
				else
				{
					Write-Verbose -Message 'Remote computer VNC installer contents already exist. No need to copy again.'
				}
			}
			else
			{
				## Copy the VNC installer folder to the remote computer
				Write-Verbose -Message "Copying VNC installer contents to [$($ComputerName)]"
				Copy-Item -Path $InstallerFolder -Destination "\\$ComputerName\c$" -Recurse
			}
			
			## Remotely invoke the VNC installer on the computer
			$localInstallFolder = "C:\$installFolderName".TrimEnd('\')
			$localInstaller = "$localInstallFolder\UltraVNC_Setup.exe"
			$localInfFile = "$localInstallFolder\UltraVNCSilentInstall.inf"
			
			$scriptBlock = {
				Start-Process $using:localInstaller -Args "/verysilent /loadinf=`"$using:localInfFile`"" -Wait -NoNewWindow
			}
			Write-Verbose -Message 'Running VNC installer...'
			Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
		finally
		{
			$remoteInstallFolder = "\\$ComputerName\c$\$installFolderName"
			Write-Verbose -Message "Cleaning up VNC install bits at [$($remoteInstallFolder)]"
			Remove-Item $remoteInstallFolder -Recurse -ErrorAction Ignore
		}
	}
}