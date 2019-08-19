
<#PSScriptInfo

.VERSION 1.6

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
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ComputerName,
	
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [pscredential]$Credential
)

<<<<<<< HEAD
$ErrorActionPreference = 'Stop'

$scriptBlock = {
    function Test-RegistryKey {
        [OutputType('bool')]
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Key
        )
=======
    ## This is the scriptblock that's run on all servers
    $remoteScriptblock = {

        function Test-RegistryKey {
            [OutputType('bool')]
            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [string]$Key
            )
>>>>>>> dcce019b814013fc8a33b17fd7f2b8a92a5251ce
    
            $ErrorActionPreference = 'Stop'

<<<<<<< HEAD
        if (Get-Item -Path $Key -ErrorAction Ignore) {
            $true
=======
            if (Get-Item -Path $Key -ErrorAction Ignore) {
                $true
            }
>>>>>>> dcce019b814013fc8a33b17fd7f2b8a92a5251ce
        }

<<<<<<< HEAD
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
=======
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
>>>>>>> dcce019b814013fc8a33b17fd7f2b8a92a5251ce
    
            $ErrorActionPreference = 'Stop'

<<<<<<< HEAD
        if (Get-ItemProperty -Path $Key -Name $Value -ErrorAction Ignore) {
            $true
=======
            if (Get-ItemProperty -Path $Key -Name $Value -ErrorAction Ignore) {
                $true
            }
>>>>>>> dcce019b814013fc8a33b17fd7f2b8a92a5251ce
        }

<<<<<<< HEAD
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
=======
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
>>>>>>> dcce019b814013fc8a33b17fd7f2b8a92a5251ce
    
            $ErrorActionPreference = 'Stop'

<<<<<<< HEAD
        if (($regVal = Get-ItemProperty -Path $Key -Name $Value -ErrorAction Ignore) -and $regVal.($Value)) {
            $true
=======
            if (($regVal = Get-ItemProperty -Path $Key -Name $Value -ErrorAction Ignore) -and $regVal.($Value)) {
                $true
            }
>>>>>>> dcce019b814013fc8a33b17fd7f2b8a92a5251ce
        }

        $tests = @(
            { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' }
            { Test-RegistryKey -Key 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress' }
            { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' }
            { Test-RegistryKey -Key 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending' }
            { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting' }
            { Test-RegistryValueNotNull -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations' }
            { Test-RegistryValueNotNull -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations2' }
            {
                (Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Updates') -and 
                (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Updates' -Name 'UpdateExeVolatile' -ErrorAction Ignore | Select-Object -ExpandProperty UpdateExeVolatile) -ne 0
            }
            { Test-RegistryValue -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' -Value 'DVDRebootSignal' }
            { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttemps' }
            { Test-RegistryValue -Key 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon' -Value 'JoinDomain' }
            { Test-RegistryValue -Key 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon' -Value 'AvoidSpnSet' }
            {
                (Test-RegistryValue -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName' -Value 'ActiveComputerName') -and
                (Test-RegistryValue -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName' -Value 'ComputerName') -and
                (
                    (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName' -Name 'ActiveComputerName').ActiveComputerName -ne
                    (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName' -Name 'ActiveComputerName').ComputerName
                )
            }
            {
                $knownFalsePositiveGuids = @('117cab2d-82b1-4b5a-a08c-4d62dbee7782')
                if (Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending' | Where-Object { $_.PSChildName -notin $knownfalsepositiveguids }) {
                    $true
                }
            }
        )

        foreach ($test in $tests) {
            if (& $test) {
                $true
                return
            }
        }
<<<<<<< HEAD
    )

    foreach ($test in $tests) {
        if (& $test) {
            $true
            break
        }
=======
        ## Return false if it hasn't returned yet
        $false
>>>>>>> dcce019b814013fc8a33b17fd7f2b8a92a5251ce
    }
}

foreach ($computer in $ComputerName) {
    try {
        $connParams = @{
<<<<<<< HEAD
            'ComputerName' = $computer
=======
            'ComputerName' = $ComputerName
>>>>>>> dcce019b814013fc8a33b17fd7f2b8a92a5251ce
        }
        if ($PSBoundParameters.ContainsKey('Credential')) {
            $connParams.Credential = $Credential
        }

<<<<<<< HEAD
        $output = @{
            ComputerName    = $computer
            IsPendingReboot = $false
        }

        $psRemotingSession = New-PSSession @connParams
        
        if (-not ($output.IsPendingReboot = Invoke-Command -Session $psRemotingSession -ScriptBlock $scriptBlock)) {
            $output.IsPendingReboot = $false
=======
        $results = Invoke-Command @connParams -ScriptBlock $remoteScriptblock
        foreach ($result in $results) {
            $output = @{
                ComputerName    = $result.PSComputerName
                IsPendingReboot = $result
            }
            [pscustomobject]$output
>>>>>>> dcce019b814013fc8a33b17fd7f2b8a92a5251ce
        }
        [pscustomobject]$output
    } catch {
        Write-Error -Message $_.Exception.Message
    }
}
