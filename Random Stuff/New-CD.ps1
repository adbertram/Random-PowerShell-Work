<# 
	.SYNOPSIS 
		Burns multiple CD copies from a specified folder path 

	.DESCRIPTION 

	.EXAMPLE 
		PS> .\BurnCDs.ps1 -Path 'C:\Folder' -CdTitle 'Test Title' -Copies 67 

	.PARAMETER 
		Path The folder path containing the files you'd like to burn to the CD 

	.PARAMETER CdTitle 
		The title of the CD that you'd like to show up in Windows Explorer 

	.PARAMETER Copies 
		The number of copies of the CD you'd like 
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory = $True,
			   ValueFromPipeline = $True,
			   ValueFromPipelineByPropertyName = $True,
			   HelpMessage = 'What is the folder path you would like to burn?')]
	[string]$Path,
	
	[Parameter(Mandatory = $False,
			   ValueFromPipeline = $False,
			   ValueFromPipelineByPropertyName = $True,
			   HelpMessage = 'What is the name of the CD?')]
	[string]$CdTitle,
	
	[Parameter(Mandatory = $False,
			   ValueFromPipeline = $False,
			   ValueFromPipelineByPropertyName = $False,
			   HelpMessage = 'How many copies would you like?')]
	[int]$Copies = 1
)

begin
{
	
	Function Eject-CDTray
	{
        <#         
			.SYNOPSIS
				Ejects the local machine's CD tray.
		
			.DESCRIPTION
				This function looks for all available CD drives and ejects them.
		
			.EXAMPLE
				Eject-CDTray
		#>
		[CmdletBinding()]
		param (
		
		)
		
		begin
		{
			$sh = New-Object -ComObject "Shell.Application"
		}
		
		process
		{
			$sh.Namespace(17).Items() | Where { $_.Type -eq "CD Drive" } | foreach { $_.InvokeVerb("Eject") }
		}
		
		end
		{
			
		}
	}
	
	Function Close-CDTray
	{
        <#
			.SYNOPSIS
				Closes the local machine's CD tray if it's ejected.
			
			.EXAMPLE
				Close-CDTray
		#>
		[CmdletBinding()]
		param (
		
		)
		
		begin
		{
			$DiskMaster = New-Object -com IMAPI2.MsftDiscMaster2
			$DiscRecorder = New-Object -com IMAPI2.MsftDiscRecorder2
			$id = $DiskMaster.Item(0)
		}
		
		process
		{
			$DiscRecorder.InitializeDiscRecorder($id)
			$DiscRecorder.CloseTray()
		}
		
		end
		{
			
		}
	}
	
	Function Out-CD
	{
        <#
			.SYNOPSIS
				Burns the contents of a folder to a CD
			
			.DESCRIPTION
				This function retrieves the contents of a specified folder path and burns a CD with the specified title.
		
			.EXAMPLE
		
				PS> Out-CD -Path 'C:\Folder' -CdTitle 'This is my title'
		
			.PARAMETER Path
				The folder path containing the files you'd like to burn to the CD.
		
			.PARAMETER CdTitle
				The title of the CD that you'd like to show up in Windows Explorer
		#>
		[CmdletBinding()]
		param (
			[Parameter(Mandatory = $True,
					   ValueFromPipeline = $True,
					   ValueFromPipelineByPropertyName = $True,
					   HelpMessage = 'What is the folder path you would like to burn?')]
			[string]$Path,
			
			[Parameter(Mandatory = $False,
					   ValueFromPipeline = $False,
					   ValueFromPipelineByPropertyName = $True,
					   HelpMessage = 'What is the name of the CD?')]
			[string]$CdTitle
		)
		
		begin
		{
			try
			{
				Write-Verbose 'Creating COM Objects.'
				
				$DiskMaster = New-Object -com IMAPI2.MsftDiscMaster2
				$DiscRecorder = New-Object -com IMAPI2.MsftDiscRecorder2
				$FileSystemImage = New-Object -com IMAPI2FS.MsftFileSystemImage
				$DiscFormatData = New-Object -com IMAPI2.MsftDiscFormat2Data
			}
			catch
			{
				$err = $Error[0]
				Write-Error $err
				return
			}
		}
		
		process
		{
			Write-Verbose 'Initializing Disc Recorder.'
			$id = $DiskMaster.Item(0)
			$DiscRecorder.InitializeDiscRecorder($id)
			
			Write-Verbose 'Assigning recorder.'
			$dir = $FileSystemImage.Root
			$DiscFormatData.Recorder = $DiscRecorder
			$DiscFormatData.ClientName = 'PowerShell Burner'
			
			Write-Verbose 'Multisession?'
			if (-not $DiscFormatData.MediaHeuristicallyBlank)
			{
				try
				{
					$FileSystemImage.MultisessionInterfaces = $DiscFormatData.MultisessionInterfaces
					Write-Verbose 'Importing existing session.'
					
					$FileSystemImage.ImportFileSystem() | Out-Null
				}
				catch
				{
					$err = $Error[0]
					Write-Error $err
					return
				}
			}
			else
			{
				Write-Verbose 'Empty medium.'
				$FileSystemImage.ChooseImageDefaults($DiscRecorder)
				$FileSystemImage.VolumeName = $CdTitle
			}
			
			Write-Verbose "Adding directory tree ($Path)."
			$dir.AddTree($Path, $false)
			
			Write-Verbose 'Creating image.'
			$result = $FileSystemImage.CreateResultImage()
			$stream = $result.ImageStream
			
			Write-Verbose 'Burning.'
			$DiscFormatData.Write($stream)
			
			Write-Verbose 'Done.'
		}
		
		end
		{
			
		}
	}
	
	Eject-CDTray
}

process
{
	for ($i = 0; $i -lt $Copies; $i++)
	{
		Sleep -Seconds 7
		Close-CDTray
		Sleep -Seconds 8
		Out-Cd -Path $Path -CdTitle $CdTitle -Verbose
		Eject-CDTray
	}
}

end
{
	Sleep -Seconds 7
	Close-CDTray
}