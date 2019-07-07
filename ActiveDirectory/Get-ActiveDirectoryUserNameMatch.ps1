function Get-ActiveDirectoryUserNameMatch($FirstName,$LastName,$MiddleInitial) {
	if ($MiddleInitial) {
		$Filter = { (initials -eq $MiddleInitial) -and (surname -eq $LastName) -and (givenname -eq $FirstName) }
		$MatchType = 'FML'
	} else {
		$Filter = { (surname -eq $LastName) -and (givenname -eq $FirstName) }
		$MatchType = 'FL'
	}
	$Param = @{ 'Filter' = $Filter; 'Properties' = 'DisplayName' }
	$Result = Get-ADUser @Param
	if ($Result) {
		$Result | Add-Member -Type 'NoteProperty' -Name 'MatchMethod' -Value $MatchType -Force
	} else {
		$UserCount = $AllAdUsers.Count
		for ($i=0; $i -lt $UserCount; $i++) {
			$FnameDistance = Get-LevenshteinDistance -first $FirstName -second $AllAdusers[$i].Givenname -ignoreCase
			$LnameDistance = Get-LevenshteinDistance -first $LastName -second $AllAdusers[$i].surname -ignoreCase
			$TotalDistance = $FnameDistance + $LnameDistance
			if ($i -eq 0) {
				$Result = $AllAdUsers[$i]
				$LowestDistance = $TotalDistance
			} elseif ($TotalDistance -lt $LowestDistance) {
				$Result = $AllAdUsers[$i]
				$LowestDistance = $TotalDistance
			}
		}
		$Result | Add-Member -Type 'NoteProperty' -Name 'MatchMethod' -Value 'LowestEditDistance' -Force
	}
	$Result
}
 
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
 
$AllAdUsers = Get-ADUser -Filter { (givenname -like '*') -and (surname -like '*') } -Properties 'DisplayName'
$Content = Get-Content 'C:\users.txt'
$UnknownSourceUsers = [system.Collections.ArrayList]@()
foreach ($Row in $Content) {
	$Split = $Row.Split(' ');
	$LastName = $Split[$Split.Count - 1];
	$FirstName = $Split[0];
	$MiddleInitial = @{ $true = $Split[1]; $false = '' }[($Split.Count -eq 3) -and ($Split[1].Length -eq 1)]
	if (($Split.Count -gt 3) -or ($Split.Count -lt 2) -or (($Split[1].Length -ne 1) -and ($Split.Count -eq 3))) {
		$UnknownSourceUsers.Add($Row) | Out-Null
	} else {
		$Output = @{
			'SourceFirstName' = $FirstName
			'SourceLastName' = $LastName
			'SourceMiddleInitial' = $MiddleInitial
			'ActiveDirectoryFirstname' = ''
			'ActiveDirectoryLastName' = ''
			'ActiveDirectoryDisplayName' = ''
			'ActiveDirectorySamAccountName' = ''
			'ActiveDirectoryStatus' = ''
			'ActiveDirectoryMatchMethod' = 'NoMatch'
		}
		$AdMatch = Get-ActiveDirectoryUserNameMatch -FirstName $FirstName -LastName $LastName -MiddleInitial $MiddleInitial
		if (!$AdMatch) {
			[pscustomobject]$Output | Export-Csv -Path johnoutput.csv -Append -NoTypeInformation
		} else {
			$Output.ActiveDirectoryDisplayName = $AdMatch.DisplayName
			$Output.ActiveDirectoryFirstName = $AdMatch.givenName
			$Output.ActiveDirectoryLastName = $AdMatch.surName
			$Output.ActiveDirectorySamAccountName = $AdMatch.SamAccountName
			$Output.ActiveDirectoryStatus = $AdMatch.Enabled
			$Output.ActiveDirectoryMatchMethod = $AdMatch.MatchMethod
			[pscustomobject]$Output | Export-Csv -Path output.csv -Append -NoTypeInformation
		}
		
	}
}
Write-Host 'Unrecognized name formats'
$UnknownSourceUsers
