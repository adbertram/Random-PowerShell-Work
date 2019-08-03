
<#PSScriptInfo

.VERSION 1.5

.GUID fe3d3698-52fc-40e8-a95c-bbc67a507ed1

.AUTHOR Adam Bertram

.COMPANYNAME Adam the Automator, LLC

.COPYRIGHT 

.DESCRIPTION This function tests various registry values to see if the local computer is pending a reboot.

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES

.SYNOPSIS
	This function tests various registry values to see if the local computer is pending a reboot
.NOTES
	Inspiration from: https://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542
.EXAMPLE
	PS> Test-PendingReboot
	
	This example checks various registry values to see if the local computer is pending a reboot.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ComputerName,
	
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [pscredential]$Credential
)
begin {
    $ErrorActionPreference = 'Stop'

    function Test-RegistryKey {
        [OutputType('bool')]
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Key,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [System.Management.Automation.Runspaces.PSSession]$Session
        )
    
        $ErrorActionPreference = 'Stop'

        Invoke-Command -Session $Session -ScriptBlock {
            if (Get-Item -Path $using:Key -ErrorAction Ignore) {
                $true
            }
        }
    }

    function Test-RegistryValue {
        [OutputType('bool')]
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [System.Management.Automation.Runspaces.PSSession]$Session,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Key,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Value
        )
    
        $ErrorActionPreference = 'Stop'

        Invoke-Command -Session $Session -ScriptBlock {
            if (Get-ItemProperty -Path $using:Key -Name $using:Value -ErrorAction Ignore) {
                $true
            }
        }
    }

    function Test-RegistryValueNotNull {
        [OutputType('bool')]
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [System.Management.Automation.Runspaces.PSSession]$Session,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Key,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Value
        )
    
        $ErrorActionPreference = 'Stop'

        Invoke-Command -Session $Session -ScriptBlock {
            if (($regVal = Get-ItemProperty -Path $using:Key -Name $using:Value -ErrorAction Ignore) -and $regVal.($using:Value)) {
                $true
            }
        }
    }

    $tests = @(
        { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' }
        { Test-RegistryKey -Key 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress' }
        { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' }
        { Test-RegistryKey -Key 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending' }
        { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting' }
        { Test-RegistryValueNotNull -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations' }
        { Test-RegistryValueNotNull -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations2' }
        { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Updates' -Name 'UpdateExeVolatile' -ErrorAction Ignore | Select-Object -ExpandProperty UpdateExeVolatile) -ne 0 }
        { Test-RegistryValue -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' -Value 'DVDRebootSignal' }
        { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttemps' }
        { Test-RegistryValue -Key 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon' -Value 'JoinDomain' }
        { Test-RegistryValue -Key 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon' -Value 'AvoidSpnSet' }
        {
            (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName' -Name 'ActiveComputerName').ActiveComputerName -ne
            (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName' -Name 'ActiveComputerName').ComputerName
        }
        {
            if (Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending') {
                $true
            }
        }
    )
}
process {
    try {
        foreach ($computer in $ComputerName) {
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

            $psRemotingSession = New-PSSession @connParams
            
            foreach ($test in $tests) {
                if (& $test) {
                    $output.IsPendingReboot = $true
                }
                [pscustomobject]$output
            }
        }
    } catch {
        Write-Error -Message $_.Exception.Message
    } finally {
        $psRemotingSession | Remove-PSSession
    }
}