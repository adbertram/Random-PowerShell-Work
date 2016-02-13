#Requires -Module virtualmachinemanager,AzureRM.Compute
#Requires -Version 4

function ConvertTo-AzureSize
{
	<#
	.SYNOPSIS
		This function takes a VMM hardware profile name as input and attempts to find the closest matching Azure instance name
		based on a few rules.
	
		It will search for Azure instances that match the CPU count from the hardware profile and attempt to find the instance
		with the same or greater amount of memory as well.
	
	.EXAMPLE
		PS> ConvertTo-AzureSize -VMMHardwareProfile 'HWP-GP1'
	
		MaxDataDiskCount     : 2
		MemoryInMB           : 3584
		Name                 : Standard_D1_v2
		NumberOfCores        : 1
		OSDiskSizeInMB       : 1047552
		ResourceDiskSizeInMB : 51200
		RequestId            : a6dfba3e-982d-47d9-a3c0-2c734f1545fa
		StatusCode           : OK
		Memory               : 3584
		CPUCount             : 1
	
	.PARAMETER VmmHardwareProfile
		The name of the VMM hardware profile to query from VMM. This is mandatory.
	
	.PARAMETER AzureLocation
		The Azure location to search for available Azure instances. This defaults to 'WestUs'.
	#>
	[CmdletBinding()]
	[OutputType('Selected.Microsoft.Azure.Commands.Compute.Models.PSVirtualMachineSize')]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$VmmHardwareProfile,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$AzureLocation = 'WestUS'
		
	)
	process
	{
		try
		{
			if (-not ($hwProfile = Get-SCHardwareProfile | where { $_.Name -eq $VmmHardwareProfile }))
			{
				throw "Hardware profile not found: [$($VmmHardwareProfile)]"
			}
			
			## Only select Azure instances with the same CPU count, with memory equal to or greater than the hardware profile
			## and only Standard Azure instances choosing only the v2 'D' instances if that's the best match. Do not match
			## any DS VMs.
			$whereFilter = {
				($_.CPUCount -eq $hwProfile.CPUCount) -and
				($_.Memory -ge $hwProfile.Memory) -and
				($_.Name -match '^Standard_(?!DS?\d)\w+?\d+?|Standard_D\d+_v2$')
			}
			
			$azureProperties = @(
			'*',
			@{ Name = 'Memory'; Expression = { $_.MemoryInMb } },
			@{ Name = 'CPUCount'; Expression = { $_.NumberOfCores } }
			)
			
			$sizeParams = @{
				'Property' = $azureProperties
				'Exclude' = 'Memory', 'NumberOfCores'
			}
			
			if (-not ($azureSize = (Get-AzureRmVMSize -Location $AzureLocation | select -Property $azureProperties).where($whereFilter)))
			{
				throw "No Azure server instances found that match hardware profile [$($VmmHardwareProfile)]"
			}
			else
			{
				$azureSize
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}