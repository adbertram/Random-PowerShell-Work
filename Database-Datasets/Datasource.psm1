function Add-SqlRow {
	<#
	.SYNOPSIS

	.EXAMPLE
		PS> Add-SqlRow -Computername SQLSERVER -Database MYDATABASE -Table MYTABLE -Row [pscustomobject]@{'FirstName' = 'Adam';'LastName' = 'Bertram'; 'ID' = 12345}
	
		This example adds a row to the MYTABLE table in the MYDATABASE database on the SQL server SQLSERVER.  The table consists of 3 fields;
		FirstName, LastName and ID.  This creates a row 'Adam,Bertram,12345'
	.PARAMETER Computername
		The computer that is hosting the SQL database
	.PARAMETER Database
		The name of the SQL database
	.PARAMETER Table
		The name of the SQL database table
	.PARAMETER Row
		A hashtable of a single row containing keys as field names and values as field values.  If any fields are missing, the field values
		in the database will be null.
	.PARAMETER Schema
		The schema of the table
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$Computername,
		[Parameter(Mandatory)]
		[string]$Database,
		[Parameter(Mandatory)]
		[string]$Table,
		[Parameter(ValueFromPipelineByPropertyName,ValueFromPipeline,Mandatory)]
		[object]$Row,
		[string]$Schema = 'dbo'
	)
	
	begin {
		$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
		Set-StrictMode -Version Latest
		try {
			$RequiredModule = 'SQLPSX'
			#if ((Get-Module -ListAvailable).Name -notcontains $RequiredModule) {
			#	throw "The required module '$RequiredModule' is not available"
			#}
		} catch {
			Write-Error $_.Exception.Message
			return
		}
	}
	
	process {
		try {
			$InsertString = "INSERT INTO $Table ($($Row.PSObject.Properties.Name -join ',')) VALUES ($($Row.PSObject.Properties.Value -join ','))"
			$InsertString
			#Set-SqlData -sqlserver $Computername -dbname $Database -qry $InsertString
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Get-SqlRow {
	<#
	.SYNOPSIS

	.EXAMPLE
		
	.PARAMETER

	#>
	[CmdletBinding()]
	param ()
	
	begin {
		$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
		Set-StrictMode -Version Latest
		try {
			
		} catch {
			Write-Error $_.Exception.Message
			return
		}
	}
	
	process {
		try {
			
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Set-SqlRow {
	<#
	.SYNOPSIS

	.EXAMPLE
		
	.PARAMETER

	#>
	[CmdletBinding()]
	param ()
	
	begin {
		$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
		Set-StrictMode -Version Latest
		try {
			
		} catch {
			Write-Error $_.Exception.Message
			return
		}
	}
	
	process {
		try {
			
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Add-CsvRow {
	<#
	.SYNOPSIS

	.EXAMPLE
		
	.PARAMETER

	#>
	[CmdletBinding()]
	param ()
	
	begin {
		$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
		Set-StrictMode -Version Latest
		try {
			
		} catch {
			Write-Error $_.Exception.Message
			return
		}
	}
	
	process {
		try {
			
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Get-CsvRow {
	<#
	.SYNOPSIS

	.EXAMPLE
		PS> Get-CsvRow -FilePath C:\Employees.csv -Row @{'LastName' = 'Bertram'}
	
		This example would find all rows in a CSV file matching the value 'Bertram' in the field 'LastName'
	.PARAMETER FilePath
		The path to where the CSV file lives
	.PARAMETER Row
		A hashtable with keys as field names and values as values.
	#>
	[CmdletBinding(DefaultParameterSetName = 'AllRows')]
	param (
		[Parameter(Mandatory)]
		[ValidateScript({Test-Path -Path $_ -PathType Leaf })]
		[string]$FilePath,
		[Parameter(Mandatory,ParameterSetName='SelectRows')]
		[hashtable]$Row
	)
	
	begin {
		$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
		Set-StrictMode -Version Latest
		try {
			## Ensure the field specified exists in the CSV file
			$ValidFields = (Import-Csv $FilePath | Select-Object -First 1).PSObject.Properties.Name
			if ($ValidFields -notcontains $Row.Keys[0]) {
				throw "The field name '$($Row.Keys[0])' does not exist in CSV file '$FilePath'"
			}
		} catch {
			Write-Error $_.Exception.Message
			return
		}
	}
	
	process {
		try {
			if ($Row) {
				$Field = $Row.Keys[0]
				$Value = $Row.Values[0]
				Import-Csv -Path $FilePath | Where-Object { $_.$Field -eq $Value }
			} else {
				Import-Csv -Path $FilePath
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Set-CsvRow {
	<#
	.SYNOPSIS

	.EXAMPLE
		
	.PARAMETER

	#>
	[CmdletBinding()]
	param ()
	
	begin {
		$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
		Set-StrictMode -Version Latest
		try {
			
		} catch {
			Write-Error $_.Exception.Message
			return
		}
	}
	
	process {
		try {
			
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Add-ExcelRow {
	<#
	.SYNOPSIS

	.EXAMPLE
		
	.PARAMETER

	#>
	[CmdletBinding()]
	param ()
	
	begin {
		$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
		Set-StrictMode -Version Latest
		try {
			
		} catch {
			Write-Error $_.Exception.Message
			return
		}
	}
	
	process {
		try {
			
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Get-ExcelRow {
	<#
	.SYNOPSIS

	.EXAMPLE
		
	.PARAMETER

	#>
	[CmdletBinding()]
	param ()
	
	begin {
		$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
		Set-StrictMode -Version Latest
		try {
			
		} catch {
			Write-Error $_.Exception.Message
			return
		}
	}
	
	process {
		try {
			
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Set-ExcelRow {
	<#
	.SYNOPSIS

	.EXAMPLE
		
	.PARAMETER

	#>
	[CmdletBinding()]
	param ()
	
	begin {
		$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
		Set-StrictMode -Version Latest
		try {
			
		} catch {
			Write-Error $_.Exception.Message
			return
		}
	}
	
	process {
		try {
			
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}