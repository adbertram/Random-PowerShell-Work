function ConvertMySqlRow-ToJson
{
	<#
	.SYNOPSIS
		This function converts a [System.Data.DataRow] object output from the MySQL module and creates a JSON file from it.

	.DESCRIPTION
		The purpose of this function is to accept input from a MySQL database row, create a JSON file and transform each
		MySQL column name into a JSON node name.  Each row's value will then turn into the JSON node's value. Once created, it
		will output the JSON file.

	.PARAMETER Row
		A [System.Data.DataRow] that will typically be output from the Invoke-MySqlQuery cmdlet inside the MySQL module. This can
		be a single row or multiple rows separated by a comma.  This parameter also accepts pipeline input.

	.PARAMETER ObjectType
		Each row will be a child of this JSON parent node. For example, if your MySQL row contains information about a user,
		a good ObjectType will be User. This is the template object that all rows are a part of.

	.EXAMPLE
		PS> Invoke-MySqlQuery -Query 'select * from users'

		UserID    : 1
		FirstName : Adam
		LastName  : Bertram
		Address   : 7684 Shoe Dr.
		City      : Chicago
		State     : IN
		ZipCode   : 65729

		PS> Invoke-MySqlQuery -Query 'select * from users' | ConvertMySqlRow-ToJson -ObjectType User -Path C:\users.json
	
		This example would create a JSON file in C:\ that looks like this:
	
		[
		    {
		        "FirstName":  "Adam"
		    },
		    {
		        "LastName":  "Bertram"
		    },
		    {
		        "Address":  "7684 Shoe Dr."
		    },
		    {
		        "City":  "Chicago"
		    },
		    {
		        "State":  "IN"
		    },
		    {
		        "ZipCode":  "65729"
		    }
		]

	.INPUTS
		System.Data.DataRow

	.OUTPUTS
		System.IO.FileInfo

	.LINK
		https://github.com/adbertram/Random-PowerShell-Work/blob/master/Database-Datasets/ConvertMySqlRow-ToJson.ps1
	#>	
	
	[CmdletBinding()]
	[OutputType('System.IO.FileInfo')]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[System.Data.DataRow[]]$Row,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('\.json$')]
		[ValidateScript({ -not (Test-Path -Path $_ -PathType Leaf) })]
		[string]$Path
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
		$null = New-Item -Path $Path -ItemType File
	}
	process
	{
		try
		{
			foreach ($r in $row)
			{
				$properties = $r.psobject.Properties.where{ $_.Value -is [string] -and $_.Name -ne 'RowError' }
				$items = [System.Collections.ArrayList]@()
				foreach ($p in $properties)
				{
					$null = $items.Add([PSCustomObject]@{$p.Name = $p.Value })
				}
				$items | ConvertTo-Json | Out-File -Append -FilePath $Path
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
	end
	{	
		Get-Item -Path $Path
	}
}