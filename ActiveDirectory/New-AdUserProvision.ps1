param (
	[Parameter(Mandatory, ValueFromPipelineByPropertyname)]
	[ValidateNotNullOrEmpty()]
	[string]$FirstName,
	
	[Parameter(Mandatory, ValueFromPipelineByPropertyname)]
	[ValidateNotNullOrEmpty()]
	[string]$LastName,
	
	[Parameter(Mandatory, ValueFromPipelineByPropertyname)]
	[ValidateNotNullOrEmpty()]
	[string]$MiddleInitial,
	
	[Parameter(Mandatory, ValueFromPipelineByPropertyname)]
	[ValidateNotNullOrEmpty()]
	[string]$Department,
	
	[Parameter(Mandatory, ValueFromPipelineByPropertyname)]
	[ValidateNotNullOrEmpty()]
	[string]$Title,
	
	[Parameter(ValueFromPipelineByPropertyname)]
	[ValidateNotNullOrEmpty()]
	[string]$Location = 'OU=Corporate Users',
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$DefaultGroup = 'XYZCompany',
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$DefaultPassword = 'p@$$w0rd12345',
	
	[Parameter()]
	[ValidateScript({ Test-Path -Path $_ })]
	[string]$BaseHomeFolderPath = '\\MEMBERSRV1\Users'
)

## Find the distinguished name of the domain the current computer is a part of.
$DomainDn = (Get-AdDomain).DistinguishedName
## Define the 'standard' username (first initial and last name)
$Username = "$($FirstName.SubString(0, 1))$LastName"

#region Check if an existing user already has the first initial/last name username taken
Write-Verbose -Message "Checking if [$($Username)] is available"
if (Get-ADUser -Filter "Name -eq '$Username'")
{
	Write-Warning -Message "The username [$($Username)] is not available. Checking alternate..."
	## If so, check to see if the first initial/middle initial/last name is taken.
	$Username = "$($FirstName.SubString(0, 1))$MiddleInitial$LastName"
	if (Get-ADUser -Filter "Name -eq '$Username'")
	{
		throw "No acceptable username schema could be created"
	}
	else
	{
		Write-Verbose -Message "The alternate username [$($Username)] is available."
	}
}
else
{
	Write-Verbose -Message "The username [$($Username)] is available"
}
#endregion

#region Ensure the OU the user's going into exists
$ouDN = "$Location,$DomainDn"
if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouDN'"))
{
	throw "The user OU [$($ouDN)] does not exist. Can't add a user there"
}
#endregion

#region Ensure the group the user's going into exists
if (-not (Get-ADGroup -Filter "Name -eq '$DefaultGroup'"))
{
	throw "The group [$($DefaultGroup)] does not exist. Can't add the user into this group."
}
if (-not (Get-ADGroup -Filter "Name -eq '$Department'"))
{
	throw "The group [$($Department)] does not exist. Can't add the user to this group."
}
#endregion

#region Ensure the home folder to create doesn't already exist
$homeFolderPath = "$BaseHomeFolderPath\$UserName"
if (Test-Path -Path $homeFolderPath)
{
	throw "The home folder path [$homeFolderPath] already exists."
}
#endregion

#region Create the new user
$NewUserParams = @{
	'UserPrincipalName' = $Username
	'Name' = $Username
	'GivenName' = $FirstName
	'Surname' = $LastName
	'Title' = $Title
	'Department' = $Department
	'SamAccountName' = $Username
	'AccountPassword' = (ConvertTo-SecureString $DefaultPassword -AsPlainText -Force)
	'Enabled' = $true
	'Initials' = $MiddleInitial
	'Path' = "$Location,$DomainDn"
	'ChangePasswordAtLogon' = $true
}
Write-Verbose -Message "Creating the new user account [$($Username)] in OU [$($ouDN)]"
New-AdUser @NewUserParams
#endregion

#region Add user to groups
Write-Verbose -Message "Adding the user account [$($Username)] to the group [$($DefaultGroup)]"
Add-ADGroupMember -Members $Username -Identity $DefaultGroup
Write-Verbose -Message "Adding the user account [$($Username)] to the group [$($Department)]"
Add-ADGroupMember -Members $Username -Identity $Department
#endregion

#region Create the home folder
Write-Verbose -message "Creating the home folder [$homeFolderPath]..."
$null = mkdir $homeFolderPath
#endregion