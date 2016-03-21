function Start-PesterTest
{
	<#
	.SYNOPSIS
		This function is a helper function for Invoke-Pester. It was built as a way to more easily pass common parameters to your
		Pester tests when performing integration tests. Using this function, you can easily direct tests to different computer names
		and pass credentials to them in case you need to remotely connect to them in your tests.
	
		It also eases passing various other parameters to your tests.
	
	.EXAMPLE
		PS> Start-PesterTest -Path C:\Path\To\PesterTestScript.ps1
	
		This example will call Invoke-Pester using the path to the script but exclude all tests that have a tag of 'Disabled'.
	
	.EXAMPLE
		PS> Start-PesterTest -Path C:\Path\To\PesterTestScript.ps1 -ComputerName MYVM -Credential (Get-Credential)
	
		If the tests you are running require you to connect to a VM and you need to pass a credential for some reason, with this
		example, you will have the $ComputerName and $Credential variables available to you in your tests to use.
		
	.EXAMPLE
		PS> Start-PesterTest -Path C:\Path\To\PesterTestScript.ps1 -Tag Integration
	
		If you have tags on your tests called 'Integration', this will only kick off tests with those tags.
	
	.PARAMETER Path
		The file path to the Pester PowerShell script that contains the tests. This is mandatory.
	
	.PARAMETER ComputerName
		If you need to reference a computer name in your Pester tests, use this parameter to pass the $ComputerName variable
		into your tests to reference.
	
	.PARAMETER Credential
		If you need to reference a computer name in your Pester tests and need a credential, use this parameter to pass the $Credential
		variable into your tests to reference.
	
	.PARAMETER DomainName
		If you need to reference a domain name in your Pester tests, use this parameter to pass the $DomainName
		variable into your tests to reference.
	
	.PARAMETER TestName
		A name of a Pester describe block. This is used if you just need to run a single tests in your file. By default, all
		tests excluding tests with the Disabled tag are ran.
	
	.PARAMETER ExcludeTag
		By default, all tests with the Exclude tag are excluded from running. Use this to override this to exclude additional tags.
	
	.PARAMETER Tag
		Use this parameter to only run tests with certain tags. You can specify one or more here.	
	
	.INPUTS
		None. You cannot pipe objects to function-name.
	
	.OUTPUTS
		output-type. function-name returns output-type-desc
		#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path $_ })]
		[string]$Path,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$DomainName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$TestName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string[]]$ExcludeTag = 'Disabled',
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string[]]$Tag
	)
	process
	{
		$scriptParams = @{ }
		if ($PSBoundParameters.ContainsKey('ComputerName')) {
			$scriptParams = @{ 'ComputerName' = $ComputerName }
		}
		
		if ($PSBoundParameters.ContainsKey('Credential'))
		{
			$scriptParams.Credential = $Credential
		}
		if ($PSBoundParameters.ContainsKey('DomainName'))
		{
			$scriptParams.DomainName = $DomainName
		}
		
		$pesterScrParams = @{ 'Path' = $Path }
		if ($scriptParams.Keys)
		{
			$pesterScrParams.Parameters = $scriptParams
		}
		
		$invPesterParams = @{
			'Script' = $pesterScrParams
			'ExcludeTag' = $ExcludeTag
		}
		
		if ($PSBoundParameters.ContainsKey('Tag'))
		{
			$invPesterParams.Tag = $Tag
		}
		
		if ($PSBoundParameters.ContainsKey('TestName'))
		{
			$invPesterParams.TestName = $TestName
		}
		
		Invoke-Pester @invPesterParams
	}
}