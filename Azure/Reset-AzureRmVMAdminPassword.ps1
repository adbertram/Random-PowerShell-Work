#Requires @{'ModuleName' = AzureRm.Compute; 'ModuleVersion' = '1.3.1'}
#Requires -Version 4

function Reset-AzureRmVMAdminPassword
{
	<#
	.SYNOPSIS
		This function resets an Azure VM's admin password. To use this, the Azure VM must be a v2 (ARM) VM and must have the
		VM agent installed. In order for the change to apply, you must restart the VM. To do this, you will use the Restart
		parameter.
		
	.EXAMPLE
		PS> Login-AzureRmAccount
		PS> $Credential = Get-Credential
		PS> Get-AzureRmVm -Name MYVM -ResourceGroupName MYRG | Reset-AzureRmVMAdminPassword -Credential $Credential
	
		This example ensures you are authenticated to your Azure subscription, gathers the admin user name and password to change
		on the VM, finds the applicable Azure VM and resets the password inside of the credential. It will not restart automatically
		which will need to be done outside of the function.
		
	.EXAMPLE
		PS> Login-AzureRmAccount
		PS> $Credential = Get-Credential
		PS> Reset-AzureRmVMAdminPassword -VMName MYVM -ResourceGroupName MYRG -Credential $Credential -Restart
	
		This example ensures you are authenticated to your Azure subscription, gathers the admin user name and password to change
		on the VM, finds the applicable Azure VM and resets the password inside of the credential. Once the password has been reset,
		it will then restart the VM to apply the configuration change.
	
	.PARAMETER VMName
		The name of an Azure VM. This has an alias of Name which can be used as pipeline input from the Get-AzureRmVM cmdlet.
	
	.PARAMETER ResourceGroupName
		The name of the resource group the Azure VM is a part of.
	
	.PARAMETER Credential
		The PSCredential object to be used to capture the admin username and password.
	
	.PARAMETER Restart
		A switch parameter that will auto-restart the VM after the password has been changed. This is required for the change
		to apply but optional in the function.
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias('Name')]
		[string]$VMName,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$ResourceGroupName,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$Restart
		
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			$vm = Get-AzureRmVm -Name $VMName -ResourceGroupName $ResourceGroupName
			
			if ($vm.OSProfile.WindowsConfiguration.ProvisionVMAgent -eq $false)
			{
				throw 'VM agent has not been installed.'
			}
			
			$typeParams = @{
				'PublisherName' = 'Microsoft.Compute'
				'Type' = 'VMAccessAgent'
				'Location' = $vm.Location
			}
			
			$typeHandlerVersion = (Get-AzureRmVMExtensionImage @typeParams | Sort-Object Version -Descending | Select-Object -first 1).Version
			
			
			$extensionParams = @{
				'VMName' = $VMName
				'Username' = $vm.OSProfile.AdminUsername
				'Password' = $Credential.GetNetworkCredential().Password
				'ResourceGroupName' = $ResourceGroupName
				'Name' = 'AdminPasswordReset'
				'Location' = $vm.Location
				'TypeHandlerVersion' = $typeHandlerVersion
			}
			
			Write-Verbose -Message 'Resetting admin password...'
			$result = Set-AzureRmVMAccessExtension @extensionParams
			if ($result.StatusCode -ne 'OK')
			{
				throw $result.Error
			}
			
			Write-Verbose -Message 'Successfully changed admin password.'
			
			if ($Restart.IsPresent)
			{
				Write-Verbose -Message 'Restarting VM...'
				$result = $vm | Restart-AzureRmVM
				if ($result.StatusCode -ne 'OK')
				{
					throw $result.Error
				}
				Write-Verbose -Message 'Successfully restarted VM.'
			}
			else
			{
				Write-Warning -Message 'You must restart the VM for the password change to take effect.'
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}