Set-StrictMode -Version Latest;

$Defaults = @{
	'KnifeLocation' = 'C:\opscode\chefdk\bin\knife.bat'
	'ChefRepoPath' = '~\chef-repo'
	'CookbookPath' = '~\chef-repo\cookbooks'
	'NotepadPath' = 'C:\Program Files (x86)\Notepad++\notepad++.exe'
	'CredentialsVaultName' = 'credentials'
}

#region function Get-Recipe
function Get-Recipe
{
	[CmdletBinding()]
	param
	(
		[Parameter(ValueFromPipelineByPropertyName)]
		[Alias('Cookbook')]
		[ValidateNotNullOrEmpty()]
		[string]$CookbookName,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Client', 'Server')]
		[string]$Source,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			if ($Source -eq 'Client')
			{
				$params = @{ }
				if ($PSBoundParameters.ContainsKey('CookbookName'))
				{
					$params.Name = $CookbookName
				}
				if (-not ($cookbooks = Find-Cookbook @params))
				{
					throw 'No cookbooks found.'
				}
				
				if (-not $PSBoundParameters.ContainsKey('Name'))
				{
					$Name = '*'
				}
				
				@($cookbooks).foreach({
						$cookbookN = $_.Cookbook
						@(Get-ChildItem -Path "$($_.Path)\recipes" -Filter "$Name.rb").foreach({
								[pscustomobject]@{
									'Cookbook' = $cookbookN
									'Recipe' = $_.BaseName
									'Path' = $_.FullName
									'Source' = $Source
								}
							})
					})
			}
			else
			{
				$recipeName = $null
				if ($PSBoundParameters.ContainsKey('CookbookName'))
				{
					$recipeName = $CookbookName
				}
				
				if ($PSBoundParameters.ContainsKey('Name'))
				{
					$recipeName += $Name
				}
				@(knife recipe list $recipeName).foreach({
						if ($_ -notmatch '::')
						{
							$CookbookName = $_
							$recipeName = 'default'
						}
						else
						{
							$split = $_.Split('::')
							$CookbookName = $split[0]
							$recipeName = $split[1]
						}
						$output = @{
							'Cookbook' = $CookbookName
							'Recipe' = $recipeName.Trim()
							'Source' = $Source
							'Path' = $null
						}
						[pscustomobject]$output
					})
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function Get-Recipe

#region function Edit-Recipe
function Edit-Recipe
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[Alias('Cookbook')]
		[ValidateNotNullOrEmpty()]
		[string]$CookbookName,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[Alias('Recipe')]
		[ValidateNotNullOrEmpty()]
		[string]$Name = 'default'
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			if (-not ($cookbook = Find-Cookbook -Name $CookbookName))
			{
				throw "Cookbook [$($CookbookName)] not found."
			}
			& $Defaults.NotepadPath "$($cookbook.Path)\recipes\$Name.rb"
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function Edit-Recipe

#region function Edit-KnifeConfiguration
function Edit-KnifeConfiguration
{
	[CmdletBinding()]
	param
	(
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			& $Defaults.NotepadPath "$($Defaults.ChefRepoPath)\.chef\knife.rb"
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function Edit-KnifeConfiguration

#region function Find-Cookbook
function Find-Cookbook
{
	[OutputType([System.IO.FileInfo])]
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Client', 'Server')]
		[string]$Source = 'Client'
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			if ($Source -eq 'Client')
			{
				if ($PSBoundParameters.ContainsKey('Name'))
				{
					$whereFilter = { $_.PSIsContainer -and ($_.Name -eq $Name) }
				}
				else
				{
					$whereFilter = { $_.PSIsContainer }
				}
				
				if ($paths = (Get-ChildItem -Path $Defaults.CookbookPath).Where($whereFilter))
				{
					@($paths).foreach({
							$output = @{
								'Cookbook' = $_.Name
								'Source' = $Source
								'Path' = $_.FullName
								'Version' = $null
							}
							if (Test-Path -Path "$($_.FullName)\metadata.rb" -PathType Leaf)
							{
								$output.Version = ((select-string -path "$($_.FullName)\metadata.rb" -Pattern "version\s+['|`"](.+)['|`"]").Matches.Groups[1].Value)
							}
							elseif (Test-Path -Path "$($_.FullName)\metadata.json" -PathType Leaf)
							{
								$output.Version = 'JSON metadata not supported yet'
							}
							[pscustomobject]$output
						})
				}
			}
			else
			{
				Push-Location -Path $Defaults.ChefRepoPath
				if ($Name)
				{
					$whereFilter = { $_.Cookbook -eq $Name }
				}
				else
				{
					$whereFilter = { $_.Cookbook }
				}
				(& $Defaults.KnifeLocation cookbook list --all).foreach({
						[pscustomobject]@{
							'Cookbook' = [regex]::Matches($_, '^(.+)\s+').Groups[1].Value.Trim()
							'Source' = $Source
							'Path' = $null
							'Version' = [regex]::Matches($_, '^.+\s+(.+)').Groups[1].Value.Trim()
						}
					}).where($whereFilter)
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
		finally
		{
			Pop-Location
		}
	}
}
#endregion function Find-Cookbook

#region function Remove-Cookbook
function Remove-Cookbook
{
	<#
	.SYNOPSIS
		Removes a Chef cookbook.
		
	.EXAMPLE
		PS> function-name
	
		Comment-Example
		
	.PARAMETER Force
		Entirely remove a cookbook (or cookbook version) from the Chef server. Use this action carefully because only 
		one copy of any single file is stored on the Chef server. Consequently, purging a cookbook disables any other 
		cookbook that references one or more files from the cookbook that has been purged.
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Cookbook,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$Force
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			if ($PSCmdlet.ShouldProcess($Cookbook.Cookbook, 'Remove'))
			{
				if ($Cookbook.Source -eq 'Server')
				{
					if ($Force.IsPresent)
					{
						& $Defaults.KnifeLocation cookbook delete $Cookbook.Cookbook --purge --yes
					}
					else
					{
						& $Defaults.KnifeLocation cookbook delete $Cookbook.Cookbook --yes
					}
				}
				else
				{
					$Cookbook.Path | Remove-Item -Recurse
				}
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function Remove-Cookbook

#region function Install-Cookbook
function Install-Cookbook
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	begin
	{
		$ErrorActionPreference = 'Continue'
	}
	process
	{
		try
		{
			$result = & $Defaults.KnifeLocation cookbook site download $Name 2>&1 $null
			$marketCookbookName = [regex]::match($result.Exception.Message[1], 'Cookbook saved: .*[/](.*)').Groups[1].Value
			Write-Verbose -Message "Market cookbook name is [$($marketCookbookName)]"
			Push-Location -Path $Defaults.ChefRepoPath
			tar -zxvf $marketCookbookName -C $Defaults.CookbookPath
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
		finally
		{
			Pop-Location
		}
	}
}
#endregion function Install-Cookbook

#region function Get-ChefCredential
function Get-ChefCredential
{
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	param
	(
		[Parameter(ParameterSetName = 'Id')]
		[ValidateNotNullOrEmpty()]
		[string]$Id,
		
		[Parameter(ParameterSetName = 'UserName')]
		[ValidateNotNullOrEmpty()]
		[string]$Username
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$params = @{
				'VaultName' = $Defaults.CredentialsVaultName
			}
			if ($PSBoundParameters.ContainsKey('Id'))
			{
				$params.Id = $Id
			}
			if ($PSBoundParameters.ContainsKey('UserName'))
			{
				@(Get-ChefVaultItem @params).where({ $_.username -eq $Username })
			}
			else
			{
				Get-ChefVaultItem @params
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function Get-ChefCredential

#region function New-ChefCredential
function New-ChefCredential
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Id,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Username,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Password
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			New-ChefVaultItem -Id $Id -Json "{`"username`": `"$Username`", `"password`": `"$Password`"}" -VaultName $Defaults.CredentialsVaultName
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function New-ChefCredential

#region function Step-CookbookVersion
function Step-CookbookVersion
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Cookbook
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$metaDataPath = "$($Cookbook.Path)\metadata.rb"
			if (Test-Path -Path $metaDataPath -PathType Leaf)
			{
				[version]$oldVersion = $Cookbook.Version
				$Cookbook.Version = ('{0}.{1}.{2}' -f $oldVersion.Major, $oldVersion.Minor, ($oldVersion.Build + 1))
				$Cookbook
			}
			else
			{
				throw 'Metadata file path not found.'
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function Step-CookbookVersion

#region function Set-Cookbook
function Set-Cookbook
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Cookbook,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$PassThru
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$metaDataPath = "$($Cookbook.Path)\metadata.rb"
			$newVersion = $Cookbook.Version
			((Get-Content -Path $metaDataPath) -replace "version '(.+)'", "version '$newVersion'") | Set-Content $metaDataPath
			if ($PassThru.IsPresent)
			{
				$Cookbook
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function Set-Cookbook

#region function Remove-ChefCredential
function Remove-ChefCredential
{
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$ChefCredential
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			if ($PSCmdlet.ShouldProcess($ChefCredential.Id, 'Credential removal'))
			{
				& $Defaults.KnifeLocation vault delete $Defaults.CredentialsVaultName $ChefCredential.Id --yes
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function Remove-ChefCredential

#region function Get-ChefVaultItem
function Get-ChefVaultItem
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Id,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$VaultName = $Defaults.CredentialsVaultName
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			if ($PSBoundParameters.ContainsKey('Id'))
			{
				$hashTable = @{ }
				$result = & $Defaults.KnifeLocation vault show $VaultName.ToLower() $Id.ToLower()
				$result.foreach({
						$groups = [regex]::Match($_, '^(.+):\s+(.+)').Groups[1..2]
						$hashTable[$groups[0].Value] = $groups[1].Value
						$hashTable[$groups[0].Value] = $groups[1].Value
					})
				[pscustomobject]$hashtable
			}
			else
			{
				if ($items = & $Defaults.KnifeLocation vault show $VaultName.ToLower())
				{
					## knife does not show username and password if a name is not explicitly picked
					@($items).foreach({
							Get-ChefVaultItem -Id $_
						})
				}
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function Get-ChefVaultItem

#region function Add-Cookbook
function Add-Cookbook
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[Alias('Cookbook')]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[Alias('Recipe')]
		[ValidateNotNullOrEmpty()]
		[string]$RecipeName = 'default',
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$NodeName
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			if ($RecipeName -eq 'default')
			{
				& $Defaults.KnifeLocation node run_list add $NodeName $Name
			}
			else
			{
				& $Defaults.KnifeLocation node run_list add $NodeName "$Name::$RecipeName"
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function Add-Cookbook

#region function New-ChefVaultItem
function New-ChefVaultItem
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Id,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Json,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$VaultName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string[]]$Administrator = 'abertram',
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string[]]$AllowedClients = '*'
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			## Escape double quotes, single quotes and backslashes
			$Json = $Json -replace "('|`"|\\)", '\$1'
			
			$admins = $Administrator -join ','
			$clients = $AllowedClients -join ',name:'
			
			& $Defaults.KnifeLocation vault create $VaultName $Id.ToLower() $Json -A $admins -S "name:$AllowedClients"
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function New-ChefVaultItem

#region function New-Recipe
function New-Recipe
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$CookbookName,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			if (-not ($cookbook = Find-Cookbook -Name $CookbookName))
			{
				throw "Cookbook [$($CookbookName)] not found."
			}
			
			$path = "$($cookbook.FullName)\recipes\$Name.rb"
			Add-Content -Path $path -Value $null
			notepad $path
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function New-Recipe

#region function New-Cookbook
function New-Cookbook
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			if (-not (Test-Path -Path $Defaults.CookbookPath))
			{
				$null = mkdir $Defaults.CookbookPath
			}
			Push-Location -Path $Defaults.CookbookPath
			& chef generate cookbook $Name
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
	end
	{
		Pop-Location
	}
}
#endregion function New-Cookbook

#region function Test-ChefServerConnection
function Test-ChefServerConnection
{
	<#
	.SYNOPSIS
		Tests the SSL connection to the Chef server.
		
	.DESCRIPTION
		Before running, ensure that the SSL cert on the Chef server is accurate. To do so, ensure the chef-server.rb
		file in /etc/opscode/chef-server.rb looks like this:
	
		server_name = "chef.genomichealth.com"
		api_fqdn = server_name
		bookshelf['vip'] = server_name
		nginx['url'] = "https://#{server_name}"
		nginx['server_name'] = server_name
		nginx['ssl_certificate'] = "/var/opt/opscode/nginx/ca/#{server_name}.crt"
		nginx['ssl_certificate_key'] = "/var/opt/opscode/nginx/ca/#{server_name}.key"
		lb['fqdn'] = server_name
	
		If it's not like this, after modification, run: sudo chef-server-ctl reconfigure on the Chef Server. You may also
		have to download the new cert into your trusted_certs folder by running this: knife ssl fetch.
	
	.EXAMPLE
		PS> Test-ChefServerConnection
	#>
	[CmdletBinding()]
	param
	(
		
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			Push-Location -Path $Defaults.ChefRepoPath
			& $Defaults.KnifeLocation ssl check
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
	end
	{
		Pop-Location
	}
}
#endregion function Test-ChefServerConnection

#region function Get-ChefUserPrivateKey
function Get-ChefUserPrivateKey
{
	[CmdletBinding()]
	param
	(
		
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			Get-ChildItem -Path "$($Defaults.ChefRepoPath)\.chef" -Filter '*.pem'
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function Get-ChefUserPrivateKey

#region function Get-Node
function Get-Node
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			Push-Location -Path $Defaults.ChefRepoPath
			if ($Name)
			{
				$whereFilter = { $_.NodeName -eq $Name }
			}
			else
			{
				$whereFilter = { $_.NodeName }
			}
			@(knife node list).foreach({
					[pscustomobject]@{
						'NodeName' = $_
					}
				}).where($whereFilter)
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
		finally
		{
			Pop-Location
		}
	}
}
#endregion function Get-Node

#region function Get-RunList
function Get-RunList
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$NodeName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			Push-Location -Path $Defaults.ChefRepoPath
			
			if ($PSBoundParameters.ContainsKey('Name'))
			{
				$whereFilter = { $_ -match 'recipe' -and $_ -match $Name }
			}
			else
			{
				$whereFilter = { $_ -match 'recipe' }
			}
			@(knife node show $NodeName --run-list).where($whereFilter).foreach({
					$split = [regex]::Matches($_, 'recipe\[(.*)\]').Groups[1].Value.Split('::')
					$output = @{
						'Node' = $NodeName
						'Cookbook' = $split[0]
					}
					if ($split.Count -eq 3)
					{
						$output.Recipe = $split[2]
					}
					else
					{
						$output.Recipe = 'default'
					}
					[pscustomobject]$output
				})
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
		finally
		{
			Pop-Location
		}
	}
}
#endregion function Get-RunList

#region function Remove-RunList
function Remove-RunList
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$RunList
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			Push-Location -Path $Defaults.ChefRepoPath
			if ($RunList.Recipe -eq 'default')
			{
				knife node run_list remove $RunList.Node "recipe[$($RunList.Cookbook)]"
			}
			else
			{
				knife node run_list remove $RunList.Node "recipe[$($RunList.Cookbook)::$($RunList.Recipe)]"
			}
			
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
		finally
		{
			Pop-Location
		}
	}
}
#endregion function Remove-RunList

#region function New-RunList
function New-RunList
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$NodeName,
		
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Recipe
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$output = @{
				'Node' = $NodeName
			}
			if ($Recipe.Recipe -eq 'default')
			{
				$output.RunList = "recipe[$($Recipe.Cookbook)]"
			}
			else
			{
				$output.RunList = "recipe[$($Recipe.Cookbook)::$($Recipe.Recipe)]"
			}
			[pscustomobject]$output
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function New-RunList

#region function Add-RunList
function Add-RunList
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$RunList
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			Push-Location -Path $Defaults.ChefRepoPath
			knife node run_list add $RunList.Node $RunList.RunList
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
		finally
		{
			Pop-Location
		}
	}
}
#endregion function Add-RunList

#region function Install-ChefServerClientPrerequisite
function Install-ChefServerClientPrerequisite
{
	<#
	.SYNOPSIS
		This function does some preliminary setup on the client connecting to a Chef Server.
	
	.PARAMETER ChefDkInstallerFilePath
		The file path to the Chef Development Kit installer. Download this file at
		https://downloads.chef.io/chef-dk/windows/
	
	.PARAMETER KnifeConfigFilePath
		The file path to the knife.rb config file. To retrieve this, go to https://chef.genomichealth.com, click on
		Admnistration, Generate Knife Config and then on the ghiinc organization. Once downloaded, replace this line:
		https://CHEF.qse1trsa14selck5erycbjhrkd.dx.internal.cloudapp.net/organizations/ghi with this:
		https://chef.genomichealth.com.
	
	.PARAMETER PrivateKeyFilePath
		The file path to the RSA private key file to talk to the Chef Server. To retrieve this, go to 
		https://chef.genomichealth.com, click on Administration, click on Users, Reset Key and then on your username.
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('\.rb$')]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[string]$KnifeConfigFilePath,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('\.pem$')]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[string]$PrivateKeyFilePath,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[string]$ChefDkInstallerFilePath,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ChefDkFolderPath = 'C:\opscode\chefdk'
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			if (-not @(Get-InstalledSoftware).where({ $_.Name -match 'Chef Development Kit' }))
			{
				if (-not $ChefDkInstallerFilePath)
				{
					throw 'Chef development kit was not found. You must specify the ChefDkInstallerPath to install it.'
				}
				& $ChefDkInstallerFilePath
			}
			
			## Add the Chef directory to the path
			if ("$ChefDkFolderPath\bin" -notin $env:Path.Split(';'))
			{
				[Environment]::SetEnvironmentVariable('Path', $env:Path + ";$ChefDkFolderPath\bin", [EnvironmentVariableTarget]::User)
				Write-Warning -Message "[$("$ChefDkFolderPath\bin")] not in user path. To use 'chef', you must restart the PowerShell console."
			}
			
			## Create the necessary folders
			$chefRepoDirPath = $Defaults.ChefRepoPath
			$chefDirPath = "$chefRepoDirPath\.chef"
			
			@($chefRepoDirPath, $chefDirPath, "$chefDirPath\trusted_certs").foreach({
					if (-not (Test-Path -Path $_ -PathType Container))
					{
						$null = mkdir $_
					}
				})
			
			& "$ChefDkFolderPath\bin\chef" gem install knife-windows
			
			@($KnifeConfigFilePath, $PrivateKeyFilePath).foreach({
					$_ | Copy-Item -Destination $chefDirPath
				})
			
			## Add the Chef server's self-signed cert to trusted_certs
			& $Defaults.KnifeLocation ssl fetch
			
			Test-ChefServerConnection
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function Install-ChefServerClientPrerequisite

#region function Install-ChefClient
function Install-ChefClient
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential = (Get-KeystoreCredential -Name 'GENOMICHEALTH\svcOrchestrator')
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
		
		## Check to ensure the .chef folder is available (PEM file and knife.rb)
	}
	process
	{
		try
		{
			@($ComputerName).foreach({
					& $Defaults.KnifeLocation bootstrap windows winrm $_ -x $Credential.UserName -P $Credential.GetNetworkCredential().Password -N $_
				})
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function Install-ChefClient

function Set-ClientConfiguration
{
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	param
	(
		[Parameter(Mandatory,ParameterSetName = 'ComputerName')]
		[ValidateNotNullOrEmpty()]
		[string]$Computername,
		
		[Parameter(Mandatory,ParameterSetName = 'Configuration',ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Configuration,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Info','Debug')]
		[string]$LogLevel,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$PassThru
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			if ($PSBoundParameters.ContainsKey('ComputerName')) {	
				$config = (Get-ClientConfiguration -Computername $Computername).Configuration
			}
			else
			{
				$Computername = $Configuration.Computername
				$config = $Configuration.Configuration
			}
			
			$configPath = "\\$Computername\c$\chef\client.rb"
			
			if ($PSBoundParameters.ContainsKey('LogLevel'))
			{
				$config -replace '(log_level\s+:)(.*)', "`$1$($LogLevel.ToLower())" | Set-Content $configPath
			}
			if ($PassThru.IsPresent)
			{
				Get-ClientConfiguration -Computername $Computername
			}
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function Get-ClientConfiguration
{
	[OutputType([pscustomobject])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Computername
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			$configPath = "\\$Computername\c$\chef\client.rb"
			[pscustomobject]@{
				'Computername' = $Computername
				'Configuration' = Get-Content -Path $configPath -Raw
			}
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

#region function Invoke-ChefClient
function Invoke-ChefClient
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential = (Get-KeystoreCredential -Name 'GENOMICHEALTH\svcOrchestrator')
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			Push-Location $Defaults.ChefRepoPath
			@($ComputerName).foreach({
					knife winrm $_ -m chef-client -x $Credential.UserName -P $Credential.GetNetworkCredential().Password --verbose
				})
		}
		
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
		finally
		{
			Pop-Location	
		}
	}
}
#endregion function Invoke-ChefClient

#region function Remove-Node
function Remove-Node
{
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias('Node')]
		[string]$NodeName
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			if ($PSCmdlet.ShouldProcess($NodeName, 'Remove'))
			{
				Push-Location $Defaults.ChefRepoPath
				knife node delete $NodeName --yes
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
		finally
		{
			Pop-Location
		}
	}
}
#endregion function Remove-Node

#region function Edit-ChefClientConfiguration
function Edit-ChefClientConfiguration
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			& $Defaults.NotepadPath "\\$ComputerName\c$\chef\client.rb"
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}
#endregion function Edit-ChefClientConfiguration

#region function Send-Cookbook
function Send-Cookbook
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Cookbook
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			Push-Location $Defaults.ChefRepoPath
			& $Defaults.KnifeLocation upload $Cookbook.Path --force
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
		finally
		{
			Pop-Location
		}
	}
}
#endregion function Send-Cookbook