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
			RedirectStandardError  = $stdErrTempFile.FullName
			RedirectStandardOutput = $stdOutTempFile.FullName
			Wait                   = $true;
			PassThru               = $true;
			NoNewWindow            = $true;
		}
		if ($PSCmdlet.ShouldProcess("Process [$($FilePath)]", "Run with args: [$($ArgumentList)]")) {
			$cmd = Start-Process @startProcessParams
			$cmdOutput = Get-Content -Path $stdOutTempFile.FullName -Raw
			$cmdError = Get-Content -Path $stdErrTempFile.FullName -Raw
			if ([string]::IsNullOrEmpty($cmdOutput) -eq $false) {
				Write-Output -InputObject $cmdOutput
			}
			if ($cmd.ExitCode -ne 0) {
				throw $cmdError.Trim()
			}	
		}
	} catch {
		$PSCmdlet.ThrowTerminatingError($_)
	} finally {
		Remove-Item -Path $stdOutTempFile, $stdErrTempFile -Force
	}
}
