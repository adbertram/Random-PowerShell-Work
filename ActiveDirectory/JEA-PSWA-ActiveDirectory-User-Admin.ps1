#region Prep work
$PswaServerName = 'PSWA'
$DomainControllerName = 'LABDC'
$JeaRoleName = 'ADUserManager'
$AdGroupName = 'ADUserManagers'
$DomainName = 'lab.local'

## Run this on $DomainControllerName

New-ADGroup -Name ADUserManagers -GroupScope DomainLocal

## Add any applicable users to the group
# Add-ADGroupMember -Identity ADUserManagers -Members XXXXX

#endregion

#region JEA Setup

#region Create the script that users will run to create new AD users
$functionText =  "@
#requires -Module ActiveDirectory

function New-User {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]`$FirstName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]`$LastName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({
				`$deps = 'Accounting', 'Information Services'
				if (`$_ -notin `$deps) {
					throw `"You have used an invalid department name. Choose from the following: `$(`$deps -join ', ').`"
            } else {
                `$true
            }
        })]
        [string]`$Department,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]`$DomainName = 'lab.local'
    )

    `$userName = '{0}{1}' -f `$FirstName.Substring(0,1),`$LastName
    if (Get-AdUser -Filter `"samAccountName -eq '`$userName'`") {
        Write-Host `"The username [`$(`$userName)] already exists.`" -ForegroundColor Red
    } elseif (-not (Get-ADOrganizationalUnit -Filter `"Name -eq '`$Department'`")) {
        Write-Host `"The Active Directory OU for department [`$(`$Department)] could not be found.`" -ForegroundColor Red
    } else {
        `$password = [System.Web.Security.Membership]::GeneratePassword((Get-Random -Minimum 20 -Maximum 32), 3)
        `$secPw = ConvertTo-SecureString -String `$password -AsPlainText -Force

        `$ouPath = 'OU={0}, DC={1}, DC={2}' -f `$Department,`$DomainName.Split('.')[0],`$DomainName.Split('.')[1]
        `$newUserParams = @{
            GivenName = `$FirstName
            Surname = `$LastName
            Name = `$userName
            AccountPassword = `$secPw
            ChangePasswordAtLogon = `$true
            Enabled = `$true
            Department = `$Department
            Path = `$ouPath
        }

        New-AdUser @newUserParams
    }
}
@"

Set-Content -Path C:\AdUserInitScript.ps1 -Value $functionText
#endregion

# Create a folder for the module
$modulePath = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules\$JeaRoleName"
$null = New-Item -ItemType Directory -Path $modulePath

# Create an empty script module and module manifest. At least one file in the module folder must have the same name as the folder itself.
$null = New-Item -ItemType File -Path (Join-Path $modulePath "$JeaRoleName.psm1")
New-ModuleManifest -Path (Join-Path $modulePath "$JeaRoleName.psd1") -RootModule "$JeaRoleName.psm1"

# Create the RoleCapabilities folder and copy in the PSRC file
$rcFolder = Join-Path $modulePath "RoleCapabilities"
$null = New-Item -ItemType Directory $rcFolder

$rcCapFilePath = Join-Path -Path $rcFolder -ChildPath "$JeaRoleName.psrc"
$roleCapParams = @{
	Path             = $rcCapFilePath
	VisibleFunctions = 'New-User'
	ModulesToImport  = 'ActiveDirectory'
	AssembliesToLoad = 'System.Web'
	VisibleCmdlets   = 'ConvertTo-SecureString', @{
		Name       = 'New-Aduser'
		Parameters = @{ Name = 'GivenName' },
		@{ Name = 'SurName' },
		@{ Name = 'Name' },
		@{ Name = 'AccountPassword' },
		@{ Name = 'ChangePasswordAtLogon' },
		@{ Name = 'Enabled' },
		@{ Name = 'Department' },
		@{ Name = 'Path' }
	},
	@{
		Name       = 'Get-AdUser'
		Parameters = @{
			Name = 'Filter'
		}
	},
	@{
		Name       = 'Set-Aduser'
		Parameters = @{ Name = 'GivenName' },
		@{ Name = 'SurName' },
		@{ Name = 'Name' },
		@{ Name = 'ChangePasswordAtLogon' },
		@{ Name = 'Department' }
	}
}
New-PSRoleCapabilityFile @roleCapParams

$sessionFilePath = Join-Path -Path $rcFolder -ChildPath "$JeaRoleName.pssc"
$params = @{
	SessionType         = 'RestrictedRemoteServer'
	Path                = $sessionFilePath
	RunAsVirtualAccount = $true
	ScriptsToProcess    = 'C:\AdUserInitScript.ps1'
	RoleDefinitions     = @{ 'LAB\ADUserManagers' = @{ RoleCapabilities = $JeaRoleName } }
}

New-PSSessionConfigurationFile @params

if (-not (Test-PSSessionConfigurationFile -Path $sessionFilePath)) {
	throw 'Failed session configuration file test.'
}

Register-PSSessionConfiguration -Path $sessionFilePath -Name $JeaRoleName -Force


## Test JEA
$nonAdminCred = Get-Credential -Message 'Input user credential to test JEA.'
Invoke-Command -ComputerName $DomainControllerName -ScriptBlock { New-User -FirstName 'Adam' -LastName 'Bertram' -Department 'Information Services' }

#endregion

#region PowerShell Web Access Setup
Add-WindowsFeature -Name WindowsPowerShellWebAccess
Install-PswaWebApplication –UseTestCertificate
Add-PswaAuthorizationRule –ComputerName $DomainControllerName –UserGroupName "$DomainName\$AdGroupName" –ConfigurationName $JeaRoleName
#endregion