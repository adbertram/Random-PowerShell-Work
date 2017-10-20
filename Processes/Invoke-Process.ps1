<#PSScriptInfo

.VERSION 1.4

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
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$FilePath,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ArgumentList
	)

	$ErrorActionPreference = 'Stop'

	try {
		$stdOutTempFile = "$env:TEMP\$((New-Guid).Guid)"
		$stdErrTempFile = "$env:TEMP\$((New-Guid).Guid)"

		$startProcessParams = @{
			FilePath               = $FilePath
			ArgumentList           = $ArgumentList
			RedirectStandardError  = $stdErrTempFile
			RedirectStandardOutput = $stdOutTempFile
			Wait                   = $true;
			PassThru               = $true;
			NoNewWindow            = $true;
		}
		if ($PSCmdlet.ShouldProcess("Process [$($FilePath)]", "Run with args: [$($ArgumentList)]")) {
			$cmd = Start-Process @startProcessParams
			$cmdOutput = Get-Content -Path $stdOutTempFile -Raw
			$cmdError = Get-Content -Path $stdErrTempFile -Raw
			if ($cmd.ExitCode -ne 0) {
				if ($cmdError) {
					throw $cmdError.Trim()
				}
				if ($cmdOutput) {
					throw $cmdOutput.Trim()
				}
			} else {
				if ([string]::IsNullOrEmpty($cmdOutput) -eq $false) {
					Write-Output -InputObject $cmdOutput
				}
			}
		}
	} catch {
		$PSCmdlet.ThrowTerminatingError($_)
	} finally {
		Remove-Item -Path $stdOutTempFile, $stdErrTempFile -Force -ErrorAction Ignore
	}
}

