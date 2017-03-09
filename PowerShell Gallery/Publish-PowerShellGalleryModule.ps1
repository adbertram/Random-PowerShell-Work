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
	[string]$NuGetApiKey = 'f1212bde-8814-4c78-a2b2-7b80b02ab349'
)

function ShowMenu
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Title,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ChoiceMessage,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$NoMessage
	)

	$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", $ChoiceMessage
	$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", $NoMessage
	$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
	$host.ui.PromptForChoice($Title, $ChoiceMessage, $options, 0)
}

function GetRequiredManifestKeyParams
{
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

$moduleTests = @(
	@{
		TestName = 'Module manifest exists'
		FailureMessage = 'The module manifest does not exist at the expected path.'
		FixMessage = 'Run New-ModuleManifest to create a new manifest'
		FixAction = { 
			param($Module)

			$newManParams = @{ Path = $Module.Path }
			$newManParams += GetRequiredManifestKeyParams

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
		FailureMessage = 'The module manifest does not have all the required keys populated.'
		FixMessage = 'Run Update-ModuleManifest to update existing manifest'
		FixAction = { 
			param($Module)

			## Have to get the module from the file system again here in case it was just created with New-ModuleManifest
			$Module = Get-Module -Name $Module.Path -ListAvailable

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
	
	foreach ($test in $moduleTests) {
		if (-not (& $test.TestAction -Module $module)) {			
			$result = ShowMenu -Title $test.FailureMessage -ChoiceMessage "Would you like to resolve this with action: [$($test.FixMessage)]?"
			switch ($result)
			{
				0 {
					Write-Verbose -Message 'Running fix action...'
					& $test.FixAction -Module $module
				}
				1 { Write-Verbose -Message 'Leaving the problem be...' }
			}
		} else {
			Write-Verbose -Message "Module passed test: [$($test.TestName)]"
		}
	}

	$result = ShowMenu -Title 'PowerShell Gallery Publication' -ChoiceMessage 'Publish it?' -NoMessage 'Do not publish it'
	switch ($result)
	{
		0 {
			Write-Verbose -Message 'Publishing module...'
			Publish-Module -Name $module.Name -NuGetApiKey $NuGetApiKey
			Write-Verbose -Message 'Done.'
		}
		1 { Write-Verbose -Message 'Leaving it be...' }
	}

} catch {
	Write-Error -Message $_.Exception.Message
}