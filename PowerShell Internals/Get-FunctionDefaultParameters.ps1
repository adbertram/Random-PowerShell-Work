function Get-FunctionDefaultParameters
{
	[CmdletBinding()]
	param (
		[string]$FunctionName
	)
	$ast = (Get-Command $FunctionName).ScriptBlock.Ast
	
	$charReplace = '{0}|{1}' -f "'", '"'
	$select = @{ n = 'Name'; e = { $_.Name.VariablePath.UserPath } },
	@{ n = 'Value'; e = { $_.DefaultValue.Extent.Text -replace $charReplace, '' } }
	
	$params = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.ParameterAst] }, $true) | where { $_.DefaultValue } | select $select
	$ht = @{ }
	foreach ($param in $params)
	{
		$ht[$param.Name] = $param.Value
	}
	$ht
}