function Install-SqlServerCumulativeUpdate
{
	[CmdletBinding(SupportsShouldProcess)]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,
		
		[Parameter(Mandatory, ParameterSetName = 'Number')]
		[ValidateNotNullOrEmpty()]
		[int]$Number,
		
		[Parameter(Mandatory, ParameterSetName = 'Latest')]
		[ValidateNotNullOrEmpty()]
		[switch]$Latest,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$Restart
	)
	process {
		try
		{
			if (Test-PendingReboot -ComputerName $ComputerName)
			{
				throw "The computer [$($ComputerName)] is pending a reboot. Reboot the computer before proceeding."
			}
			
			## Find the current version on the computer
			$currentVersion = Get-SQLServerVersion -ComputerName $ComputerName
			
			## Find the architecture of the computer
			##TODO: ADB - This should be a function
			$arch = (Get-CimInstance -ComputerName $ComputerName -ClassName 'Win32_ComputerSystem' -Property 'SystemType').SystemType
			if ($arch -eq 'x64-based PC')
			{
				$arch = 'x64'
			}
			else
			{
				$arch = 'x86'
			}
			
			## Find the installer to use
			$params = @{
				'Architecture' = $arch
				'SqlServerVersion' = $currentVersion.MajorVersion
				'ServicePackNumber' = $currentVersion.ServicePack
			}
			if ($PSBoundParameters.ContainsKey('Number'))
			{
				$params.CumulativeUpdateNumber = $Number
			}
			elseif ($Latest.IsPresent)
			{
				$params.CumulativeUpdateNumber = (Get-LatestSqlServerCumulativeUpdateVersion -SqlServerVersion $currentVersion.MajorVersion -ServicePackNumber $currentVersion.ServicePack).CumulativeUpdate
			}
			
			if ($currentVersion.CumulativeUpdate -eq $params.CumulativeUpdateNumber)
			{
				throw "The computer [$($ComputerName)] already has the specified (or latest) cumulative update installed."
			}
			
			if (-not ($installer = Find-SqlServerCumulativeUpdateInstaller @params))
			{
				throw "Could not find installer for cumulative update [$($params.CumulativeUpdateNumber)]"
			}
			
			## Apply SP
			if ($PSCmdlet.ShouldProcess($ComputerName, "Install cumulative update [$($installer.Name)] for SQL Server [$($currentVersion.MajorVersion)]"))
			{
				$invProgParams = @{
					'ComputerName' = $ComputerName
					'Credential' = $Credential
				}
				
				$spExtractPath = 'C:\Windows\Temp\SQLCU'
				Invoke-Program @invProgParams -FilePath $installer.FullName -ArgumentList "/extract:`"$spExtractPath`" /quiet"
				
				## Install the SP
				Invoke-Program @invProgParams -FilePath "$spExtractPath\setup.exe" -ArgumentList '/quiet /allinstances'
				
				if ($Restart.IsPresent)
				{
					Restart-Computer -ComputerName $ComputerName -Wait -For WinRm -Force
				}
				
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}

function TestSqlServerServicePack
{
	<#
	.SYNOPSIS
		This is a small helper function that returns a boolean $true or $false depending on if the SQL server version
		installed on a computer matches a particular service pack number.

	.EXAMPLE
		PS> TestSqlServerServicePack -ComputerName VM1 -ServicePackNumber 1

		This example connects to VM1 to obtain the SQL version installed. If the service pack installed is equal to
		or less than -ServicePackNumber, it will return $false other, it will return $true.

	.PARAMETER ComputerName
		A mandatory string parameter representing SQL server to connect to.

	.PARAMETER ServicePackNumber
		A mandatory integer paramter representing the service pack number to compare against the currently installed
		service pack.
	#>
	[OutputType([bool])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[int]$ServicePackNumber
	)
	process {
		try
		{
			$currentVersion = Get-SQLServerVersion -ComputerName $ComputerName
			if ($currentVersion.ServicePack -lt $ServicePackNumber)
			{
				Write-Verbose -Message "The server [$($ComputerName)'s'] service pack [$($currentVersion.ServicePack)] is older than [$($ServicePackNumber)]"
				$false
			}
			else
			{
				Write-Verbose -Message "The server [$($ComputerName)'s'] service pack [$($currentVersion.ServicePack)] is newer or equal to [$($ServicePackNumber)]"
				$true
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}

function Install-SqlServerServicePack
{
	<#
	.SYNOPSIS
		This function attempts to install a service pack to a SQL instance. It discovers the current version of SQL
		installed, searches for the bits for the service pack and installs the service pack specified.
	
	.EXAMPLE
		PS> Install-SqlServicePack -ComputerName SERVER1 -Number 2
	
		This example attempts to install service pack 2 for whatever version of SQL that's installed on SERVER1.
	
	.EXAMPLE
		PS> Install-SqlServicePack -ComputerName SERVER1 -Latest
	
		This example will find the latest service pack that is downloaded and will attempt to install it on SERVER1.
	
	.PARAMETER ComputerName
		A mandatory string parameter representing the FQDN of the computer to run the function against. This must be
		a FQDN.
	
	.PARAMETER Number
		A mandatory integer parameter if Latest is not used. This represents the service pack to attempt to install.
	
	.PARAMETER Latest
		A mandatory switch parameter if Number is not used. Using this parameter will find the latest service pack
		that has been downloaded for the SQL server version installed on ComputerName that will be installed.
	
	.PARAMETER Restart
		An optional switch parameter. By default, ComputerName will not restart after service pack installation. If this parameter is used, it will
		restart after a successful install.
	
	.PARAMETER Credential
		An optional pscredential parameter representing a credential to use to connect to ComputerName. By default,
		this will be the pscredential for 'GENOMICHEALTH\svcOrchestrator' returned from the key store.
	
	#>
	[OutputType([void])]
	[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Latest')]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,
		
		[Parameter(Mandatory, ParameterSetName = 'Number')]
		[ValidateNotNullOrEmpty()]
		[ValidateRange(1, 5)]
		[int]$Number,
		
		[Parameter(Mandatory, ParameterSetName = 'Latest')]
		[ValidateNotNullOrEmpty()]
		[switch]$Latest,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$Restart
	)
	process
	{
		try
		{
			## Find the current version on the computer
			$currentVersion = Get-SQLServerVersion -ComputerName $ComputerName
			
			## Figure out the service pack to use if -Latest was used instead of -Number.
			if ($Latest.IsPresent)
			{
				$Number = (Get-LatestSqlServerServicePackVersion -SqlServerVersion $currentVersion.MajorVersion).ServicePack
			}
			
			## Common Invoke-Command et al connection parameters
			$connParams = @{
				'ComputerName' = $ComputerName
			}
				
			Write-Verbose -Message "Installing SP on [$($ComputerName)]"
			
			## Find the architecture of the computer
			##TODO: ADB - This should be a function
			$arch = (Get-CimInstance -ComputerName $ComputerName -ClassName 'Win32_ComputerSystem' -Property 'SystemType').SystemType
			if ($arch -eq 'x64-based PC')
			{
				$arch = 'x64'
			}
			else
			{
				$arch = 'x86'
			}
			
			## Find the installer to use
			$params = @{
				'Architecture' = $arch
				'SqlServerVersion' = $currentVersion.MajorVersion
				'Number' = $Number
			}
			
			if (TestSqlServerServicePack -ComputerName $ComputerName -ServicePackNumber $Number)
			{
				Write-Verbose -Message "The computer [$($ComputerName)] already has the specified (or latest) service pack installed."
			}
			else
			{
				if (-not ($installer = Find-SqlServerServicePackInstaller @params))
				{
					throw "Could not find installer for service pack [$($Number)] for version [$($currentVersion.MajorVersion)]"
				}
				
				if (Test-PendingReboot @connParams)
				{
					throw "The computer [$($ComputerName)] is pending a reboot. Reboot the computer before proceeding."
				}
				
				## Apply SP
				if ($PSCmdlet.ShouldProcess($ComputerName, "Install service pack [$($installer.Name)] for SQL Server [$($currentVersion.MajorVersion)]"))
				{
					$spExtractPath = 'C:\Windows\Temp\SQLSP'
					Invoke-Program @connParams -FilePath $installer.FullName -ArgumentList "/extract:`"$spExtractPath`" /quiet"
					
					## Install the SP
					Invoke-Program @connParams -FilePath "$spExtractPath\setup.exe" -ArgumentList '/q /allinstances'
					
					if ($Restart.IsPresent)
					{
						Restart-Computer @connParams -Wait -Force
					}
				}
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
		finally
		{
			if ((Test-Path -Path Variable:\spExtractPath) -and $spExtractPath)
			{
				## Cleanup the extracted SP
				Invoke-Command @connParams -ScriptBlock { Remove-Item -Path $using:spExtractPath -Recurse -Force -ErrorAction SilentlyContinue }
			}
		}
	}
}

function Get-SQLServerVersion
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName
	)
	process
	{
		try
		{
			$sqlInstance = Get-SQLInstance -ComputerName $ComputerName
			if (-not $sqlInstance)
			{
				throw 'Server query failed.'
			}
			else
			{
				$currentVersion = ConvertTo-VersionObject -Version $sqlInstance.Version
				$currentVersion | Add-Member -Name 'Edition' -MemberType NoteProperty -Value $sqlInstance.Edition
				$currentVersion
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}

function ConvertTo-VersionObject
{
	<#
	.SYNOPSIS
		ConvertTo-VersionObject takes a version input like 11.1.4.5 and converts this into a "friendly" output showing what
		major version, service pack and cumulative update this version applies to.
	#>
	[OutputType([System.Management.Automation.PSCustomObject])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[version]$Version
	)
	process
	{
		try
		{
			$impCsvParams = @{
				'Path' = "$PSScriptRoot\sqlversions.csv"
			}

			$filterScript = { $_.FullVersion -le "$($Version.Major).00.$($Version.Build)" }

			$selectParams = @{
				'Last' = 1
				'Property' = '*', @{ Name = 'ServicePack'; Expression = { if ($_.ServicePack -eq 0) { $null } else { $_.ServicePack} } }
				'ExcludeProperty' = 'ServicePack'

			}
			(Import-Csv @impCsvParams | Sort-Object FullVersion).Where($filterScript) | Select-Object @selectParams
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}

function Get-SQLInstance
{
<#
	.SYNOPSIS
		Retrieves SQL server information from a local or remote servers. The majority of this function was created by
		Boe Prox.

	.DESCRIPTION
		Retrieves SQL server information from a local or remote servers. Pulls all instances from a SQL server and
		detects if in a cluster or not.

	.PARAMETER ComputerName
		Local or remote systems to query for SQL information.

	.NOTES
		Name: Get-SQLInstance
		Author: Boe Prox
		DateCreated: 07 SEPT 2013

	.EXAMPLE
		Get-SQLInstance -ComputerName SQL01 -Component SSDS

		ComputerName  : BDT005-BT-SQL
		InstanceType  : Database Engine
		InstanceName  : MSSQLSERVER
		InstanceID    : MSSQL11.MSSQLSERVER
		Edition       : Enterprise Edition
		Version       : 11.1.3000.0
		Caption       : SQL Server 2012
		IsCluster     : False
		IsClusterNode : False
		ClusterName   :
		ClusterNodes  : {}
		FullName      : BDT005-BT-SQL

		Description
		-----------
		Retrieves the SQL instance information from SQL01 for component type SSDS (Database Engine).

	.EXAMPLE
		Get-SQLInstance -ComputerName SQL01

		ComputerName  : BDT005-BT-SQL
		InstanceType  : Analysis Services
		InstanceName  : MSSQLSERVER
		InstanceID    : MSAS11.MSSQLSERVER
		Edition       : Enterprise Edition
		Version       : 11.1.3000.0
		Caption       : SQL Server 2012
		IsCluster     : False
		IsClusterNode : False
		ClusterName   :
		ClusterNodes  : {}
		FullName      : BDT005-BT-SQL

		ComputerName  : BDT005-BT-SQL
		InstanceType  : Reporting Services
		InstanceName  : MSSQLSERVER
		InstanceID    : MSRS11.MSSQLSERVER
		Edition       : Enterprise Edition
		Version       : 11.1.3000.0
		Caption       : SQL Server 2012
		IsCluster     : False
		IsClusterNode : False
		ClusterName   :
		ClusterNodes  : {}
		FullName      : BDT005-BT-SQL

		Description
		-----------
		Retrieves the SQL instance information from SQL01 for all component types (SSAS, SSDS, SSRS).
#>
	
	[CmdletBinding()]
	param
	(
		[Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('__Server', 'DNSHostName', 'IPAddress')]
		[string[]]$ComputerName = $Env:COMPUTERNAME,
		
		[Parameter()]
		[ValidateSet('SSDS', 'SSAS', 'SSRS')]
		[string[]]$Component = @('SSDS', 'SSAS', 'SSRS')
	)
	
	begin
	{
		$componentNameMap = @(
			[pscustomobject]@{
				ComponentName	= 'SSAS';
				DisplayName		= 'Analysis Services';
				RegKeyName		= "OLAP";
			},
			[pscustomobject]@{
				ComponentName	= 'SSDS';
				DisplayName		= 'Database Engine';
				RegKeyName		= 'SQL';
			},
			[pscustomobject]@{
				ComponentName	= 'SSRS';
				DisplayName		= 'Reporting Services';
				RegKeyName		= 'RS';
			}
		);
	}
	
	process
	{
		foreach ($computer in $ComputerName)
		{
			try
			{
				#region Connect to the specified computer and open the registry key
				$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $computer);
				$baseKeys = "SOFTWARE\\Microsoft\\Microsoft SQL Server", "SOFTWARE\\Wow6432Node\\Microsoft\\Microsoft SQL Server";
				if ($reg.OpenSubKey($baseKeys[0]))
				{
					$regPath = $baseKeys[0];
				}
				elseif ($reg.OpenSubKey($baseKeys[1]))
				{
					$regPath = $baseKeys[1];
				}
				else
				{
					continue;
				}
				#endregion Connect to the specified computer and open the registry key
				
				# Shorten the computer name if a FQDN was specified.
				$computer = $computer -replace '(.*?)\..+', '$1';
				
				$regKey = $reg.OpenSubKey("$regPath");
				if ($regKey.GetSubKeyNames() -contains "Instance Names")
				{
					foreach ($componentName in $Component)
					{
						$componentRegKeyName = $componentNameMap |
						Where-Object { $_.ComponentName -eq $componentName } |
						Select-Object -ExpandProperty RegKeyName;
						$regKey = $reg.OpenSubKey("$regPath\\Instance Names\\{0}" -f $componentRegKeyName);
						if ($regKey)
						{
							foreach ($regValueName in $regKey.GetValueNames())
							{
								Get-SQLInstanceDetail -RegPath $regPath -Reg $reg -RegKey $regKey -Instance $regValueName;
							}
						}
					}
				}
				elseif ($regKey.GetValueNames() -contains 'InstalledInstances')
				{
					$isCluster = $false;
					$regKey.GetValue('InstalledInstances') | ForEach-Object {
						Get-SQLInstanceDetail -RegPath $regPath -Reg $reg -RegKey $regKey -Instance $_;
					};
				}
				else
				{
					continue;
				}
			}
			catch
			{
				Write-Error ("{0}: {1}" -f $computer, $_.Exception.ToString());
			}
		}
	}
}

function Get-SQLInstanceDetail
{
	<#
		.SYNOPSIS
			 The majority of this function was created by Boe Prox.
	
		.EXAMPLE
			PS> $functionName
	
		.PARAMETER parameter
			A mandatoryorOptional paramType parameter representing 
	
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
		[string[]]$Instance,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.Win32.RegistryKey]$RegKey,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.Win32.RegistryKey]$reg,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$RegPath
	)
	process
	{
		#region Process each instance
		foreach ($sqlInstance in $Instance)
		{
			$nodes = New-Object System.Collections.ArrayList;
			$clusterName = $null;
			$isCluster = $false;
			$instanceValue = $regKey.GetValue($sqlInstance);
			$instanceReg = $reg.OpenSubKey("$regPath\\$instanceValue");
			if ($instanceReg.GetSubKeyNames() -contains 'Cluster')

			{
				$isCluster = $true;
				$instanceRegCluster = $instanceReg.OpenSubKey('Cluster');
				$clusterName = $instanceRegCluster.GetValue('ClusterName');
				Write-Verbose -Message "Getting cluster node names";
				$clusterReg = $reg.OpenSubKey("Cluster\\Nodes");
				$clusterNodes = $clusterReg.GetSubKeyNames();
				if ($clusterNodes)
				{
					foreach ($clusterNode in $clusterNodes)
					{
						$null = $nodes.Add($clusterReg.OpenSubKey($clusterNode).GetValue("NodeName").ToUpper());
					}
				}
			}
			
			#region Gather additional information about SQL instance
			$instanceRegSetup = $instanceReg.OpenSubKey("Setup")
			
			#region Get SQL instance directory
			try
			{
				$instanceDir = $instanceRegSetup.GetValue("SqlProgramDir");
				if (([System.IO.Path]::GetPathRoot($instanceDir) -ne $instanceDir) -and $instanceDir.EndsWith("\"))
				{
					$instanceDir = $instanceDir.Substring(0, $instanceDir.Length - 1);
				}
			}
			catch
			{
				$instanceDir = $null;
			}
			#endregion Get SQL instance directory
			
			#region Get SQL edition
			try
			{
				$edition = $instanceRegSetup.GetValue("Edition");
			}
			catch
			{
				$edition = $null;
			}
			#endregion Get SQL edition
			
			#region Get SQL version
			try
			{
				
				$version = $instanceRegSetup.GetValue("Version");
				if ($version.Split('.')[0] -eq '11')
				{
					$verKey = $reg.OpenSubKey('SOFTWARE\\Microsoft\\Microsoft SQL Server\\110\\SQLServer2012\\CurrentVersion')
					$version = $verKey.GetValue('Version')
				}
				elseif ($version.Split('.')[0] -eq '12')
				{
					$verKey = $reg.OpenSubKey('SOFTWARE\\Microsoft\\Microsoft SQL Server\\120\\SQLServer2014\\CurrentVersion')
					$version = $verKey.GetValue('Version')
				}
			}
			catch
			{
				$version = $null;
			}
			#endregion Get SQL version
			
			#endregion Gather additional information about SQL instance
			
			#region Generate return object
			[pscustomobject]@{
				ComputerName = $computer.ToUpper();
				InstanceType = {
					$componentNameMap | Where-Object { $_.ComponentName -eq $componentName } |
					Select-Object -ExpandProperty DisplayName
				}.InvokeReturnAsIs();
				InstanceName = $sqlInstance;
				InstanceID = $instanceValue;
				InstanceDir = $instanceDir;
				Edition = $edition;
				Version = $version;
				Caption = {
					switch -regex ($version)
					{
						"^11"		{ "SQL Server 2012"; break }
						"^10\.5"	{ "SQL Server 2008 R2"; break }
						"^10"		{ "SQL Server 2008"; break }
						"^9"		{ "SQL Server 2005"; break }
						"^8"		{ "SQL Server 2000"; break }
						default { "Unknown"; }
					}
				}.InvokeReturnAsIs();
				IsCluster = $isCluster;
				IsClusterNode = ($nodes -contains $computer);
				ClusterName = $clusterName;
				ClusterNodes = ($nodes -ne $computer);
				FullName = {
					if ($sqlInstance -eq "MSSQLSERVER")
					{
						$computer.ToUpper();
					}
					else
					{
						"$($computer.ToUpper())\$($sqlInstance)";
					}
				}.InvokeReturnAsIs();
			}
			#endregion Generate return object
		}
		#endregion Process each instance
	}
}

function Test-PendingReboot
{
	<#
		.SYNOPSIS
			This function tests various registry values to see if the local computer is pending a reboot
		.NOTES
			Inspiration from: https://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542
		.EXAMPLE
			PS> Test-PendingReboot
			
			This example checks various registry values to see if the local computer is pending a reboot.
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
	)
	process {
		try
		{
			$icmParams = @{
				'ComputerName' = $ComputerName
			}
			if ($PSBoundParameters.ContainsKey('Credential')) {
				$icmParams.Credential = $Credential
			}
			
			$OperatingSystem = Get-CimInstance -ComputerName $ComputerName -ClassName Win32_OperatingSystem -Property BuildNumber, CSName
			
			# If Vista/2008 & Above query the CBS Reg Key
			If ($OperatingSystem.BuildNumber -ge 6001)
			{
				$PendingReboot = Invoke-Command @icmParams -ScriptBlock { Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing' -Name 'RebootPending' -ErrorAction SilentlyContinue }
				if ($PendingReboot)
				{
					Write-Verbose -Message 'Reboot pending detected in the Component Based Servicing registry key'
					return $true
				}
			}
			
			# Query WUAU from the registry
			$PendingReboot = Invoke-Command @icmParams -ScriptBlock { Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Name 'RebootRequired' -ErrorAction SilentlyContinue }
			if ($PendingReboot)
			{
				Write-Verbose -Message 'WUAU has a reboot pending'
				return $true
			}
			
			# Query PendingFileRenameOperations from the registry
			$PendingReboot = Invoke-Command @icmParams -ScriptBlock { Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue }
			if ($PendingReboot -and $PendingReboot.PendingFileRenameOperations)
			{
				Write-Verbose -Message 'Reboot pending in the PendingFileRenameOperations registry value'
				return $true
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}

function Find-SqlServerServicePackInstaller
{
	[CmdletBinding(DefaultParameterSetName = 'Latest')]
	[OutputType('System.IO.FileInfo')]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('2008R2', '2012', '2014')]
		[string]$SqlServerVersion,
		
		[Parameter(ParameterSetName = 'Specific')]
		[ValidateNotNullOrEmpty()]
		[ValidateRange(1, 5)]
		[int]$Number,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('x86', 'x64')]
		[string]$Architecture = 'x64',
		
		[Parameter(ParameterSetName = 'Latest')]
		[ValidateNotNullOrEmpty()]
		[switch]$Latest,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$SqlServerInstallerBasePath = '\\SOme\unc\path\here'
		
	)
	process
	{
		try
		{
			## Doing it this wonky way to prevent having to enumerate ALL files.
			## The -Depth param in v5 would greatly clean this up.
			$servicePacks = Get-ChildItem -Path $SqlServerInstallerBasePath | Where-Object { $_.Name -match '^\d{4}' } | Get-ChildItem -Filter 'Updates' | Get-ChildItem -Filter 'SQLServer*-SP?-*.exe'
			
			if ($PSBoundParameters.ContainsKey('SqlServerVersion'))
			{
				$filter = 'SQLServer{0}' -f $SqlServerVersion
			}
			
			if ($PSBoundParameters.ContainsKey('Number'))
			{
				$filter += '-SP{0}-' -f $Number
			}
			
			if ($PSBoundParameters.ContainsKey('Architecture'))
			{
				$filter += '(.+)?{0}\.exe$' -f $Architecture
			}
			Write-Verbose -Message "Using filter [$($filter)]..."
			
			if ($filter)
			{
				$servicePacks = @($servicePacks).Where{ $_.Name -match $filter }
			}
			
			if ($Latest.IsPresent)
			{
				$servicePacks | Sort-Object { $_.Name } -Descending | Select-Object -First 1
			}
			else
			{
				$servicePacks
			}
			
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}

function Find-SqlServerCumulativeUpdateInstaller
{
	[CmdletBinding(DefaultParameterSetName = 'Latest')]
	[OutputType('System.IO.FileInfo')]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('2008R2', '2012', '2014')]
		[string]$SqlServerVersion,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateRange(1, 5)]
		[int]$ServicePackNumber,
		
		[Parameter(ParameterSetName = 'Specific')]
		[ValidateNotNullOrEmpty()]
		[int]$CumulativeUpdateNumber,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('x86', 'x64')]
		[string]$Architecture = 'x64',
		
		[Parameter(ParameterSetName = 'Latest')]
		[ValidateNotNullOrEmpty()]
		[switch]$Latest,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$SqlServerInstallerBasePath = '\\some\unc\path\here'
		
	)
	process
	{
		try
		{
			## Doing it this wonky way to prevent having to enumerate ALL files.
			## The -Depth param in v5 would greatly clean this up.
			$cumulUpdates = Get-ChildItem -Path $SqlServerInstallerBasePath | Where-Object { $_.Name -match '^\d{4}' } | Get-ChildItem -Filter 'Updates' | Get-ChildItem -Filter 'SQLServer*-SP?CU*.exe'
			
			if ($PSBoundParameters.ContainsKey('SqlServerVersion'))
			{
				$filter = 'SQLServer{0}' -f $SqlServerVersion
			}
			
			if ($PSBoundParameters.ContainsKey('ServicePackNumber'))
			{
				$filter += '-SP{0}' -f $ServicePackNumber
			}
			
			if ($PSBoundParameters.ContainsKey('CumulativeUpdateNumber'))
			{
				$filter += 'CU{0}.+' -f ([string]$CumulativeUpdateNumber).PadLeft(2, '0')
			}
			
			if ($PSBoundParameters.ContainsKey('Architecture'))
			{
				$filter += '(.+)?{0}\.exe$' -f $Architecture
			}
			Write-Verbose -Message "Using filter [$($filter)]..."
			
			if (-not $filter)
			{
				$cumulUpdates
			}
			else
			{
				@($cumulUpdates).Where{ $_.Name -match $filter }
			}
			
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}

function Get-LatestSqlServerCumulativeUpdateVersion
{
	[OutputType([pscustomobject])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('2008R2', '2012', '2014')]
		[string]$SqlServerVersion,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateRange(1, 5)]
		[int]$ServicePackNumber
	)
	process
	{
		try
		{
			(Import-Csv -Path "$PSScriptRoot\sqlversions.csv").where({
				$_.MajorVersion -eq $SqlServerVersion -and $_.ServicePack -eq $ServicePackNumber
			}) | sort-object { [int]$_.cumulativeupdate } -Descending | Select-Object -first 1
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}

function Get-LatestSqlServerServicePackVersion
{
	[OutputType([pscustomobject])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('2008R2', '2012', '2014')]
		[string]$SqlServerVersion
	)
	process
	{
		try
		{
			(Import-Csv -Path "$PSScriptRoot\sqlversions.csv").where({ $_.MajorVersion -eq $SqlServerVersion }) | sort-object servicepack -Descending | Select-Object -first 1
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}

function Update-SqlServer
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet(1, 2, 3, 4, 5, 'Latest')]
		[string]$ServicePack = 'Latest',
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 'Latest')]
		[string]$CumulativeUpdate = 'Latest',
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
	)
	process {
		try
		{
			$spParams = @{
				'ComputerName' = $ComputerName
				'Restart' = $true	
			}
			if ($ServicePack -eq 'Latest')
			{
				$spParams.Latest = $true
			}
			else
			{
				$spParams.Number = $ServicePack	
			}
			Install-SqlServerServicePack @spParams
				
			$cuParams = @{
				'ComputerName' = $ComputerName
				'Restart' = $true
			}
			if ($CumulativeUpdate -eq 'Latest')
			{
				$cuParams.Latest = $true
			}
			else
			{
				$cuParams.Number = $CumulativeUpdate
			}
			Install-SqlServerCumulativeUpdate @cuParams
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}

function Invoke-Program
{
	[CmdletBinding()]
	[OutputType([System.Management.Automation.PSObject])]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$FilePath,

		[Parameter()]
		[string]$ComputerName = 'localhost',

		[Parameter()]
		[pscredential]$Credential,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ArgumentList,

		[Parameter()]
		[bool]$ExpandStrings = $false,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$WorkingDirectory,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[uint32[]]$SuccessReturnCodes = @(0, 3010)
	)
	process
	{
		try
		{
			# Clear the DNS cache on the local machine.
			$null = Clear-DNSClientCache;
			
			$icmParams = @{
				ComputerName = $ComputerName;
			}

			$icmParams.Authentication = 'CredSSP'
			if ($PSBoundParameters.ContainsKey('Credential'))
			{
				$icmParams.Credential = $Credential	
			}
			
			Write-Verbose -Message "Acceptable success return codes are [$($SuccessReturnCodes -join ',')]"
			
			$icmParams.ScriptBlock = {
				$VerbosePreference = $using:VerbosePreference
				
				try
				{
					$processStartInfo = New-Object System.Diagnostics.ProcessStartInfo;
					$processStartInfo.FileName = $Using:FilePath;
					if ($Using:ArgumentList)
					{
						$processStartInfo.Arguments = $Using:ArgumentList;
						if ($Using:ExpandStrings)
						{
							$processStartInfo.Arguments = $ExecutionContext.InvokeCommand.ExpandString($Using:ArgumentList);
						}
					}
					if ($Using:WorkingDirectory)
					{
						$processStartInfo.WorkingDirectory = $Using:WorkingDirectory;
						if ($Using:ExpandStrings)
						{
							$processStartInfo.WorkingDirectory = $ExecutionContext.InvokeCommand.ExpandString($Using:WorkingDirectory);
						}
					}
					$processStartInfo.UseShellExecute = $false; # This is critical for installs to function on core servers
					$ps = New-Object System.Diagnostics.Process;
					$ps.StartInfo = $processStartInfo;
					Write-Verbose -Message "Starting process path [$($processStartInfo.FileName)] - Args: [$($processStartInfo.Arguments)] - Working dir: [$($Using:WorkingDirectory)]"
					$null = $ps.Start();
					$ps.WaitForExit();
					
					# Check the exit code of the process to see if it succeeded.
					if ($ps.ExitCode -notin $Using:SuccessReturnCodes)
					{
						throw "Error running program: $($ps.ExitCode)";
					}
				}
				catch
				{
					Write-Error $_.Exception.ToString();
				}
			}
			
			# Run program on specified computer.
			Write-Verbose -Message "Running command line [$FilePath $ArgumentList] on $ComputerName";
			
			$params = @{
				'ComputerName' = $ComputerName
				'Credential' = $Credential
			}
			$result = Invoke-Command @icmParams
			
			# Check if any errors occurred.
			if ($err)
			{
				throw $err;
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}