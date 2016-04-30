#requires -Version 4

function New-ScreenShot
{
	<#
	.SYNOPSIS
		This function take a screenshot of your computer and saves it to a file of your choosing. It will only capture a single
		screen on a multi-monitor setup.
		
	.EXAMPLE
		PS> New-ScreenShot -FilePath C:\Screenshot.bmp
	
		This example will capture a screenshot of your current screen and save it to a BITMAP file at C:\ScreenShot.bmp.
		
	.PARAMETER FilePath
		A mandatory parameter that specifies where you'd like the screenshot image to be saved. If a file is detected in this
		path, the function will not allow the capture to happen. There must be no file at this location.
	
		You may choose file extensions of JPG, JPEG and BMP.
	
	.OUTPUTS
		System.IO.FileInfo
	#>
	[OutputType([System.IO.FileInfo])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ -not (Test-Path -Path $_ -PathType Leaf) })]
		[ValidatePattern('\.jpg|\.jpeg|\.bmp')]
		[string]$FilePath
			
	)
	begin {
		$ErrorActionPreference = 'Stop'
		Add-Type -AssemblyName System.Windows.Forms
		Add-type -AssemblyName System.Drawing
	}
	process {
		try
		{
			# Gather Screen resolution information
			$Screen = [System.Windows.Forms.SystemInformation]::VirtualScreen

			# Create bitmap using the top-left and bottom-right bounds
			$bitmap = New-Object System.Drawing.Bitmap $Screen.Width, $Screen.Height
			
			# Create Graphics object
			$graphic = [System.Drawing.Graphics]::FromImage($bitmap)
			
			# Capture screen
			$graphic.CopyFromScreen($Screen.Left, $Screen.Top, 0, 0, $bitmap.Size)
			
			# Save to file
			$bitmap.Save($FilePath)
			
			Get-Item -Path $FilePath
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}