<#
.SYNOPSIS
Tests credentials by validating a user's username and password against a domain or local machine account.

.DESCRIPTION
The Test-UserAccountPassword function validates a user's credentials (username and password) against either a specified 
domain or the local machine's user accounts. This is useful for verifying if a username and password combination is correct 
without logging into the user's account.

.PARAMETER UserName
Specifies the username of the account to test the credentials against. This parameter is mandatory.

.PARAMETER Password
Specifies the password of the user in a secure string format. This parameter is mandatory and does not accept plain text 
passwords to ensure security.

.PARAMETER DomainName
Optional. Specifies the domain name to validate the credentials against. If not provided, it defaults to the local machine. 
Provide a period (.) to explicitly specify the local machine.

.EXAMPLE
$securePassword = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
Test-UserAccountPassword -UserName "exampleUser" -Password $securePassword -DomainName "DOMAIN"

This example shows how to test the credentials of 'exampleUser' on domain 'DOMAIN' using a secure string password.

.NOTES
Ensure that the function is run with appropriate permissions, especially when accessing domain-based credentials.
Requires the System.DirectoryServices.AccountManagement assembly to perform the credential checks.
#>

function Test-UserAccountPassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$UserName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [securestring]$Password,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DomainName
    )

    function decryptPassword {
        param(
            [securestring]$Password
        )
        try {
            $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
            [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        } finally {
            ## Clear the decrypted password from memory
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }
    }

    try {
        Add-Type -AssemblyName System.DirectoryServices.AccountManagement

        if ($PSBoundParameters.ContainsKey('DomainName') -and $DomainName -ne '.') {
            $context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $DomainName)
        } else {
            $context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine)
        }
    
        $context.ValidateCredentials($UserName, (decryptPassword($Password)))
    } catch {
        throw $_
    } finally {
        if ($context) {
            $context.Dispose()
        }
    }
}
