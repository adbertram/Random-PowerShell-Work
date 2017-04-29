describe 'Get-FileViaSftp.ps1' {

	$commandName = "$PSScriptRoot\Get-FileViaSftp.ps1"

	mock 'Test-Path' {
		$true
	} -ParameterFilter { $Path -notlike 'Variable:\'}

	mock 'Test-Path' {
		$false
	} -ParameterFilter { $Path -like 'Variable:\'}

	mock 'Install-module'

	mock 'New-SFTPSession' {
		@{
			SessionId = 0
		}
	}

	mock 'Get-SFTPFile'

	mock 'Write-Host'

	mock 'Get-SFTPSession'

	mock 'Remove-SftpSession'

	function Get-Module { param() $true }

	$cred = New-MockObject -Type 'System.Management.Automation.PSCredential'
	$cred | Add-Member -MemberType ScriptMethod -Name 'GetNetworkCredential' -Force -Value { [pscustomobject]@{Password = 'pwhere'} }
	$cred | Add-Member -MemberType NoteProperty -Name 'UserName' -Force -Value 'user'

	$parameterSets = @(
		@{
			Server = 'foo'
			LocalFolderPath = 'C:\'
			RemoteFilePath = 'file.txt'
			Credential = $cred
			TestName = 'Mandatory parameters'
		}
		@{
			Server = 'foo'
			LocalFolderPath = 'C:\'
			RemoteFilePath = 'file.txt'
			Credential = $cred
			Force = $true
			TestName = 'Mandatory parameters / Overwrite Local File'
		}
	)

	$testCases = @{
		All = $parameterSets
		OverWrite = $parameterSets.where({$_.ContainsKey('Force')})
	}

	it 'downloads the expected file: <TestName>' -TestCases $testCases.All {
		param($Server,$LocalFolderPath,$RemoteFilePath,$Credential,$Force)
	
		$result = & $commandName @PSBoundParameters

		$assMParams = @{
			CommandName = 'Get-SftpFile'
			Times = 1
			Exactly = $true
			Scope = 'It'
			ParameterFilter = {
				$LocalPath -eq $LocalFolderPath -and
				$RemoteFile -eq $RemoteFilePath
			 }
		}
		Assert-MockCalled @assMParams
	}

	it 'should not prompt to accept the key when creating the SFTP session: <TestName>' -TestCases $testCases.All {
		param($Server,$LocalFolderPath,$RemoteFilePath,$Credential,$Force)
	
		$result = & $commandName @PSBoundParameters

		$assMParams = @{
			CommandName = 'New-SftpSession'
			Times = 1
			Exactly = $true
			Scope = 'It'
			ParameterFilter = { $AcceptKey }
		}
		Assert-MockCalled @assMParams
	}

	context 'When -Force is used' {

		it 'should overwrite the local file if it exists: <TestName>' -TestCases $testCases.Overwrite {
			param($Server,$LocalFolderPath,$RemoteFilePath,$Credential,$Force)
		
			$result = & $commandName @PSBoundParameters

			$assMParams = @{
				CommandName = 'Get-SFTPFile'
				Times = 1
				Exactly = $true
				Scope = 'It'
				ParameterFilter = { $Force }
			}
			Assert-MockCalled @assMParams
		}
	}


	context 'when a sesion was established' {

		mock 'Get-SFTPSession' {
			$obj = New-MockObject -Type 'SSH.SftpSession'
			$obj | Add-Member -MemberType ScriptMethod -Name 'Disconnect' -Force -Value { 'disconnected' }
			$obj | Add-Member -MemberType NoteProperty -Name 'SessionId' -Force -Value 0 -PassThru
		}

		mock 'Test-Path' {
			$true
		} -ParameterFilter { $Path -like 'Variable:\'}

		it 'should remove the session: <TestName>' -TestCases $testCases.All {
			param($Server,$LocalFolderPath,$RemoteFilePath,$Credential,$Force)
		
			$result = & $commandName @PSBoundParameters

			$assMParams = @{
				CommandName = 'Remove-SftpSession'
				Times = 1
				Exactly = $true
				Scope = 'It'
				ParameterFilter = { $SftpSession }
			}
			Assert-MockCalled @assMParams
		}
	}
	

	context 'when required modules are not available' {

		function Get-Module { param() }

		it 'downloads all required modules: <TestName>' -TestCases $testCases.All {
			param($Server,$LocalFolderPath,$RemoteFilePath,$Credential,$Force)
		
			$result = & $commandName @PSBoundParameters

			$assMParams = @{
				CommandName = 'Install-Module'
				Times = 1
				Exactly = $true
				Scope = 'It'
				ParameterFilter = { $Name -eq 'Posh-SSH' }
			}
			Assert-MockCalled @assMParams
		}
	}
	
}