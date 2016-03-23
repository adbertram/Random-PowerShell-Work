#Requires -Version 4

function Get-FunctionDefaultParameter
{
	<#
	.SYNOPSIS
		This function is used to fine all default parameter values defined in a function. In order for this to work, be sure the 
		function you're specifying is either in a module availabe to be auto-imported or the function has manually been loaded into
		the session.
	
		This function will enumerate all default values in a function and output their values. If it sees a value that's an expression,
		it will expand the expression and output the result rather than just the string representation.
	
	.EXAMPLE
		PS> function MyFunction { param($Param1 = 'Default1',$Param2 = 'Default2') }
		PS> Get-FunctionDefaultParameter -Name MyFunction
	
		Name                           Value
		----                           -----
		Param1                         Default1
		Param2                         Default2
		
	.PARAMETER Name
		The name of the function loaded into the session.
	
	.INPUTS
		None. You cannot pipe objects to function-name.
	
	.OUTPUTS
		System.HashTable
	#>
	[CmdletBinding()]
	[OutputType([hashtable])]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)

	$ast = (Get-Command $Name).ScriptBlock.Ast
	
	$select = @{ n = 'Name'; e = { $_.Name.VariablePath.UserPath } },
	@{ n = 'Value'; e = { $_.DefaultValue.Extent.Text } }
	
	$params = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.ParameterAst] }, $true) | where { $_.DefaultValue } | select $select
	$ht = @{ }
	foreach ($param in $params)
	{
		if ($param.Value -match '\(.*\)')
		{
			$ht[$param.Name] = Invoke-Expression $param.Value
		}
		else
		{
			$ht[$param.Name] = $param.Value -replace "'|`"`""
		}
	}
	$ht
}