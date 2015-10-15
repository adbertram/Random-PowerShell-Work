function Send-File
{
	<#
	.SYNOPSIS
		Sends a file to a remote session.

	.EXAMPLE
		$session = New-PsSession leeholmes1c23
		Send-File c:\temp\test.exe c:\temp\test.exe $session
	#>
	
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Path,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Destination,
		
		[Parameter(Mandatory)]
		[System.Management.Automation.Runspaces.PSSession]$Session
	)
	begin
	{
		function Test-UncPath
		{
			[CmdletBinding()]
			[OutputType([bool])]
			param
			(
				[Parameter(Mandatory)]
				[ValidateNotNullOrEmpty()]
				[string]$Path
				
			)
			process
			{
				if ($Path -like '\\*')
				{
					$true
				}
				else
				{
					$false
				}
			}
		}
	}
	process
	{
		foreach ($p in $Path)
		{
			try
			{
				if (Test-UncPath -Path $p)
				{
					Write-Verbose -Message "[$($p)] is a UNC path. Copying locally first"
					Copy-Item -Path $p -Destination ([environment]::GetEnvironmentVariable('TEMP', 'Machine')) -Force -Recurse
					$p = "$([environment]::GetEnvironmentVariable('TEMP', 'Machine'))\$($p | Split-Path -Leaf)"
				}
				if (Test-Path -Path $p -PathType Container)
				{
					Write-Verbose -Message "[$($p)] is a folder. Sending all files"
					$files = Get-ChildItem -Path $p -File -Recurse
					$sendFileParamColl = @()
					foreach ($file in $Files)
					{
						$sendParams = @{
							'Session' = $Session
							'Path' = $file.FullName
						}
						if ($file.DirectoryName -ne $p) ## It's a subdirectory
						{
							$subdirpath = $file.DirectoryName.Replace("$p\", '')
							$sendParams.Destination = "$Destination\$subDirPath"
						}
						else
						{
							$sendParams.Destination = $Destination
						}
						$sendFileParamColl += $sendParams
					}
					foreach ($paramBlock in $sendFileParamColl)
					{
						Send-File @paramBlock
					}
				}
				else
				{
					Write-Verbose -Message "Starting WinRM copy of [$($p)] to [$($Destination)]"
					# Get the source file, and then get its contents
					$sourceBytes = [System.IO.File]::ReadAllBytes($p);
					$streamChunks = @();
					
					# Now break it into chunks to stream.
					$streamSize = 1MB;
					for ($position = 0; $position -lt $sourceBytes.Length; $position += $streamSize)
					{
						$remaining = $sourceBytes.Length - $position
						$remaining = [Math]::Min($remaining, $streamSize)
						
						$nextChunk = New-Object byte[] $remaining
						[Array]::Copy($sourcebytes, $position, $nextChunk, 0, $remaining)
						$streamChunks +=, $nextChunk
					}
					$remoteScript = {
						if (-not (Test-Path -Path $using:Destination -PathType Container))
						{
							$null = New-Item -Path $using:Destination -Type Directory -Force
						}
						$fileDest = "$using:Destination\$($using:p | Split-Path -Leaf)"
						## Create a new array to hold the file content
						$destBytes = New-Object byte[] $using:length
						$position = 0
						
						## Go through the input, and fill in the new array of file content
						foreach ($chunk in $input)
						{
							[GC]::Collect()
							[Array]::Copy($chunk, 0, $destBytes, $position, $chunk.Length)
							$position += $chunk.Length
						}
						
						[IO.File]::WriteAllBytes($fileDest, $destBytes)
						
						Get-Item $fileDest
						[GC]::Collect()
					}
					
					# Stream the chunks into the remote script.
					$Length = $sourceBytes.Length
					$streamChunks | Invoke-Command -Session $Session -ScriptBlock $remoteScript
					Write-Verbose -Message "WinRM copy of [$($p)] to [$($Destination)] complete"
				}
			}
			catch
			{
				throw $_
			}
		}
	}
	
}

function Test-LocalComputer
{
	<#	
			.SYNOPSIS
			This script detects if the a label indicates the local computer or not. A designation for local computer
			could be a number of labels such as ".", "localhost", the netbios name of the local computer or the FQDN
			of the local computer.  This function returns true if any of those labels match the local computer or false
			if it indicates a remote computer.

	.PARAMETER Label
		The label that's being tested if it represents the local machine or not.

			.EXAMPLE
			PS> Test-LocalComputer -Label localhost

			This example will return [bool]$true because localhost is an indicator of the local machine.

			.EXAMPLE
			PS> Test-LocalComputer -Label PC02
	
			This example will return [bool]$true if the NetBIOS name of the local computer is PC02. If not, it will return
			[bool]$false.

	.NOTES
		Created on: 	5/27/15
		Created by: 	Adam Bertram
	#>
	
	[CmdletBinding()]
	[OutputType([bool])]
	param
	(
		[Parameter(Mandatory)]
		[string]$ComputerName
	)
	begin
	{
		$LocalComputerLabels = @(
		'.',
		'localhost',
		[System.Net.Dns]::GetHostName(),
		[System.Net.Dns]::GetHostEntry('').HostName
		)
	}
	process
	{
		try
		{
			if ($LocalComputerLabels -contains $ComputerName)
			{
				Write-Verbose -Message "The computer reference [$($ComputerName)] is a local computer"
				$true
			}
			else
			{
				Write-Verbose -Message "The computer reference [$($ComputerName)] is a remote computer"
				$false
			}
		}
		catch
		{
			throw $_
		}
	}
}

function Import-CertificateSigningRequestResponse
{
	<#
	.SYNOPSIS
		This function imports a certificate response to a certificate signing request.
	
	.DESCRIPTION
		By specifying a path to a certificate (.CER file), this function can then import that response into a certificate store.
		It's primary use is for IIS certificates. This function will be used after generating the CSR with the New-CertificateSigningRequest
		function and certificate generated by a CA.
	.EXAMPLE
		
		local computer
	.EXAMPLE
		
	
	.PARAMETER FilePath
		This is the path to the certificate file that you'd like to import
	#>
	[CmdletBinding()]
	param
	(
		
		[Parameter(Mandatory)]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[string]$FilePath,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Machine', 'User')]
		[string]$CertificateLocation = 'Machine',
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName = $env:COMPUTERNAME,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$CertReqFilePath = "$env:SystemRoot\system32\certreq.exe"
	)
	process
	{
		try
		{
			if (-not (Test-LocalComputer -ComputerName $ComputerName))
			{
				$sessParams = @{
					'ComputerName' = $ComputerName
				}
				
				$remoteFilePath = "C:\$([System.IO.Path]::GetFileName($FilePath))"
				$session = New-PSSession @sessParams
				
				$null = Send-File -Session $session -Path $FilePath -Destination 'C:\'
				
				Invoke-Command -Session $session -ScriptBlock { Start-Process -FilePath $using:CertReqFilePath -Args "-accept -$using:CertificateLocation `"$using:remoteFilePath`""}
			}
			else
			{
				Start-Process -FilePath $CertReqFilePath -Args "-accept -$CertificateLocation `"$FilePath`"" -Wait -NoNewWindow
			}
		}
		catch
		{
			throw $_
		}
		finally
		{
			Invoke-Command -Session $session -ScriptBlock {Remove-Item -Path $using:remoteFilePath -ErrorAction Ignore}
			Remove-PSSession -Session $session -ErrorAction Ignore
		}
	}
}