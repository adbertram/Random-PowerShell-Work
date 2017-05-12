. "$PSScriptRoot\Publish-PowerShellGalleryModule.ps1"

$commandName = 'Publish-PowerShellGalleryModule'

describe 'Publish-PowerShellGalleryModule' {
	#region Mocks
		mock 'Test-Path' {
			$true
		}

		mock 'ShowMenu'

		mock 'PromptChoice'

		mock 'GetRequiredManifestKeyParams' {
			@{
				Version = 'ver'
				Description = 'desc'
				Author = 'authorhere'
				ProjectUri = 'urihere'
			}
		}

		mock 'New-ModuleManifest'

		mock 'Test-ModuleManifest' {
			$true
		}

		mock 'Add-Content'

		mock 'Update-ModuleManifest'

		mock 'Publish-Module'

		mock 'Invoke-Test'

		function Get-Module {
			@{
				Path = 'manifestpath'
				Description = 'deschere'
				Author = 'authhere'
				Version = 'verhere'
				LicenseUri = 'licurihere'
				ModuleBase = 'modulebase'
				Name = 'modulename'
			}
		}
	#endregion

	$parameterSets = @(
		@{
			ModuleFilePath = 'C:\module.psm1'
			TestName = 'Mandatory params'
		}
		@{
			ModuleFilePath = 'C:\module.psm1'
			RunOptionalTests = $true
			NuGetApiKey = 'xxxx'
			PublishToGallery = $true
			TestName = 'All tests / Publish to Gallery'
		}
		@{
			ModuleFilePath = 'C:\module.psm1'
			RunOptionalTests = $true
			NuGetApiKey = 'xxxx'
			TestName = 'All tests'
		}
		@{
			ModuleFilePath = 'C:\module.psm1'
			NuGetApiKey = 'xxxx'
			PublishToGallery = $true
			TestName = 'Publish to Gallery'
		}
	)

	$testCases = @{
		All = $parameterSets
		AllTests = $parameterSets.where({$_.ContainsKey('RunOptionalTests')})
		PublishToGallery = $parameterSets.where({$_.ContainsKey('PublishToGallery')})
		NoApi = $parameterSets.where({-not $_.ContainsKey('NuGetApiKey')})
		NugetApi = $parameterSets.where({$_.ContainsKey('NuGetApiKey')})
	}

	it 'should run all mandatory tests: <TestName>' -TestCases $testCases.NugetApi {
		param($ModuleFilePath,$RunOptionalTests,$NuGetApiKey,$PublishGallery)

		$result = & $commandName @PSBoundParameters

		$testNames = 'Module manifest exists','Manifest has all required keys','Manifest passes Test-Modulemanifest validation'
		foreach ($name in $testNames) {
			$assMParams = @{
				CommandName = 'Invoke-Test'
				Times = 1
				Exactly = $true
				Scope = 'It'
				ParameterFilter = { $PSBoundParameters.TestName -eq $name }
			}
			Assert-MockCalled @assMParams
		}

	}

	# context 'When RunOptionalTests is chosen' {

	# 	it 'should run all optional tests: <TestName>' -TestCases $testCases.AllTests {
	# 		param($ModuleFilePath,$RunOptionalTests,$NuGetApiKey,$PublishGallery)
		
	# 		$result = & $commandName @PSBoundParameters
	# 	}

	# }

	# context 'when PublishToGallery is chosen' {

	# 	it 'should call Publish-Module with the expected parameters: <TestName>' -TestCases $testCases.PublishToGallery {
	# 		param($ModuleFilePath,$RunOptionalTests,$NuGetApiKey,$PublishGallery)
		
	# 		$result = & $commandName @PSBoundParameters
	# 	}


	# }

	# context 'When no NuGet API key is passed' {

	# 	it 'return a non-terminating error: <TestName>' -TestCases $testCases.NoApi {
	# 		param($ModuleFilePath,$RunOptionalTests,$NuGetApiKey,$PublishGallery)
		
	# 		$result = & $commandName @PSBoundParameters -ErrorVariable err -ErrorAction SilentlyContinue
	# 		$err.Exception.Message | should match 'The NuGet API key was not found'
	# 	}
	# }

	# context 'When no module manifest exists' {

	# 	it 'should run the fix action' {
	# 		param($ModuleFilePath,$RunOptionalTests,$NuGetApiKey,$PublishGallery)
	# 	}
	# }

	# context 'When a module manifest exists but does not have required keys' {

	# 	it 'should run the fix action' {
	# 		param($ModuleFilePath,$RunOptionalTests,$NuGetApiKey,$PublishGallery)
	# 	}
	# }

	# context 'When no Pester tests are found' {

	# 	it 'should run the fix action' {
	# 		param($ModuleFilePath,$RunOptionalTests,$NuGetApiKey,$PublishGallery)
	# 	}

	# 	it 'should create a describe block for each exported module function' {
	# 		param($ModuleFilePath,$RunOptionalTests,$NuGetApiKey,$PublishGallery)
	# 	}
	# }

	# context 'When it does not pass Test-ModuleManifest' {

	# 	it 'should run the fix action' {
	# 		param($ModuleFilePath,$RunOptionalTests,$NuGetApiKey,$PublishGallery)
	# 	}
	# }

	# context 'When the module is not found' {

	# 	it 'should throw an exception' {

	# 	}
	# }
}

