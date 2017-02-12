<#
    .SYNOPSIS
        This is a Pester test script meant to perform a series of checks on proprietary scripts and modules to ensure
        it does not contains any company-specific information. It is to be used as a final gate between private scripts/modules
        before sharing with the community.

    .EXAMPLE
        PS> $params = @{
                Script = @{
                Path = 'C:\Community.Tests.ps1'
                ScriptFilePath = 'C:\PathToScriptToTest.ps1'
                CompanyReference = 'Acme Corporation'
            }
        PS> Invoke-Pester @params
        
        This example invokes Pester using this community test script to run tests against a company-specific script.

    .PARAMETER ScriptFilePath
         A mandatory string parameter representing a single script or module file path. This must exist or an exception will be thrown.

    .PARAMETER TestsFilePath
         A optional string parameter representing the file path to the associated Pester script for the module/script.

    .PARAMETER CompanyReference
         An optional parameter representing one or more strings separated by a comma that represent any company-specific strings
         that need to be removed prior to community sharing.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [string]$FolderPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$CompanyReference
)

$defaultCommandNames = (Get-Command -Module 'Microsoft.PowerShell.*','Pester' -All).Name
$defaultModules = (Get-Module -Name 'Microsoft.PowerShell.*','Pester').Name

if ($scripts = Get-ChildItem -Path $FolderPath -Recurse -Filter '*.ps*' | Sort-Object Name) {
    $scripts | foreach({
        $script = $_.FullName
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script,[ref]$null,[ref]$null)
        $commandRefs = $ast.FindAll({$args[0] -is [System.Management.Automation.Language.CommandAst]},$true)
        if ($testRefs = (Select-String -path $script -Pattern "mock [`"|'](.*)[`"|']").Matches) {
            $commandRefsInTest = $testRefs | foreach {
                $_.Groups[1].Value
            }
        }

        $script:commandRefNames += (@($commandRefs).foreach({ [string]$_.CommandElements[0] }) | Select-Object -Unique) + $commandRefsInTest
        $script:commandDeclarationNames += $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) | Select-Object -ExpandProperty Name
        
        describe "[$($script)] Test" {

            if ($CompanyReference) {
                $companyRefRegex = ('({0})' -f ($CompanyReference -join '|'))
                if ($companyReferences = [regex]::Matches((Get-Content $script -Raw),$companyRefRegex).Groups) {
                    $companyReferences = $companyReferences.Groups[1].Value
                }
            }

            $properties = @(
                @{
                    Name = 'Command'
                    Expression = { $alias = Get-Alias -Name $_ -ErrorAction Ignore
                        if ($alias) {
                            $alias.ResolvedCommandName
                        } else {
                            $_
                        }
                    }
                }
            )

            $privateCommandNames = $script:commandRefNames | Select-Object -Property $properties | Where {
                $_.Command -notin $defaultCommandNames -and 
                $_.Command -notin $commandDeclarationNames -and
                $_.Command -match '^\w' -and
                $_.Command -notmatch 'powershell_ise\.exe'
            } | Select-Object -ExpandProperty Command

            if ($privateModuleNames = (Select-String -Path $script -Pattern "($($defaultModules -join '|'))" -NotMatch).Matches) {
                $privateModuleNames = $privateModuleNames.Group[1].Value
            }
            
            it 'has no references to our company-specific strings' {
                $companyReferences | should benullOrempty
            }

            it 'has no references to private functions' {
                $privateCommandNames | should be $null
            }

            it 'has no references to private modules' {
                $privateModuleNames | should benullOrempty
            }
        }
    })
}