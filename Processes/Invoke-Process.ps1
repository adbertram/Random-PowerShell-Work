<#PSScriptInfo

.VERSION 2.0

.GUID b787dc5d-8d11-45e9-aeef-5cf3a1f690de

.AUTHOR Adam Bertram

.COMPANYNAME Adam the Automator, LLC

.TAGS Processes

#>

<# 

.DESCRIPTION 
 	Invoke-Process is a simple wrapper function that aims to "PowerShellyify" launching typical external processes. There
	are lots of ways to invoke processes in PowerShell with Start-Process, Invoke-Expression, & and others but none account
	well for the various streams and exit codes that an external process returns. Also, it's hard to write good tests
	when launching external proceses.

	This function ensures any errors are sent to the error stream, standard output is sent via the Output stream and any
	time the process returns an exit code other than 0, treat it as an error.

#> 
param()

function Invoke-Process {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,
        [string[]]$ArgumentList
    )

    $ErrorActionPreference = 'Stop'

    try {
        $stdOutTempFile = "$env:TEMP\$(( New-Guid ).Guid)"
        $stdErrTempFile = "$env:TEMP\$(( New-Guid ).Guid)"

        $startProcessParams = @{
            FilePath               = $FilePath
            RedirectStandardError  = $stdErrTempFile
            RedirectStandardOutput = $stdOutTempFile
            Wait                   = $true
            PassThru               = $true
            NoNewWindow            = $true
        }
        if ($PSCmdlet.ShouldProcess("Process [$($FilePath)]", "Run with args: [$($ArgumentList)]")) {
            if ($ArgumentList) {
                Write-Verbose -Message "$FilePath $ArgumentList"
                $cmd = Start-Process @startProcessParams -ArgumentList $ArgumentList
            }
            else {
                Write-Verbose $FilePath
                $cmd = Start-Process @startProcessParams
            }
            $stdOut = Get-Content -Path $stdOutTempFile -Raw
            $stdErr = Get-Content -Path $stdErrTempFile -Raw
            if ([string]::IsNullOrEmpty($stdOut) -eq $false) {
                $stdOut = $stdOut.Trim()
            }
            if ([string]::IsNullOrEmpty($stdErr) -eq $false) {
                $stdErr = $stdErr.Trim()
            }
            $return = [PSCustomObject]@{
                Name     = $cmd.Name
                Id       = $cmd.Id
                ExitCode = $cmd.ExitCode
                Output   = $stdOut
                Error    = $stdErr
            }
            if ($return.ExitCode -ne 0) {
                throw $return
            }
            else {
                $return
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        Remove-Item -Path $stdOutTempFile, $stdErrTempFile -Force -ErrorAction Ignore
    }
}

