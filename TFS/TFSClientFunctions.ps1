function Add-ItemToTfs
{	
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path $_ })]
		[string]$ItemPath,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[string]$tfFilePath = 'C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\TF.exe'
	
	)
	$ErrorActionPreference = 'Stop'
	try
	{
		Write-Verbose -Message "Adding the item [$($Itempath)] into TFS"
		
		$null = & $tfFilePath add $Itempath
		
		if (Test-Path -Path $ItemPath -PathType Container)
		{
			## Add the files inside the folder
			Get-ChildItem -Path $Itempath | ForEach-Object { $null = & $tfFilePath add $_.FullName }
		}
	}
	catch
	{
		Write-Error $_.Exception.Message
	}
}

function Submit-TfsChange
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path $_ })]
		[string]$ItemPath,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Comment = 'New Checkin',
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[string]$tfFilePath = 'C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\TF.exe'
	)
	try
	{
		Write-Verbose -Message "Checking in [$($Itempath)] to TFS"
		$null = & $tfFilePath checkin $Itempath /recursive /comment:$Comment
	}
	catch
	{
		Write-Error $_.Exception.Message
	}
}