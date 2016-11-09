#requires -Module Pester

function Start-PesterTest
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Module,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Unit','Integration','Acceptance')]
        [string]$Type,

        [Parameter()]
        [string]$TestName,

        [Parameter()]
        [hashtable]$AdditionalParams
    )
    begin
    {
        $ErrorActionPreference = 'Stop'
    }
    process
    {
        try
        {
            if (-not ($testScript = Find-TestScript -Module $Module -Type $Type)) {
                throw "Could not find $Type test script for the [$($Module)] module."
            } else {
                $invPestParams = @{
                    Path = $testScript.FullName
                }
                if ($PSBoundParameters.ContainsKey('InvokePesterParams'))
                {
                    $invPestParams += $AdditionalParams
                }
                if ($PSBoundParameters.ContainsKey('TestName'))
                {
                    $invPestParams.TestName = $TestName
                }
                Invoke-Pester @invPestParams

                $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Invoke-Pester', [System.Management.Automation.CommandTypes]::Function)
                $scriptCmd = { & $wrappedCmd @invPestParams }
                $steppablePipeline = $scriptCmd.GetSteppablePipeline()
                $steppablePipeline.Begin($PSCmdlet)
            }
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Find-TestScript
{
    [OutputType([System.IO.FileInfo])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Module,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Unit','Integration','Acceptance')]
        [string]$Type
    )
    
    Get-ChildItem -Path 'C:\Program Files\WindowsPowerShell\Modules' -Filter "$Module.$Type.Tests.ps1"
}

function Start-UnitTest
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Module,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$TestName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [hashtable]$AdditionalParams
    )
    $params = @{
        Module = $Module
        Type = 'Unit'
        TestName = $TestName
        InvokePesterParams = $AdditionalParams
    }
    Start-PesterTest @params
}

function Start-IntegrationTest
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Module,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$TestName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [hashtable]$AdditionalParams
    )
    $params = @{
        Module = $Module
        Type = 'Integration'
        TestName = $TestName
        InvokePesterParams = $AdditionalParams
    }
    Start-PesterTest @params
}

function Start-AcceptanceTest
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Module,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$TestName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [hashtable]$AdditionalParams
    )
    $params = @{
        Module = $Module
        Type = 'Acceptance'
        TestName = $TestName
        InvokePesterParams = $AdditionalParams
    }
    Start-PesterTest @params
}