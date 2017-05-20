function Get-MissingUpdates {
	[CmdletBinding()]
	[OutputType([System.Management.Automation.PSCustomObject])]
	param (
		[Parameter(Mandatory,
		ValueFromPipeline,
		ValueFromPipelineByPropertyName)]
		[string]$ComputerName
	)
	begin {
		function Get-32BitProgramFilesPath {
			if ((Get-Architecture) -eq 'x64') {
				${ env:ProgramFiles(x86) }
			} else {
				$env:ProgramFiles
			}
		}
		
		function Get-Architecture {
			if ([System.Environment]::Is64BitOperatingSystem) {
				'x64'
			} else {
				'x86'
			}
		}
		
		$Output = @{ }
	}
	process {
		try {
			
			## Remove any previous reports
			Get-ChildItem "$($Env:USERPROFILE)\SecurityScans\*" -Recurse -ea 'SilentlyContinue' | Remove-Item -Force -Recurse
			## Run the report to create the output XML
			$ExeFilePath = "$(Get-32BitProgramFilesPath)\Microsoft Baseline Security Analyzer 2\mbsacli.exe"
			if (!(Test-Path $ExeFilePath)) {
				throw "$ExeFilePath not found"
			}
			& $ExeFilePath /target $ComputerName /wi /nvc /o %C% 2>&1> $null
			## Convert the report to XML so I can use it
			ParseMbsaXml "$($Env:USERPROFILE)\SecurityScans\$($Computername.Split('.')[0]).mbsa"
		} catch {
			Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
		}
	}
}

function ParseMbsaXml
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$FilePath
	)

	[xml]$ScanResults = Get-Content -Path $FilePath

	$UpdateSeverityLabels = @{
		'0' = 'Other'
		'1' = 'Low'
		'2' = 'Moderate'
		'3' = 'Important'
		'4' = 'Critical'
	}
	
	$MissingUpdates = $ScanResults.SelectNodes("//Check[@Name='Windows Security Updates']/Detail/UpdateData[@IsInstalled='false']")
	foreach ($Update in $MissingUpdates) {
		$Ht = @{ }
		$Properties = $Update | Get-Member -Type Property
		foreach ($Prop in $Properties) {
			$Value = ($Update | select -expandproperty $Prop.Name)
			if ($Prop.Name -eq 'Severity') {
				$Value = $UpdateSeverityLabels[$Value]
			}
			$Ht[$Prop.Name] = $Value
		}
		[pscustomobject]$Ht
	}
	
}