<#
.SYNOPSIS

.NOTES
	Created on: 	8/22/2014
	Created by: 	Adam Bertram
	Filename:		
	Credits:		
	Requirements:	
	Todos:				
.EXAMPLE
	
.EXAMPLE
	
.PARAMETER PARAM1
 	
.PARAMETER PARAM2
	
#>
[CmdletBinding(DefaultParameterSetName = 'CSV')]
[OutputType('System.Management.Automation.PSCustomObject')]
param (
	[hashtable]$AdToSourceFieldMappings = @{ 'givenName' = 'FirstName'; 'Initials' = 'MiddleInitial'; 'surName' = 'LastName' },
	[hashtable]$AdToOutputFieldMappings = @{ 'givenName' = 'AD First Name'; 'Initials' = 'AD Middle Initial'; 'surName' = 'AD Last Name'; 'samAccountName' = 'AD Username' },
	[ValidateScript({Test-Path -Path $_ -PathType 'Leaf'})]
	[Parameter(Mandatory, ParameterSetName = 'CSV')]
	[ValidateScript({Test-Path -Path $_ -PathType 'Leaf' })]
	[string]$CsvFilePath
)

begin {
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	Set-StrictMode -Version Latest
	try {
		#region MatchTests
		function Test-MatchFirstNameLastName ($FirstName, $LastName) {
			if ($FirstName -and $LastName) {
				Write-Verbose -Message "$($MyInvocation.MyCommand) - Searching for AD user match based on first name '$FirstName', last name '$LastName'"
				$Match = $AdUsers | where { ($_.givenName -eq $FirstName) -and ($_.surName -eq $LastName) }
				if ($Match) {
					Write-Verbose "$($MyInvocation.MyCommand) - Match(es) found!"
					$Match
				} else {
					Write-Verbose "$($MyInvocation.MyCommand) - Match not found"
					$false	
				}
			} else {
				Write-Verbose "$($MyInvocation.MyCommand) - Match not found. Either first or last name is null"
				$false
			}
		}
	
		function Test-MatchFirstNameMiddleInitialLastName ($FirstName, $MiddleInitial, $LastName) {
			if ($FirstName -and $LastName -and $MiddleInitial) {
				Write-Verbose -Message "$($MyInvocation.MyCommand) - Searching for AD user match based on first name '$FirstName', middle initial '$MiddleInitial' and last name '$LastName'"
				$Match = $AdUsers | where { ($_.givenName -eq $FirstName) -and ($_.surName -eq $LastName) -and (($_.Initials -eq $MiddleInitial) -or ($_.Initials -eq "$MiddleInitial.")) }
				if ($Match) {
					Write-Verbose "$($MyInvocation.MyCommand) - Match(es) found!"
					$Match
				} else {
					Write-Verbose "$($MyInvocation.MyCommand) - Match not found"
					$false
				}
			} else {
				Write-Verbose "$($MyInvocation.MyCommand) - Match not found. Either first name, middle initial or last name is null"
				$false
			}
		}
		
		function Test-MatchFirstInitialLastName ($FirstName,$LastName) {
			Write-Verbose -Message "$($MyInvocation.MyCommand) - Searching for AD user match based on first initial '$($FirstName.Substring(0,1))' and last name '$LastName'"
			if ($FirstName -and $LastName) {
				$Match = $AdUsers | where { "$($FirstName.SubString(0, 1))$LastName" -eq $_.samAccountName }
				if ($Match) {
					Write-Verbose "$($MyInvocation.MyCommand) - Match(es) found!"
					$Match
				} else {
					Write-Verbose "$($MyInvocation.MyCommand) - Match not found"
					$false
				}
			} else {
				Write-Verbose "$($MyInvocation.MyCommand) - Match not found. Either first name or last name is null"
				$false
			}
		}
		<#
		function Test-MatchLikeFirstNameLikeLastName ($FirstName, $LastName) {
			if ($FirstName -and $LastName) {
				Write-Verbose -Message "$($MyInvocation.MyCommand) - Searching for AD user match based on like first name '$FirstName', last name '$LastName'"
				$Match = $AdUsers | where { ($FirstName -like "*$($_.givenName)*") -and ($LastName -like "*$($_.surName)*") }
				if ($Match) {
					Write-Verbose "$($MyInvocation.MyCommand) - Match(es) found!"
					$Match
				} else {
					Write-Verbose "$($MyInvocation.MyCommand) - Match not found"
					$false
				}
			} else {
				Write-Verbose "$($MyInvocation.MyCommand) - Match not found. Either first or last name is null"
				$false
			}
		}
		#>
		<#
		function Test-MatchCommonFirstNameTranslationsLastName ($FirstName, $LastName) {
			$Translations = @{
				'Kathy' = 'Kathleen'
				'Randy' = 'Randall'
				'Bob' = 'Robert'
				'Rob' = 'Robert'
			}
			if ($FirstName -and $LastName) {
				Write-Verbose -Message "$($MyInvocation.MyCommand) - Searching for AD user match based on first name '$FirstName', last name '$LastName'"
				$Match = $AdUsers | where { ($FirstName -match $_.givenName) -and ($LastName -match $_.surName) }
				if ($Match) {
					Write-Verbose "$($MyInvocation.MyCommand) - Match(es) found!"
					$Match
				} else {
					Write-Verbose "$($MyInvocation.MyCommand) - Match not found"
					$false
				}
			} else {
				Write-Verbose "$($MyInvocation.MyCommand) - Match not found. Either first or last name is null"
				$false
			}
		}
		#>
		
		#function Test-MatchLevenshteinDistance {
		#	
		#}
		#endregion
		
		#region ValidationTests
		function Test-CsvField {
			$CsvHeaders = (Get-Content $CsvFilePath | Select-Object -First 1).Split(',').Trim('"')
			$AdToSourceFieldMappings.Values | foreach {
				if (!($CsvHeaders -like $_)) {
					return $false
				}
			}
			$true
		}
		#endregion
		
		#region Functions
		function Get-LevenshteinDistance {
			# get-ld.ps1 (Levenshtein Distance)
			# Levenshtein Distance is the # of edits it takes to get from 1 string to another
			# This is one way of measuring the "similarity" of 2 strings
			# Many useful purposes that can help in determining if 2 strings are similar possibly
			# with different punctuation or misspellings/typos.
			#
			########################################################
			
			# Putting this as first non comment or empty line declares the parameters
			# the script accepts
			###########
			param ([string] $first, [string] $second, [switch] $ignoreCase)
			
			# No NULL check needed, why is that?
			# PowerShell parameter handling converts Nulls into empty strings
			# so we will never get a NULL string but we may get empty strings(length = 0)
			#########################
			
			$len1 = $first.length
			$len2 = $second.length
			
			# If either string has length of zero, the # of edits/distance between them
			# is simply the length of the other string
			#######################################
			if ($len1 -eq 0) { return $len2 }
			
			if ($len2 -eq 0) { return $len1 }
			
			# make everything lowercase if ignoreCase flag is set
			if ($ignoreCase -eq $true) {
				$first = $first.tolowerinvariant()
				$second = $second.tolowerinvariant()
			}
			
			# create 2d Array to store the "distances"
			$dist = new-object -type 'int[,]' -arg ($len1 + 1), ($len2 + 1)
			
			# initialize the first row and first column which represent the 2
			# strings we're comparing
			for ($i = 0; $i -le $len1; $i++) { $dist[$i, 0] = $i }
			for ($j = 0; $j -le $len2; $j++) { $dist[0, $j] = $j }
			
			$cost = 0
			
			for ($i = 1; $i -le $len1; $i++) {
				for ($j = 1; $j -le $len2; $j++) {
					if ($second[$j - 1] -ceq $first[$i - 1]) {
						$cost = 0
					} else {
						$cost = 1
					}
					
					# The value going into the cell is the min of 3 possibilities:
					# 1. The cell immediately above plus 1
					# 2. The cell immediately to the left plus 1
					# 3. The cell diagonally above and to the left plus the 'cost'
					##############
					# I had to add lots of parentheses to "help" the Powershell parser
					# And I separated out the tempmin variable for readability
					$tempmin = [System.Math]::Min(([int]$dist[($i - 1), $j] + 1), ([int]$dist[$i, ($j - 1)] + 1))
					$dist[$i, $j] = [System.Math]::Min($tempmin, ([int]$dist[($i - 1), ($j - 1)] + $cost))
				}
			}
			
			# the actual distance is stored in the bottom right cell
			return $dist[$len1, $len2];
		}
		
		<#
		function Test-DataRow ([object]$SourceRowData) {
			## Check for instances where all fields are null
			$FieldCount = $SourceRowData.psObject.Properties.Name.Count
			$NullValues = $SourceRowData.psObject.Properties.Value | where { $_ -eq $null }
			if ($NullValues -and ($FieldCount -eq $NullValues.Count)) {
				Write-Warning 'This source data row contains all null fields'
				$false
			} else {
				$true	
			}
		}
		#>
		
		function New-OutputRow ([object]$SourceRowData) {
			$OutputRow = [ordered]@{
				'Match' = $false;
				'MatchTest' = 'N/A'
			}
			$AdToOutputFieldMappings.Values | foreach {
				$OutputRow[$_] = 'N/A'
			}
			
			$SourceRowData.psobject.Properties | foreach {
				if ($_.Value) {
					$OutputRow[$_.Name] = $_.Value
				}
			}
			$OutputRow
		}
		
		function Add-ToOutputRow ([hashtable]$OutputRow, [object]$AdRowData, $MatchTest) {
			$AdToOutputFieldMappings.Keys | foreach {
				if ($AdRowData.$_) {
					$OutputRow[$AdToOutputFieldMappings[$_]] = $AdRowData.$_
				}
				$OutputRow.MatchTest = $MatchTest
			}
			$OutputRow
		}
		
		function Test-TestMatchValid ($FunctionParameters) {
			$Compare = Compare-Object -ReferenceObject $FunctionParameters -DifferenceObject ($AdToSourceFieldMappings.Values | % { $_ }) -IncludeEqual -ExcludeDifferent
			if (!$Compare) {
				$false
			} elseif ($Compare.Count -ne $FunctionParameters.Count) {
				$false
			} else {
				$true	
			}
		}
		
		function Get-FunctionParams ($Function) {
			$Function.Parameters.Keys | where { $AdToSourceFieldMappings.Values -contains $_ }
		}
		#endregion
		
		## Each row of the reference data source will be checked for a match with an AD user object by
		## attempting a match based on any of the Test-Match* functions.  Each match function needs to be
		## assigned a priority.  A match will be attempted starting from the highest priority match function
		## to the lowest until a match is made.  Once the match is made, matching will stop.
		$MatchFunctionPriorities = @{
			'Test-MatchFirstNameMiddleInitialLastName' = 1
			'Test-MatchFirstNameLastName' = 2
			#'Test-MatchLikeFirstNameLikeLastName' = 3
			'Test-MatchFirstInitialLastName' = 4
		}
		
		if ($PSBoundParameters.CsvFilePath) {
			Write-Verbose -Message "Verifying all field names in the $CsvFilePath match $($AdToSourceFieldMappings.Values -join ',')"
			if (!(Test-CsvField)) {
				throw "One or more fields specified in the `$AdToSourceFieldMappings param do not exist in the CSV file $CsvFilePath"
			} else {
				Write-Verbose "The CSV file's field match source field mappings"
			}
		}
		
	} catch {
		Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
		return
	}
	
	Write-Verbose -Message "Retrieving all Active Directory user objects..."
	$script:AdUsers = Get-ADUser -Filter * -Properties 'DisplayName','Initials'
}

process {
	try {
		## Find all functions in memory that match Test-match*.  This will automatically include all of our tests
		## without having to call them one at a time.  This will also automatically match all functions with only
		## the fields the source data has
		$TestFunctions = Get-ChildItem function:\Test-Match* | where { !$_.Module }
		Write-Verbose "Found $($TestFunctions.Count) test functions in the script"
		$MatchTestsToRun = @()
		foreach ($TestFunction in $TestFunctions) {
			Write-Verbose -Message "Checking to see if we'll use the $($TestFunction.Name) function"
			if (Test-TestMatchValid -FunctionParameters ($TestFunction.Parameters.Keys | % { $_ })) {
				Write-Verbose -Message "The source data has all of the function $($TestFunction.Name)'s parameters. We'll try this one"
				$MatchTestsToRun += [System.Management.Automation.FunctionInfo]$TestFunction
			} else {
				Write-Verbose -Message "The parameters $($AdToSourceFieldMappings.Keys -join ',') are not adequate for the function $($TestFunction.Name)"
			}
		}
		
		## Once all the tests have been gathered that apply to the fields in the data source match them with the
		## function name in the priorities hash table and sort them by priority
		$MatchTestsToRun | foreach {
			$Test = $_;
			foreach ($i in $MatchFunctionPriorities.GetEnumerator()) {
				if ($Test.Name -eq $i.Key) {
					Write-Verbose "Assigning a priority of $($i.Value) to function $($Test.Name)"
					$Test | Add-Member -NotePropertyName 'Priority' -NotePropertyValue $i.Value
				}
			}
		}
		$MatchTestsToRun = $MatchTestsToRun | Sort-Object Priority
		
		if ($CsvFilePath) {
			$DataRows = Import-Csv -Path $CsvFilePath	
		}
		
		## Add any future data sources here ensuring they all get assigned to $DataRows
		
		foreach ($Row in $DataRows) {
			#if (Test-DataRow -SourceRowData $Row) {
				[hashtable]$OutputRow = New-OutputRow -SourceRowData $Row
				## Run the match tests that only apply to the fields in the source data
				## This prevents tests from being run that have param requirements that our
				## source data doesn't have like when the source data only has first name and
				## last name.  This means we couldn't run the Test-FirstNameMiddleInitialLastName function.
				foreach ($Test in $MatchTestsToRun) {
					Write-Verbose -Message "Running function $($Test.Name)..."
					[array]$FuncParamKeys = Get-FunctionParams -Function $Test
					[hashtable]$FuncParams = @{ }
					[array]$FuncParamKeys | foreach {
						$Row.psObject.Properties | foreach {
							if ([array]$FuncParamKeys -contains [string]$_.Name) {
								$FuncParams[$_.Name] = $_.Value
							}
						}
					}
					Write-Verbose -Message "Passing the parameters '$($FuncParams.Keys -join ',')' with values '$($FuncParams.Values -join ',')' to the function $($Test.Name)"
					$AdTestResultObject = & $Test @FuncParams
					if ($AdTestResultObject) {
						$OutputRow.Match = $true
						foreach ($i in $AdTestResultObject) {
							$OutputRow = Add-ToOutputRow -AdRowData $i -OutputRow $OutputRow -MatchTest $Test.Name
						}
						break
					}
				}
			#}
			[pscustomobject]$OutputRow
		}
	} catch {
		Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
	}
}