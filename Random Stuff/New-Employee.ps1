param(
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$CsvFilePath
)

function New-CompanyAdUser {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$EmployeeRecord
	)

	## Generate a random password
	$password = [System.Web.Security.Membership]::GeneratePassword((Get-Random -Minimum 20 -Maximum 32), 3)
	$secPw = ConvertTo-SecureString -String $password -AsPlainText -Force

	## Generate a first initial/last name username
	$userName = "$($EmployeeRecord.FirstName.Substring(0,1))$($EmployeeRecord.LastName))"

	## Create the user
	$NewUserParameters = @{
		GivenName       = $EmployeeRecord.FirstName
		Surname         = $EmployeeRecord.LastName
		Name            = $userName
		AccountPassword = $secPw
	}
	New-AdUser @NewUserParameters

	## Add the user to the department group
	Add-AdGroupMember -Identity $EmployeeRecord.Department -Members $userName
}

function New-CompanyUserFolder {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$EmployeeRecord
	)

	$fileServer = 'FS1'

	$null = New-Item -Path "\\$fileServer\Users\$($EmployeeRecord.FirstName)$($EmployeeRecord.LastName)" -ItemType Directory

}

function Register-CompanyMobileDevice {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$EmployeeRecord
	)

	## Send an email for now. If we ever can automate this, we'll do it here.
	$sendMailParams = @{
		'From'       = 'EmailAddress@gmail.com'
		'To'         = 'SomeOtherAddress@whatever.com'
		'Subject'    = 'A new mobile device needs to be registered'
		'Body'       = "Employee: $($EmployeeRecord.FirstName) $($EmployeeRecord.LastName)"
		'SMTPServer' = 'smtpserver.something.local'
		'SMTPPort'   = '587'
	}
	
	Send-MailMessage @sendMailParams

}

function Read-Employee {
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$CsvFilePath = $CsvFilePath
	)

	Import-Csv -Path $CsvFilePath

}


$functions = 'New-CompanyAdUser','New-CompanyUserFolder','Register-CompanyMobileDevice'
foreach ($employee in (Read-Employee)) {
	foreach ($function in $functions) {
		& $function -EmployeeRecord $employee
	}
}
