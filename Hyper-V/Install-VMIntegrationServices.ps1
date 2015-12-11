function Install-VMIntegrationService
{
	<#
		.SYNOPSIS
			This function remotely connects to a Hyper-V VM and installs Integration Services.
	
		.PARAMETER VM
			A VM object from the Get-VM cmdlet that will be targeted to install Integaation Services on.
	
		.PARAMETER Server
			The Hyper-V host that the VM is running on.
	
		.PARAMETER Credential
			A optional PSCredential object to use if you'd like to authenticate with other credentials.
	
		.EXAMPLE
			PS> Get-VM SERVER1 | Install-VMIntegrationServices
	
			This example installing Integration Services on the VM SERVER1.
	#>
	
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory,ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.HyperV.PowerShell.VirtualMachine[]]$VM,
		
		[Parameter(Mandatory,ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias('ComputerName')]
		[string]$Server,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
	)
	process
	{
		foreach ($v in $VM)
		{
			$v = $v.Name
			Set-VMDvdDrive -ComputerName $Server -VMName $v -Path 'C:\Windows\System32\vmguest.iso'
			$DVDriveLetter = (Get-VMDvdDrive -ComputerName $Server -VMName $v).Id | Split-Path -Leaf
			$params = @{
				'ComputerName' = $v
			}
			if ($PSBoundParameters.ContainsKey('Credential')) {
				$params.Credential = $Credential
			}
			Write-Verbose -Message "Installing integration services on [$($v)] with DVD drive letter [$($DVDriveLetter)]"
			Invoke-Command @params -ScriptBlock {
				if ($ENV:PROCESSOR_ARCHITECTURE -eq 'AMD64')
				{
					$folder = 'amd64'
				}
				else
				{
					$folder = 'x86'	
				}
				Start-Process -FilePath "$($using:DVDriveLetter):\support\$folder\setup.exe" -Args '/quiet /norestart' -Wait				
			}
			
			Write-Verbose -Message "Restarting [$($v)]"
			Restart-Computer @params -Wait -For WinRM -Force
			Set-VMDvdDrive -ComputerName $Server -VMName $v -ControllerNumber 1 -ControllerLocation 0 -Path $null
		}
	}	
}