## Specify all file paths and configuration values
$sUnionEmployeesFilePath = 'Union Lawson Employees.csv';
$sUapEmployeesFilePath = 'UAPEmployees.csv';
$sOutputFilePath = 'old-non-employee-AD-user-accounts.tsv';
$iDefinedOldDays = 90;
$dDaysAgo = [DateTime]::Now.Subtract([TimeSpan]::FromDays($iDefinedOldDays));

## Normalize both the Union and UAP spreadsheets into standard properties to match
## AD property names and ensure all alpha characters are lowercase to simplify matching
## Properties: EmployeeId,GivenName,SurName,Department
$aUnionContent = Get-Content $sUnionEmployeesFilePath;
$aUnionNoHeader = Get-Content $sUnionEmployeesFilePath | Select-Object -Skip 1;
$aUapContent = Get-Content $sUapEmployeesFilePath;
$aUapNoHeader = Get-Content $sUapEmployeesFilePath | Select-Object -Skip 1;

## Rename all interesting header columns in Lawson content
$sHeaderRow = $aUnionContent[0];
$sHeaderRow = $sHeaderRow.Replace('EMPLOYEE','EmployeeID');
$sHeaderRow = $sHeaderRow.Replace('LAST_NAME','Surname');
$sHeaderRow = $sHeaderRow.Replace('FIRST_NAME','GivenName');
$sHeaderRow = $sHeaderRow.Replace('R_NAME','Department');
$sHeaderRow = $sHeaderRow.Replace('MIDDLE_INIT','Initials');
$sHeaderRow = $sHeaderRow.Replace('LAWSON_PAPOSITION.DESCRIPTION','Title');
$sHeaderRow = $sHeaderRow.Replace('LAWSON_EMSTATUS.DESCRIPTION','HireStatus');
Set-Content $sUnionEmployeesFilePath -Value $sHeaderRow,$aUnionContent[1..($aUnionContent.Count)];

## Add the HireStatus column to the UAP content (if necessary)
$sHeaderRow = $aUapContent[0];
if ($sHeaderRow -notmatch "^.*,HireStatus$") {
	$sHeaderRow = "$sHeaderRow,HireStatus";
}##endif
Set-Content $sUapEmployeesFilePath -Value $sHeaderRow,$aUapContent[1..($aUapContent.Count)];

## Bring in the first data sources
$aUnionEmployeesCsv = Import-Csv $sUnionEmployeesFilePath;
$aUapEmployeesCsv = Import-Csv $sUapEmployeesFilePath;

## Merge both UAP and Union employee lists to simplify comparision
$global:aEmployeesFromCsv = $aUnionEmployeesCsv + $aUapEmployeesCsv;
$global:iEmpCount = $aEmployeesFromCsv.Count;

## Bring in the second data source for comparison
$aOldUsers = Get-ADUser -Filter {(Enabled -eq 'True') -and (LastLogonDate -le $dDaysAgo) -and (PasswordLastSet -le $dDaysAgo)} -Properties EmployeeID,LastLogonDate,PasswordLastSet,Department,Initials;
## The last element is always null for some reason
$iAdUserCount = $aOldUsers.Count;

function isActiveEmployee($oAdUser) {
	for ($i = 0; $i -lt $iEmpCount; $i++) {
		if ($oAdUser.EmployeeID -and $aEmployeesFromCsv[$i].EmployeeID) {
			if ($oAdUser.EmployeeID -eq $aEmployeesFromCsv[$i].EmployeeID) {
				return @($true,$oAdUser,$aEmployeesFromCsv[$i].HireStatus);
			}##endif
		}##endif
		if ($aEmployeesFromCsv[$i].Surname -and $aEmployeesFromCsv[$i].GivenName) { ## Ensure we're not trying to match on a blank
			if ($oAdUser.GivenName -match '^[^0-9]*$') { ## No numbers in first name field
				if ($oAdUser.Surname -match '^[^-]*$') { ## No dashes in the last name field
					$sLNameLike = '*' + $aEmployeesFromCsv[$i].Surname.Trim() + '*';
					$sFNameLike = '*' + $aEmployeesFromCsv[$i].GivenName.Trim() + '*';
					if ($oAdUser.Surname -like $sLNameLike) { # If the employee last name is anywhere in the AD last name
						if ($oAdUser.GivenName -like $sFNameLike) { ## If the employee first name is anywhere in the AD first name
							return @($true,$oAdUser,$aEmployeesFromCsv[$i].HireStatus);
						}##endif
					}##endif
				}##endif
			}##endif
		}##endif
	}##endfor
	return @($false,$oAdUser,$null);
}##endfunction

function createCustomObject($oAdUser,$sHireStatus) {
	$hProps = @{
		EmployeeID=$oAdUser.EmployeeID;
		LastLogonDate=$oAdUser.LastLogonDate;
		PasswordLastSet=$oAdUser.PasswordLastSet;
		SamAccount=$oAdUser.SamAccountName;
		FirstName=$oAdUser.GivenName;
		LastName=$oAdUser.Surname;
		Department=$oAdUser.Department;
		HireStatus=$sHireStatus
	};
	
	$obj = New-Object -TypeName PSObject -Property $hProps;
	return $obj;
}##endfunction

for ($i = 0; $i -lt $iAdUserCount; $i++) {
	$aIsActiveEmployee = isActiveEmployee $aOldUsers[$i];
	if (!$aIsActiveEmployee[0]) {
		$oUser = createCustomObject $aOldUsers[$i] 'N/A';
	} elseif ($aIsActiveEmployee[2] -eq 'TERMINATED') {
		$oUser = createCustomObject $aOldUsers[$i] 'Terminated';
	} else {
		$oUser = createCustomObject $aOldUsers[$i] 'Active';
	}##endif
	Write-ObjectToCsv -Object $oUser -CsvPath $sOutputFilePath -Delimiter "`t";
}##endfor

Write-Host 'Done' -ForegroundColor Green