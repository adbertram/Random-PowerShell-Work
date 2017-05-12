function ShowMenu
{
	<#
		.SYNOPSIS
			A helper function to display a menu when a test fails.
	
		.EXAMPLE
			PS> ShowMenu -Title 'What to do' -ChoiceMessage 'Should I do it?'
	
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Title,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ChoiceMessage,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$NoMessage = 'No thanks'
	)

	$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", $ChoiceMessage
	$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", $NoMessage
	$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
	PromptChoice -Title $Title -ChoiceMessage $ChoiceMessage -options $options
}

function PromptChoice {
	param(
		$Title,
		$ChoiceMessage,
		$Options
	)
	$host.ui.PromptForChoice($Title, $ChoiceMessage, $options, 0)
}

function GetRequiredManifestKeyParams
{
	<#
		.SYNOPSIS
			A helper function to retrieve values for the required manifest keys from the user.
	
		.EXAMPLE
			PS> GetRequiredManifestKeyParams
	
	#>
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string[]]$RequiredKeys = @('Description','Version','ProjectUri','Author')
	)
	
	$paramNameMap = @{
		Version = 'ModuleVersion'
		Description = 'Description'
		Author = 'Author'
		ProjectUri = 'ProjectUri'
	}
	$params = @{ }
	foreach ($val in $RequiredKeys) {
		$result = Read-Host -Prompt "Input value for module manifest key: [$val]"
		$paramName = $paramNameMap.$val
		$params.$paramName = $result
	}
	$params
}

function Invoke-Test {
	param(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$TestName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Test','Fix')]
		[string]$Action,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[object]$Module
	)
	
	$testHt = $moduleTests | where { $_.TestName -eq $TestName}
	$actionName = '{0}{1}' -f $Action,'Action'
	& $testHt.$actionName -Module $Module
}

function Publish-PowerShellGalleryModule {
	<#
		.SYNOPSIS
			This script is a script designed to remove all barriers to entry when publishing modules to the PowerShell
			Gallery. Before running, ensure the NuGetApiKey parameter has a default parameter value.

		.DESCRIPTION
			This script has two different purposes; to ensure your module meets all official Gallery requirements and to
			assist in creating your own "requirements". As-is, the script ensure your module is Gallery-ready by checking for
			all official requirements but also performs a couple extra tests. It's purpose is to provide a foundation to
			add upon to for your own "requirements" for the Gallery.

			Each run will ensure a module manifest is in the same folder as the ModuleFilePath and will ensure that manifest 
			has all of the required keys. Also, it will run Test-ModuleManifest to ensure the result passes there as well.

		.EXAMPLE
			PS> Publish-PowerShellGalleryModule -ModuleFilePath C:\Foo\Foo.psm1 -NuGetApiKey XXXXXXXXX

			This example will check the Foo module for all pre-defined requirements and fix as necessary. 

		.EXAMPLE
			PS> Publish-PowerShellGalleryModule -ModuleFilePath C:\Modules\Foo.psm1 -RunOptionalTests

			This example assumes that you've included a default value for the NuGetApiKey.

		.PARAMETER ModuleFilePath
			A mandatory string parameter representing the file path to a PSM1 file. The folder path also represents the 
			folder that will be searched for a matching module manifest as well.

		.PARAMETER RunOptionalTests
			A switch parameter to enable if you'd like to run any optional tests. Currently, the only optional tests is a
			Pester tests file. If a file matching $ModuleName.Tests.ps1 is not in the same folder as the PSM1, it will
			notice this and prompt to create a simple template.

			To add more tests, just add a hashtable to the $moduleTests array by copying an existing one ensuring
			that the Mandatory key value is as expected.

		.PARAMETER NuGetApiKey
			A optional PowerShell parameter yet required Gallery attribute representing the NuGet API key provided when
			signing up for an account with the PowerShell Gallery. This can be found by going to the URL
			https://www.powershellgallery.com/users/account/LogOn?returnUrl=%2F. It is recommended that your key be placed
			as the default parameter value to remove the need of providing it each time.

		.PARAMETER PublishToGallery
			An optional switch parameter to use if you'd like to automatically published the tested module to the PowerShell Gallery.
			If this isn't used, you will be prompted to publish.
	#>

	[CmdletBinding(DefaultParameterSetName = 'ByName')]
	param(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({
			if (-not (Test-Path -Path $_ -PathType Leaf)) {
				throw "The module $($_) could not be found."
			} else {
				$true
			}
		})]
		[string]$ModuleFilePath,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$RunOptionalTests,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$NuGetApiKey,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$PublishToGallery
	)

	<# 
	Here are all of the individual tests. This is where you can add additional mandatory or optional tests depending on the
	value of the Mandatory key. To add a test, add a hashtable with the same key values. Any test marked as Mandatory will
	always run. Any test marked as Optional will only run with the -RunOptionalTests parameter is used.
	#>
	$moduleTests = @(
		@{
			TestName = 'Module manifest exists'
			Mandatory = $true
			FailureMessage = 'The module manifest does not exist at the expected path.'
			FixMessage = 'Run New-ModuleManifest to create a new manifest'
			FixAction = { 
				param($Module)

				## Gather up all of the requuired key values from the user
				$newManParams = @{ Path = $Module.Path }
				$newManParams += GetRequiredManifestKeyParams

				## Create the new manifest
				Write-Verbose -Message "Running New-ModuleManifest with params: [$($newManParams | Out-String)]"
				New-ModuleManifest @newManParams
			}
			TestAction = {
				param($Module)

				## Module path will always be the PSD1 since we're overriding the property earlier
				if (-not (Test-Path -Path $Module.Path -PathType Leaf)) {
					$false
				} else {
					$true
				}
			}
		}
		@{
			TestName = 'Manifest has all required keys'
			Mandatory = $true
			FailureMessage = 'The module manifest does not have all the required keys populated.'
			FixMessage = 'Run Update-ModuleManifest to update existing manifest'
			FixAction = { 
				param($Module)

				## Have to get the module from the file system again here in case it was just created with New-ModuleManifest
				$Module = Get-Module -Name $Module.Path -ListAvailable

				## Gather up all of the keys required and their values and update the existing manifest.
				$updateManParams = @{ Path = $Module.Path }
				$missingKeys = ($Module.PsObject.Properties | Where-Object -FilterScript { $_.Name -in @('Description','Author','Version') -and (-not $_.Value) }).Name
				if ((-not $Module.LicenseUri) -and (-not $Module.PrivateData.PSData.ProjectUri)) {
					$missingKeys += 'ProjectUri'
				}

				$updateManParams += GetRequiredManifestKeyParams -RequiredKeys $missingKeys
				Update-ModuleManifest @updateManParams
			}
			TestAction = {
				param($Module)

				## Have to get the module again here to either update any new keys New-ModuleManifest just created or, since the 
				## module was originally passed as a PSM1, it has no idea of an already existing manifest anyway.
				$Module = Get-Module -Name $Module.Path -ListAvailable
					
				if ($Module.PsObject.Properties | Where-Object -FilterScript { $_.Name -in @('Description','Author','Version') -and (-not $_.Value) }) {
					$false
				} elseif ((-not $Module.LicenseUri) -and (-not $Module.PrivateData.PSData.ProjectUri)) {
					$false
				} else {
					$true
				}
			}
		}
		@{
			TestName = 'Manifest passes Test-Modulemanifest validation'
			Mandatory = $true
			FailureMessage = 'The module manifest does not pass validation with Test-ModuleManifest'
			FixMessage = 'Run Test-ModuleManifest explicitly to investigate problems discovered'
			FixAction = {
				param($Module)
				Test-ModuleManifest -Path $module.Path
			}
			TestAction = {
				param($Module)
				if (-not (Test-ModuleManifest -Path $Module.Path -ErrorAction SilentlyContinue)) {
					$false
				} else {
					$true
				}
			}
		}
		@{
			TestName = 'Pester Tests Exists'
			Mandatory = $false
			FailureMessage = 'The module does not have any associated Pester tests.'
			FixMessage = 'Create a new Pester test file using a common template'
			FixAction = { 
				param($Module)

				## Create a $ModuleName.Tests.ps1 file using a template inside of the module folder creating a Describe block
				## for each function that's exported inside of the module.
				$pesterTestPath = "$($Module.ModuleBase)\$($Module.Name).Tests.ps1"
				$publicFunctionNames = (Get-Command -Module $Module).Name

				$templateFuncs = ''
				$templateFuncs += $publicFunctionNames | foreach {
					@"
		describe '$_' {
			
		}

"@
				}

				## This is a sample Pester template template that will represnt the contents of the $ModuleName.Tests.ps1 file
				## Optionally, this text could be stored in an external template file as well instead of here as a here string.
				$pesterTestTemplate = @'
#region import modules
$ThisModule = "$($MyInvocation.MyCommand.Path -replace "\.Tests\.ps1$", '').psm1"
$ThisModuleName = (($ThisModule | Split-Path -Leaf) -replace ".psm1")
Get-Module -Name $ThisModuleName -All | Remove-Module -Force

Import-Module -Name $ThisModule -Force -ErrorAction Stop

## If a module is in $Env:PSModulePath and $ThisModule is not, you will have two modules loaded when importing and 
## InModuleScope does not like that. 0.0 will always be the one imported directly from PSM1.
@(Get-Module -Name $ThisModuleName).where({{ $_.version -ne "0.0" }}) | Remove-Module -Force
#endregion

InModuleScope $ThisModuleName {{
{0}
}}
'@ -f $templateFuncs

				Add-Content -Path $pesterTestPath -Value $pesterTestTemplate
			}
			TestAction = {
				param($Module)

				if (-not (Test-Path -Path "$($Module.ModuleBase)\$($Module.Name).Tests.ps1" -PathType Leaf)) {
					$false
				} else {
					$true
				}
			}
		}
	)

	try {

		if (-not $NuGetApiKey) {
			throw @"
The NuGet API key was not found in the NuGetAPIKey parameter. In order to publish to the PowerShell Gallery this key is required. 
Go to https://www.powershellgallery.com/users/account/LogOn?returnUrl=%2F for instructions on registering an account and obtaining 
a NuGet API key.
"@
		}

		$module = Get-Module -Name $ModuleFilePath -ListAvailable

		## Force the manifest to show up if it exists. This is done as an easy way to bring along a manifest reference
		$module | Add-Member -MemberType NoteProperty -Name 'Path' -Value "$($module.ModuleBase)\$($Module.Name).psd1" -Force
		
		if ($RunOptionalTests.IsPresent) {
			$whereFilter = { '*' }
		} else {
			$whereFilter = { $_.Mandatory }
		}

		foreach ($test in ($moduleTests | where $whereFilter)) {
			if (-not (Invoke-Test -TestName $test.TestName -Action 'Test' -Module $module)) {			
				$result = ShowMenu -Title $test.FailureMessage -ChoiceMessage "Would you like to resolve this with action: [$($test.FixMessage)]?"
				switch ($result)
				{
					0 {
						Write-Verbose -Message 'Running fix action...'
						Invoke-Test -TestName $test.TestName -Action 'Fix' -Module $module
					}
					1 { Write-Verbose -Message 'Leaving the problem be...' }
				}
			} else {
				Write-Verbose -Message "Module passed test: [$($test.TestName)]"
			}
		}

		$publishAction = {
			Write-Verbose -Message 'Publishing module...'
			Publish-Module -Name $module.Name -NuGetApiKey $NuGetApiKey
			Write-Verbose -Message 'Done.'
		}
		if ($PublishToGallery.IsPresent) {
			& $publishAction
		} else {
			$result = ShowMenu -Title 'PowerShell Gallery Publication' -ChoiceMessage 'All mandatory tests have passed. Publish it?'
			switch ($result)
			{
				0 {
					& $publishAction
				}
				1 { 
					Write-Host "Postponing publishing. When ready, use this syntax: Publish-Module -Name $($module.Name) -NuGetApiKey $NuGetApiKey"
				}
			}
		}

	} catch {
		Write-Error -Message $_.Exception.Message
	}
}