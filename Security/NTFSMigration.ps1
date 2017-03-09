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
                Write-Log -Line $_
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

function Write-Log
{
    [OutputType([void])]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Line
    )
    
    $logLineParams = @{}

    ## Attempt to find the file/folder path from the line
    $m = [regex]::Match($Line,'\\(.*)$')
    if (-not $m.Success) {
        $logLineParams.Path = $Line
        $logLineParams.Severity = 'Warning'
    } else {
        $fullPath = $m.Groups[1].Value
        $logLineParams.Path = $fullPath
        
        ## Figure out if the path is a file or folder
        if (($fullPath | Split-Path -Leaf) -match '\.\w+$') {
            $logLineParams.Type = 'File'
        } else {
            $logLineParams.Type = 'Folder'
        }
        
        if ($Line -notmatch '(^processed file)|(^Successfully processed)') {
            $logLineParams.Severity = 'Error'
        }
    }
    
    Write-LogLine @logLineParams

}

function Write-LogLine
{
    [OutputType([void])]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Type,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Information','Warning','Error')]
        [string]$Severity = 'Information',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LogFilePath = 'C:\PermissionLog.txt'
    )

    $obj = [pscustomobject]@{
        Path = $Path
        Severity = $Severity
        Type = $Type
    }
    $obj | Export-Csv -Path $LogFilePath -Append -NoTypeInformation

}