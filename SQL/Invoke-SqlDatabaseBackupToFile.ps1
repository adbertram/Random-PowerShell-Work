#Requires -Module SQLPS

function Invoke-SqlDatabaseBackupToFile
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Database,
	
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1 })]
		[string]$Server,
	
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Full','Differential')]
		[string]$Type = 'Full',
	
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ -not (Test-Path -Path $_ -PathType Leaf) })]
		[string]$FilePath
	)
	
	$query = @"
		BACKUP DATABASE $Database
		TO DISK = '$FilePath'
"@
	
	if ($Type -eq 'Differential')
	{
		$query += ' WITH DIFFERENTIAL'
	}
	
	Write-Verbose -Message "Running query: $($query)"
	
	Invoke-SQLCmd -ServerInstance $Server -Database $Database -Query $query
}