function ConvertTo-CleanScript
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Path,
	
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ToRemove = ''
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			$Ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
			
			
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}