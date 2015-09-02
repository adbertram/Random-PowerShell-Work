function Get-SqlInstance {
	param (
		[ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1 })]
		[Parameter(ValueFromPipeline)]
		[string[]]$Computername = 'localhost'
	)
	process {
		foreach ($Computer in $Computername) {
			try {
				$SqlServices = Get-Service -ComputerName $Computer -DisplayName 'SQL Server (*'
				if (!$SqlServices) {
					Write-Verbose 'No instances found'
				} else {
					$InstanceNames = $SqlServices | Select-Object @{ n = 'Instance'; e = { $_.DisplayName.Trim('SQL Server ').Trim(')').Trim('(') } } | Select-Object -ExpandProperty Instance
					foreach ($InstanceName in $InstanceNames) {
						[pscustomobject]@{ 'Computername' = $Computer; 'Instance' = $InstanceName }
					}
				}
			} catch {
				Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
				$false
			}
		}
	}
}

function Get-SqlLogin {
	param (
		[ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1 })]
		[Parameter(ValueFromPipelineByPropertyName)]
		[string[]]$Computername = 'localhost',
		[Parameter(ValueFromPipelineByPropertyName)]
		[string]$Instance,
		[string]$Name
	)
	begin {
		[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
	}
	process {
		try {
			foreach ($Computer in $Computername) {
				$Instances = Get-SqlInstance -Computername $Computer
				foreach ($Instance in $Instances.Instance) {
					if ($Instance -eq 'MSSQLSERVER') {
						$Server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $Computer
					} else {
						$Server = new-object ('Microsoft.SqlServer.Management.Smo.Server') "$Computer`\$Instance"
					}
					if (!$Name) {
						$Server.Logins
					} else {
						$Server.Logins | where { $_.Name -eq $Name }
					}
				}
			}
		} catch {
			Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
			$false
		}
	}
}

function New-SqlLogin {
	param (
		[ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1 })]
		[Parameter(ValueFromPipelineByPropertyName)]
		[string]$Computername = 'localhost',
		[Parameter(ValueFromPipelineByPropertyName)]
		[string]$Instance,
		[string]$Username,
		[ValidateSet('AsymmetricKey', 'Certificate', 'SqlLogin', 'WindowsGroup', 'WindowsUser')]
		[string]$Type
	)
	begin {
		[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
	}
	process {
		try {
			$Server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $Computername
			## https://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.logintype.aspx
			$Login = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $Server, $Username
			$Login.LoginType = $Type
			$true
		} catch {
			Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
			$false
		}
	}
}