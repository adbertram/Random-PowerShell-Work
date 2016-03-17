#Requires -Version 4

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
<#
.SYNOPSIS
	This is a simple script that allows you to specify one or more folder paths on a file system and remove "old" files by
	last write time. By default, it will look for all files recursively in a particular folder, check for the last time those
	files have been written to, verify that last write time is older than $DaysOld and if, so, remove them.

.EXAMPLE
	PS> .\Remove-FileOlderThan.ps1 -FolderPath 'C:\Folder1','C:\Folder2' -DaysOld 30 -FileExtension 'doc'

	This example would recursively look through both the C:\Folder1 and C:\Folder2 folders for all *.doc files that have a 
	last write time of 30 days or older. Once found, they are removed.
	
.PARAMETER FolderPath
	One or more folder paths separated by a comma to look through. This is mandatory.

.PARAMETER DaysOld
	The minimum number of days old a file must be in order to be classified as "old". This is mandatory.

.PARAMETER FileExtension
	An optional parameter to only remove old files with a particular file extension.
#>
param (
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string[]]$FolderPath,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[int]$DaysOld,

	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[ValidateLength(1, 3)]
	[string]$FileExtension
)

$Now = Get-Date

$gciParams = @{
	'Recurse' = $true
	'File' = $true
}

if ($PSBoundParameters.ContainsKey('FileExtension')) {
	$gciParams.Filter = "Extension -eq $FileExtension"
}

$LastWrite = $Now.AddDays(-$DaysOld)

foreach ($path in $FolderPath)
{
	$gciParams.Path = $path
	((Get-ChildItem @gciParams).Where{ $_.LastWriteTime -le $LastWrite }).foreach{
		if ($PSCmdlet.ShouldProcess($_.FullName, 'Remove'))
		{
			Remove-Item -Path $_.FullName -Force
		}
	}
}