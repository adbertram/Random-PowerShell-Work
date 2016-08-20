function Get-FunctionDefaultParameter
{
	<#
	.SYNOPSIS
	This is a function that will find all of the default parameter names and values from a given function.
	
	.EXAMPLE
	PS> Get-FunctionDefaultParameter -FunctionName Get-Something
	
	.PARAMETER FuntionName
	A mandatory string parameter representing the name of the function to find default parameters to.
	
	#>
	[CmdletBinding()]
	[OutputType([hashtable])]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$FunctionName	
	)
	try
	{
		$ast = (Get-Command $FunctionName).ScriptBlock.Ast
		
		$select = @{ n = 'Name'; e = { $_.Name.VariablePath.UserPath } },
		@{ n = 'Value'; e = { $_.DefaultValue.Extent.Text -replace "`"|'" } }
		
		$ht = @{}
		@($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.ParameterAst] }, $true) | Where-Object { $_.DefaultValue } | Select-Object $select).foreach({
			$ht[$_.Name] = $_.Value	
			})
		$ht
		
	}
	catch
	{
		Write-Error -Message $_.Exception.Message
	}
}