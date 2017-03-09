<#PSScriptInfo
	VERSION 1.0
	GUID 774b207b-ca23-4163-9a26-abe911368cdd
	AUTHOR Adam Bertram
	COMPANYNAME Adam the Automator, LLC
	COPYRIGHT
	TAGS
	LICENSEURI
	PROJECTURI
	ICONURI
	EXTERNALMODULEDEPENDENCIES
	REQUIREDSCRIPTS
	EXTERNALSCRIPTDEPENDENCIES
	RELEASENOTES
#>


<#
    .DESCRIPTION
        ICacls is a module made up of a few functions to assist in using this helpful, yet overly complicated tool.
        It is best used when performing data migrations. Using the Save-Acl and Restore-Acl functions allows you to easily
        point to a entire folder to first save all ACEs to a file and then use that file to restore all of those same
        ACEs to the files copied in the other location.
#>

param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [string]$FolderPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ -not (Test-Path -Path $_ -PathType Leaf) })]
    [string]$SaveFilePath
)

$errorsLogFilePath = 'C:\PermissionErrors.txt'

function Save-Acl
{
    <#
        .SYNOPSIS
            This function uses icacls to recursively retrieves all permissions from all files and folders in a particular 
            folder path and saves them to a text file.
    
        .EXAMPLE
            PS> Save-Acl -FolderPath \\FILESERVER\FileShare -SaveFilePath C:\FileSharePermissions.txt
    
    #>
    [OutputType([void])]
    [CmdletBinding()]
    param
    (   
        [Parameter(Mandatory)]
        [string]$FolderPath,

        [Parameter(Mandatory)]
        [string]$SaveFilePath
    )
    begin
    {
        $ErrorActionPreference = 'Continue'
    }
    process
    {
        try
        {
            Invoke-ICacls @PSBoundParameters | ForEach-Object {
                Write-Output $_
            }
            if (-not (Get-Content -Path $errorsLogFilePath)) {
                Remove-Item -Path $errorsLogFilePath
            }
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Restore-Acl
{
    [OutputType()]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string]$RestoreToFolderPath,

        [Parameter(Mandatory)]
        [string]$PermissionFilePath
    )

    Invoke-ICacls -FolderPath $RestoreToFolderPath -RestoreFilePath $PermissionFilePath
    
}

function Invoke-ICacls
{
    [OutputType()]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]$FolderPath,

        [Parameter(ParameterSetName = 'Save')]
        [string]$SaveFilePath,

        [Parameter(ParameterSetName = 'Restore')]
        [string]$RestoreFilePath
    )

    if ($PSCmdlet.ParameterSetName -eq 'Save') {
        icacls $FolderPath /save "$SaveFilePath" /t /c 2>$errorsLogFilePath
    } elseif ($PSCmdlet.ParameterSetName -eq 'Restore') {
        icacls $FolderPath /restore "$RestoreFilePath" /c 2>$errorsLogFilePath
    }   
}