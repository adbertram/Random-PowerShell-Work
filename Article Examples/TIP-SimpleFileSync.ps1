$Folder1Path = 'C:\Folder1'
$Folder2Path = 'C:\Folder2'

$Folder1Files = Get-ChildItem -Path $Folder1Path
$Folder2Files = Get-ChildItem -Path $Folder2Path

$FileDiffs = Compare-Object -ReferenceObject $Folder1Files -DifferenceObject $Folder2Files

$FileDiffs | foreach {
	$removeParams = @{
		'Path' = $_.InputObject.FullName
	}
	if ($_.SideIndicator -eq '<=')
	{
		$removeParams.Destination = $Folder2Path
	}
	else
	{
		$removeParams.Destination = $Folder1Path
	}
	Copy-Item @removeParams
}

####################################################

$Folder1Path = 'C:\Folder1'
$Folder2Path = 'C:\Folder2'

$Folder1Files = Get-ChildItem -Path $Folder1Path
$Folder2Files = Get-ChildItem -Path $Folder2Path

$FileDiffs = Compare-Object -ReferenceObject $Folder1Files -DifferenceObject $Folder2Files

$FileDiffs | foreach {
	Remove-Item -Path $_.InputObject.FullName
}