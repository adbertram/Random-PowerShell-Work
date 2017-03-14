. .\Publish-PowerShellGalleryModule.ps1

$commandName = 'Publish-PowerShellGalleryModule'

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

	mock 'Get-Module' {
		@{
			Path = 'manifestpath'
			Description = 'deschere'
			Author = 'authhere'
			Version = 'verhere'
			LicenseUri = 'licurihere'
		}
	}

	mock 'Update-ModuleManifest'

	mock 'Publish-Module'

	mock 'Invoke-Test'
#endregion

it 'should run all optional tests if chosen' {
	& $commandName -ModuleFilePath 'C:\module.psm1' -RunOptionalTests


}

it 'should run all mandatory tests' {

}

it 'should call Publish-Module with the expected parameters' {
		
}

context 'When immediately publishing to the PowerShell Gallery' {

	it 'should call Publish-Module with the expected parameters' {

	}
}

context 'When no NuGet API key is passed' {

	it 'throws an exception' {
		s
	}
}

context 'When no module manifest exists' {

	it 'should run the fix action' {

	}
}

context 'When a module manifest exists but does not have required keys' {

	it 'should run the fix action' {

	}
}

context 'When no Pester tests are found' {

	it 'should run the fix action' {

	}

	it 'should create a describe block for each exported module function' {

	}
}

context 'When it does not pass Test-ModuleManifest' {

	it 'should run the fix action' {

	}
}

context 'When the module is not found' {

	it 'should throw an exception' {

	}
}


