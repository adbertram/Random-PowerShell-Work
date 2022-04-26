<#PSScriptInfo

.VERSION 1.11

.GUID fe3d3698-52fc-40e8-a95c-bbc67a507ed1

.AUTHOR Adam Bertram

.COMPANYNAME Adam the Automator, LLC

.COPYRIGHT 

.DESCRIPTION This script tests various registry values to see if the local computer is pending a reboot.

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES

.SYNOPSIS
	This script tests various registry values to see if the local computer is pending a reboot
.NOTES
	Inspiration from: https://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542
.EXAMPLE
	PS> Test-PendingReboot -ComputerName localhost
	
	This example checks various registry values to see if the local computer is pending a reboot.
#>
[CmdletBinding()]
param(
    # ComputerName is optional. If not specified, localhost is used.
    [ValidateNotNullOrEmpty()]
    [string[]]$ComputerName,
	
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [pscredential]$Credential
)

$ErrorActionPreference = 'Stop'

$scriptBlock = {
    if ($null -ne $using) {
        # $using is only available if this is being called with a remote session
        $VerbosePreference = $using:VerbosePreference
    }

    function Test-RegistryKey {
        [OutputType('bool')]
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Key
        )
    
        $ErrorActionPreference = 'Stop'

        if (Get-Item -Path $Key -ErrorAction Ignore) {
            $true
        }
    }

    function Test-RegistryValue {
        [OutputType('bool')]
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Key,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Value
        )
    
        $ErrorActionPreference = 'Stop'

        if (Get-ItemProperty -Path $Key -Name $Value -ErrorAction Ignore) {
            $true
        }
    }

    function Test-RegistryValueNotNull {
        [OutputType('bool')]
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Key,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Value
        )
    
        $ErrorActionPreference = 'Stop'

        if (($regVal = Get-ItemProperty -Path $Key -Name $Value -ErrorAction Ignore) -and $regVal.($Value)) {
            $true
        }
    }

    # Added "test-path" to each test that did not leverage a custom function from above since
    # an exception is thrown when Get-ItemProperty or Get-ChildItem are passed a nonexistant key path
    $tests = @(
        { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' }
        { Test-RegistryKey -Key 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress' }
        { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' }
        { Test-RegistryKey -Key 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending' }
        { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting' }
        { Test-RegistryValueNotNull -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations' }
        { Test-RegistryValueNotNull -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations2' }
        { 
            # Added test to check first if key exists, using "ErrorAction ignore" will incorrectly return $true
            'HKLM:\SOFTWARE\Microsoft\Updates' | Where-Object { test-path $_ -PathType Container } | ForEach-Object {
                if(Test-Path "$_\UpdateExeVolatile" ){ 
                    (Get-ItemProperty -Path $_ -Name 'UpdateExeVolatile' | Select-Object -ExpandProperty UpdateExeVolatile) -ne 0 
                }else{ 
                    $false 
                }
            }
        }
        { Test-RegistryValue -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' -Value 'DVDRebootSignal' }
        { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttempts' }
        { Test-RegistryValue -Key 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon' -Value 'JoinDomain' }
        { Test-RegistryValue -Key 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon' -Value 'AvoidSpnSet' }
        {
            # Added test to check first if keys exists, if not each group will return $Null
            # May need to evaluate what it means if one or both of these keys do not exist
            ( 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' | Where-Object { test-path $_ } | % { (Get-ItemProperty -Path $_ ).ComputerName } ) -ne 
            ( 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' | Where-Object { Test-Path $_ } | % { (Get-ItemProperty -Path $_ ).ComputerName } )
        }
        {
            # Added test to check first if key exists
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending' | Where-Object { 
                (Test-Path $_) -and (Get-ChildItem -Path $_) } | ForEach-Object { $true }
        }
    )

    foreach ($test in $tests) {
        Write-Verbose "Running scriptblock: [$($test.ToString())]"
        if (& $test) {
            $true
            break
        }
    }
}

# if ComputerName was not specified, then use localhost 
# to ensure that we don't create a Session.
if ($null -eq $ComputerName) {
    $ComputerName = "localhost"
}

foreach ($computer in $ComputerName) {
    try {
        $connParams = @{
            'ComputerName' = $computer
        }
        if ($PSBoundParameters.ContainsKey('Credential')) {
            $connParams.Credential = $Credential
        }

        $output = @{
            ComputerName    = $computer
            IsPendingReboot = $false
        }

        if ($computer -in ".", "localhost", $env:COMPUTERNAME ) {        
            if (-not ($output.IsPendingReboot = Invoke-Command -ScriptBlock $scriptBlock)) {
                $output.IsPendingReboot = $false
            }
        }
        else {
            $psRemotingSession = New-PSSession @connParams
        
            if (-not ($output.IsPendingReboot = Invoke-Command -Session $psRemotingSession -ScriptBlock $scriptBlock)) {
                $output.IsPendingReboot = $false
            }
        }
        [pscustomobject]$output
    } catch {
        Write-Error -Message $_.Exception.Message
    } finally {
        if (Get-Variable -Name 'psRemotingSession' -ErrorAction Ignore) {
            $psRemotingSession | Remove-PSSession
        }
    }
}
