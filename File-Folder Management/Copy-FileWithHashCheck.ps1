function Copy-FileWithHashCheck {
	<#
	.SYNOPSIS
		This function copies a file and then verifies the copy was successful by comparing the source and destination
		file hash values.
	.EXAMPLE
		PS> Copy-FileWithHashCheck -SourceFilePath 'C:\Windows\file1.txt' -DestinationFolderPath '\\COMPUTER\c$\Windows'
		
		This example copies the file from C:\Windows\file1.txt to \\COMPUTER\c$\Windows and then checks the hash for the
		source file and destination file to ensure the copy was successful.
	.EXAMPLE
		PS> Get-ChildItem C:\*.txt | Copy-FileWithHashCheck -DestinationFolderPath '\\COMPUTER\c$\Windows'

		This example copies all files matchint the .txt file extension from C:\ to \\COMPUTER\c$\Windows and then checks the hash for the
		source file and destination file to ensure the copy was successful.
	.PARAMETER SourceFilePath
		The source file path
	.PARAMETER DestinationFolderPath
		The destination folder path
	.PARAMETER Force
		Overwrite the destination file if one exists
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $True)]
		[Alias('Fullname')]
		[string]$SourceFilePath,
		[Parameter(Mandatory = $true)]
		[ValidateScript({ Test-Path -Path $_ -PathType Container })]
		[string]$DestinationFolderPath,
		[Parameter()]
		[switch]$Force
	)
	begin {
		function Test-HashEqual ($FilePath1, $FilePath2) {
			$SourceHash = Get-MyFileHash -Path $FilePath1
			$DestHash = Get-MyFileHash -Path $FilePath2
			if ($SourceHash.SHA256 -ne $DestHash.SHA256) {
				$false
			} else {
				$true
			}
		}
		
		function Get-MyFileHash {
    	<#
        .SYNOPSIS
            Calculates the hash on a given file based on the seleced hash algorithm.

        .DESCRIPTION
            Calculates the hash on a given file based on the seleced hash algorithm. Multiple hashing 
            algorithms can be used with this command.

        .PARAMETER Path
            File or files that will be scanned for hashes.

        .PARAMETER Algorithm
            The type of algorithm that will be used to determine the hash of a file or files.
            Default hash algorithm used is SHA256. More then 1 algorithm type can be used.
            
            Available hash algorithms:

            MD5
            SHA1
            SHA256 (Default)
            SHA384
            SHA512
            RIPEM160

        .NOTES
            Name: Get-FileHash
            Author: Boe Prox
            Created: 18 March 2013
            Modified: 28 Jan 2014
                1.1 - Fixed bug with incorrect hash when using multiple algorithms

        .OUTPUTS
            System.IO.FileInfo.Hash

        .EXAMPLE
            Get-FileHash -Path Test2.txt
            Path                             SHA256
            ----                             ------
            C:\users\prox\desktop\TEST2.txt 5f8c58306e46b23ef45889494e991d6fc9244e5d78bc093f1712b0ce671acc15      
            
            Description
            -----------
            Displays the SHA256 hash for the text file.   

        .EXAMPLE
            Get-FileHash -Path .\TEST2.txt -Algorithm MD5,SHA256,RIPEMD160 | Format-List
            Path      : C:\users\prox\desktop\TEST2.txt
            MD5       : cb8e60205f5e8cae268af2b47a8e5a13
            SHA256    : 5f8c58306e46b23ef45889494e991d6fc9244e5d78bc093f1712b0ce671acc15
            RIPEMD160 : e64d1fa7b058e607319133b2aa4f69352a3fcbc3

            Description
            -----------
            Displays MD5,SHA256 and RIPEMD160 hashes for the text file.

        .EXAMPLE
            Get-ChildItem -Filter *.exe | Get-FileHash -Algorithm MD5
            Path                               MD5
            ----                               ---
            C:\users\prox\desktop\handle.exe  50c128c5b28237b3a01afbdf0e546245
            C:\users\prox\desktop\PortQry.exe c6ac67f4076ca431acc575912c194245
            C:\users\prox\desktop\procexp.exe b4caa7f3d726120e1b835d52fe358d3f
            C:\users\prox\desktop\Procmon.exe 9c85f494132cc6027762d8ddf1dd5a12
            C:\users\prox\desktop\PsExec.exe  aeee996fd3484f28e5cd85fe26b6bdcd
            C:\users\prox\desktop\pskill.exe  b5891462c9ca5bddfe63d3bae3c14e0b
            C:\users\prox\desktop\Tcpview.exe 485bc6763729511dcfd52ccb008f5c59

            Description
            -----------
            Uses pipeline input from Get-ChildItem to get MD5 hashes of executables.

    		#>
			[CmdletBinding()]
			Param (
				[Parameter(Position = 0, Mandatory = $true, ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $True)]
				[Alias("PSPath", "FullName")]
				[string[]]$Path,
				
				[Parameter(Position = 1)]
				[ValidateSet("MD5", "SHA1", "SHA256", "SHA384", "SHA512", "RIPEMD160")]
				[string[]]$Algorithm = "SHA256"
			)
			Process {
				ForEach ($item in $Path) {
					try {
						$item = (Resolve-Path $item).ProviderPath
						If (-Not ([uri]$item).IsAbsoluteUri) {
							Write-Verbose ("{0} is not a full path, using current directory: {1}" -f $item, $pwd)
							$item = (Join-Path $pwd ($item -replace "\.\\", ""))
						}
						If (Test-Path $item -Type Container) {
							Write-Warning ("Cannot calculate hash for directory: {0}" -f $item)
							Return
						}
						$object = New-Object PSObject -Property @{
							Path = $item
						}
						#Open the Stream
						$stream = ([IO.StreamReader]$item).BaseStream
						foreach ($Type in $Algorithm) {
							[string]$hash = -join ([Security.Cryptography.HashAlgorithm]::Create($Type).ComputeHash($stream) |
							ForEach { "{0:x2}" -f $_ })
							$null = $stream.Seek(0, 0)
							#If multiple algorithms are used, then they will be added to existing object
							$object = Add-Member -InputObject $Object -MemberType NoteProperty -Name $Type -Value $Hash -PassThru
						}
						$object.pstypenames.insert(0, 'System.IO.FileInfo.Hash')
						#Output an object with the hash, algorithm and path
						Write-Output $object
						
						#Close the stream
						$stream.Close()
					} catch {
						Write-Log -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" -LogLevel '3'
						$false
					}
				}
			}
		}
	}
	process {
		try {
			$CopyParams = @{ 'Path' = $SourceFilePath; 'Destination' = $DestinationFolderPath }
			
			## If the file is already there, check to see if it's the one we're copying in the first place
			$DestFilePath = "$DestinationFolderPath\$($SourceFilePath | Split-Path -Leaf)"
			if (Test-Path -Path $DestFilePath -PathType 'Leaf') {
				if (Test-HashEqual -FilePath1 $SourceFilePath -FilePath2 $DestFilePath) {
					Write-Verbose -Message "The file $SourceFilePath is already in $DestinationFolderPath and is the same. No need to copy"
					return $true
				} elseif (!$Force.IsPresent) {
					throw "A file called $SourceFilePath is already in $DestinationFolderPath but is not the same file being copied."
				} else {
					$CopyParams.Force = $true
				}
			}
			
			Write-Verbose "Copying file $SourceFilePath..."
			Copy-Item @CopyParams
			if (Test-HashEqual -FilePath1 $SourceFilePath -FilePath2 $DestFilePath) {
				Write-Verbose -Message "The file $SourceFilePath was successfully copied to $DestinationFolderPath"
				return $true
			} else {
				throw "Attempted to copy the file $SourceFilePath to $DestinationFolderPath but failed the hash check"
			}
			
		} catch {
			Write-Error -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
			$false
		}
	}
}