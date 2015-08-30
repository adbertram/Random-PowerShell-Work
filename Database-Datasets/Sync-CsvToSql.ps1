#Requires -Module SQLPSX

<#
.SYNOPSIS
	This queries compares the contents of a CSV file against a SQL database table
	and either reports or syncs the different field values to the SQL table.

	If -replace is not used, it will output only the rows in the SQL database that are
	different
	
	2/16/15 CURRENT LIMITATION: This will only sync int, smallint, varchar and char fields.
.NOTES
	Created on: 	2/16/15
	Created by: 	Adam Bertram
	Filename:		Sync-CsvToSql.ps1
.EXAMPLE
	
.EXAMPLE
.PARAMETER Replace
	Use this switch parameter to move from simply reporting on changes to making changes
.PARAMETER CsvFilePath
 	The path to the CSV file that will be read and compared against the SQL table	
.PARAMETER ServerInstance
	The server name and the instance name (if more than one installed) of the SQL server
.PARAMETER Database
	The name of the database that contains the table you'll be syncing
.PARAMETER Schema
	The database schema if other than dbo.
.PARAMETER Table
	The name of the SQL table you'll be syncing the CSV's contents to
#>
[CmdletBinding()]
param (
	[switch]$Replace,
	[Parameter(Mandatory)]
	[ValidateScript({ Test-Path $_ -PathType Leaf })]
	[string]$CsvFilePath,
	[Parameter(Mandatory)]
	[string]$ServerInstance,
	[Parameter(Mandatory)]
	[string]$Database,
	[string]$Schema = 'dbo',
	[Parameter(Mandatory)]
	[string]$Table
)

begin {
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	Set-StrictMode -Version Latest
	try {
		## Ensure the columns in the CSV file and the database are equal
		$CsvRows = Import-Csv -Path $CsvFilePath
		$SqlTable = Get-SqlTable -Database (Get-SqlDatabase -sqlserver $Server -dbname $Database) -Name $Table -Schema $Schema
		if (Compare-Object -DifferenceObject ($CsvRows[0].Psobject.Properties.Name) -ReferenceObject ($SqlTable.Columns.Name)) {
			throw 'The field names in the CSV file and the SQL database are not equal'
		}
		
		## Load the entire table in memory for faster querying
		$SqlRows = Get-SqlData -sqlserver $ServerInstance -dbname $Database -qry "SELECT * FROM $Table"
	} catch {
		Write-Error $_.Exception.Message
		exit
	}
}

process {
	try {
		
		## Find the primary key to keep a 1:1 match
		$PrimaryKey = ($SqlTable.Columns | Where-Object { $_.InPrimaryKey }).Name
		## I must separate the int and char columns out because if a string is detected in the CSV and that value
		## is attempted to be updated in the table in a non-char field, it will fail.  This allows me
		## to treat the value as a string with quotes or not.
		$SqlIntCols = $SqlTable.Columns | where { @('smallint', 'int') -contains $_.DataType.Name }
		$SqlCharCols = $SqlTable.Columns | where { @('varchar', 'char') -contains $_.DataType.Name }
		
		foreach ($CsvRow in $CsvRows) {
			try {
				## Find the match
				$SqlRow = $SqlRows | Where-Object { $_.$PrimaryKey -eq $CsvRow.$PrimaryKey }
				if ($SqlRow) {
					#Write-Verbose "SQL row match found for row $($CsvRow.$PrimaryKey)"
					#$FieldDiffs = [System.Collections.ArrayList]@()
					$FieldDiffs = [ordered]@{ }
					foreach ($CsvProp in ($CsvRow.PsObject.Properties | where { $_.Name -ne $PrimaryKey })) {
						foreach ($SqlProp in ($SqlRow.PsObject.Properties | where { $_.Name -ne $PrimaryKey })) {
							if (($CsvProp.Name -eq $SqlProp.Name) -and ($CsvProp.Value -ne $SqlProp.Value)) {
								$FieldDiffs["$($CsvProp.Name) - FROM"] = $SqlProp.Value;
								$FieldDiffs["$($CsvProp.Name) - TO"] = $CsvProp.Value
							}
						}
					}
					if (!($FieldDiffs.Keys | where { $_ })) {
						Write-Verbose "All fields are equal for row $($SqlRow.$PrimaryKey)"
					} else {
						$FieldDiffs['PrimaryKeyValue'] = $SqlRow.$PrimaryKey
						if (!$Replace.IsPresent) {
							[pscustomobject]$FieldDiffs
						} else {
							#						$UpdateString = 'UPDATE Directory SET '
							#						foreach ($Diff in $FieldDiffs) {
							#						if ($Replace.IsPresent) {
							#							if ($SqlIntCols.Name -contains $Prop.Name) {
							#								$Items.Add("$($Prop.Name)=$($Prop.Value)") | Out-Null
							#							} elseif ($SqlCharCols.Name -contains $Prop.Name) {
							#								$Items.Add("$($Prop.Name)='$($Prop.Value)'") | Out-Null
							#							}
							#							$UpdateString += ($Items -join ',')
							#							$UpdateString += " WHERE $PrimaryKey = '$($CsvRow.$PrimaryKey)'"
							#							Set-SqlData @SqlParams -qry $UpdateString
							#						} else {
							#							$Fiel
							#						}
						}
					}
				} else {
					Write-Verbose "No SQL row match found for CSV row $($CsvRow.$PrimaryKey)"
				}
			} catch {
				Write-Warning "Error Occurred: $($_.Exception.Message) in row $($CsvRow.$PrimaryKey)"
			}
		}
	} catch {
		Write-Error $_.Exception.Message
	}
}