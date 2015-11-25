#Requires -Version 4

## All required installer file names and the URLs in which they are located
$files = [ordered]@{
	'SQLSysClrTypes.msi' = 'http://go.microsoft.com/fwlink/?LinkID=239644&clcid=0x409' # Microsoft® System CLR Types for Microsoft® SQL Server® 2012 (x64)
	'SharedManagementObjects.msi' = 'http://go.microsoft.com/fwlink/?LinkID=239659&clcid=0x409' # Microsoft® SQL Server® 2012 Shared Management Objects (x64)
	'PowerShellTools.msi' = 'http://go.microsoft.com/fwlink/?LinkID=239656&clcid=0x409' # Microsoft® Windows PowerShell Extensions for Microsoft® SQL Server® 2012 (x64)
	'azure-powershell.0.9.8.msi' = 'https://github.com/Azure/azure-powershell/releases/download/v0.9.8-September2015/azure-powershell.0.9.8.msi' # Azure PowerShell module
}

function Receive-AzureSqlPrerequisites
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Path
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			if (-not (Test-Path -Path $Path -PathType Container))
			{
				Write-Verbose -Message "Creating the download folder [$($Path)]."
				$null = mkdir -Path $Path
			}
			foreach ($file in $files.GetEnumerator())
			{
				$downloadFile = (Join-Path -Path $Path -ChildPath $file.Key)
				Write-Verbose -Message "Starting download of [$($file.Key)] from [$($file.Value)]."
				Invoke-WebRequest -Uri $file.Value -OutFile $downloadFile
				if (-not (Test-Path -Path $downloadFile -PathType Leaf))
				{
					throw "The file [$($file.Key)] was not downloaded successfully."
				}
				else
				{
					Write-Verbose -Message "[$($file.Key)] was successfully downloaded."	
				}
				if ([System.IO.Path]::GetExtension($downloadFile) -eq '.msi')
				{
					Write-Verbose -Message 'Starting install.'
					Start-Process -FilePath 'msiexec.exe' -Args "/i $downloadFile /qn" -Wait
					Write-Verbose -Message 'Install complete.'
				}
				else
				{
					Write-Warning -Message "The file [$($file.Key)] is not a MSI. Non-MSI install support has not been implemented."	
				}
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Set-AzureSqlModulePath
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string[]]$Path = ('C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement', 'C:\Program Files\Microsoft SQL Server\110\Tools\PowerShell\Modules\SQLPS')
		
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			$paths = $env:PSModulePath -split ';'
			$paths += $Path
			$modulePath = $paths -join ';'
			$env:PSModulePath = $modulePath
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function New-AzureSqlFirewallRule
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.WindowsAzure.Commands.SqlDatabase.Model.SqlDatabaseServerContext]$Server,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$RuleName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$PublicIpRefUrl = 'http://myexternalip.com/raw'
			
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			## Get your client's public IP --can always to a block range if you'd like.
			$publicIp = (Invoke-WebRequest $PublicIpRefUrl).Content -replace "`n"
			
			## Create the firewall rule
			New-AzureSqlDatabaseServerFirewallRule -ServerName $Server.ServerName -RuleName $RuleName -StartIpAddress $publicIp -EndIpAddress $publicIp
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}