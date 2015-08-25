function Get-FunctionDefaultParameters
{
	[CmdletBinding()]
	param (
		[string]$FunctionName
	)
	$ast = [System.Management.Automation.Language.Parser]::ParseInput((Get-Command $FunctionName).Definition, [ref]$null, [ref]$null)
	
	$charReplace = '{0}|{1}' -f "'", '"'
	$select = @{ n = 'Name'; e = { $_.Name.VariablePath.UserPath } },
		@{ n = 'Value'; e = { $_.DefaultValue.Extent.Text -replace $charReplace, '' } }
	
	$ast.FindAll({ $args[0] -is [System.Management.Automation.Language.ParameterAst] }, $true) | where { $_.DefaultValue } | select $select
}