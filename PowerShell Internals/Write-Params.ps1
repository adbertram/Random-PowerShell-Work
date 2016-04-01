function Write-Param
{
	<#
	.SYNOPSIS
		Write-Param is a simple function that writes the parameters used for the calling function out to the console. This is useful
		 in debugging situations where you have function "trees" where you have dozens of functions calling each and want to see
		what parameters are being passed to each function via the console.
	
		No need to pass any parameters to Write-Param. It uses the PS call stack to find what function called it and all the parameters
		used.
		
	.EXAMPLE
		function MyFunction {
			param(
				[Parameter()]
				[string]$Param1,
	
				[Parameter()]
				[string]$Param2
			)
	
			Write-Params
		}
	
		PS> MyFunction -Param1 'hello' -Param2 'whatsup'
		
		This example would output the following to the Verbose stream:
	
		Function: Get-LocalGroup - Params used: {Param1=hello, Param2=whatsup}
		
	#>
	[CmdletBinding()]
	param ()
	$caller = (Get-PSCallStack)[1]
	Write-Verbose -Message "Function: $($caller.Command) - Params used: $($caller.Arguments)"
}