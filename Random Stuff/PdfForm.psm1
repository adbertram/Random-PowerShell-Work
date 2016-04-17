#Requires -Version 4

function Find-ITextSharpLibrary
{
	[OutputType([System.IO.FileInfo])]
	[CmdletBinding()]
	param
	()
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			## Download the iTextSharp library
			$tempFile = [System.IO.Path]::GetTempFileName()
			
			Write-Verbose -Message "Downloading iTextSharp library as [$($tempFile)]..."
			$params = @{
				'Uri' = 'https://sourceforge.net/projects/itextsharp/files/itextsharp/iTextSharp-5.5.9/itextsharp-all-5.5.9.zip/download?use_mirror=jaist&r=&use_mirror=jaist'
				'OutFile' = $tempFile
				'UserAgent' = [Microsoft.PowerShell.Commands.PSUserAgent]::Firefox
			}
			Invoke-WebRequest @params
			
			if ((Get-Item -Path $tempFile).Length -lt '54000')
			{
				throw 'ITextLibrary download failed. Go to https://sourceforge.net/projects/itextsharp to download manually.'
			}
			else
			{
				## Extract the iTextSharp DLL
				Add-Type -assembly 'System.io.compression.filesystem'
				[io.compression.zipfile]::ExtractToDirectory($tempFile, $env:TEMP)
				[io.compression.zipfile]::ExtractToDirectory("$env:TEMP\itextsharp-dll-core.zip", $env:TEMP)
				Get-Item -Path "$env:TEMP\itextsharp.dll"
			}
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function Get-PdfFieldNames
{
	[OutputType([string])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('\.pdf$')]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[string]$FilePath,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('\.dll$')]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[string]$ITextLibraryPath = (Find-ITextSharpLibrary).FullName
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
		## Load the iTextSharp DLL to do all the heavy-lifting 
		[System.Reflection.Assembly]::LoadFrom($ITextLibraryPath) | Out-Null
	}
	process
	{
		try
		{
			$reader = New-Object iTextSharp.text.pdf.PdfReader -ArgumentList $FilePath
			$reader.AcroFields.Fields.Key
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function Save-PdfField
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[Hashtable]$Fields,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('\.pdf$')]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[string]$InputPdfFilePath,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('\.pdf$')]
		[ValidateScript({ -not (Test-Path -Path $_ -PathType Leaf) })]
		[string]$OutputPdfFilePath,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('\.dll$')]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[string]$ITextSharpLibrary = (Find-ITextSharpLibrary).FullName
		
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$reader = New-Object iTextSharp.text.pdf.PdfReader -ArgumentList $InputPdfFilePath
			$stamper = New-Object iTextSharp.text.pdf.PdfStamper($reader, [System.IO.File]::Create($OutputPdfFilePath))
			
			## Apply all hash table elements into the PDF form
			foreach ($j in $Fields.GetEnumerator())
			{
				$null = $stamper.AcroFields.SetField($j.Key, $j.Value)
			}
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
		finally
		{
			## Close up shop 
			$stamper.Close()
			Get-Item -Path $OutputPdfFilePath
		}
	}
}