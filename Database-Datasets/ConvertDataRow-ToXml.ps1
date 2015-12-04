#Requires -Version 4

function ConvertDataRow-ToXml
{
	<#
	.SYNOPSIS
		This function converts a [System.Data.DataRow] object output and creates a XML file from it.

	.DESCRIPTION
		The purpose of this function is to accept one or more database rows, create a XML file and transform each
		row column name into a XML node name.  Each row's value will then turn into the XML node's value. Once created, it
		will output the XML file.

	.PARAMETER Row
		A [System.Data.DataRow] that will typically be output from the Invoke-MySqlQuery or perhaps the Invoke-SqlQuery cmdlet. 
		This can be a single row or multiple rows separated by a comma.  This parameter also accepts pipeline input.

	.PARAMETER ObjectType
		Each row will be a child of this XML parent node. For example, if your data row contains information about a user,
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

		PS> Invoke-MySqlQuery -Query 'select * from users' | ConvertDataRow-ToXml -ObjectType User -Path C:\users.xml
	
		This example would create a XML file in C:\ that looks like this:
	
		<?xml version="1.0"?>
		<Users>
			<User>
				<FirstName>Adam</FirstName>
				<LastName>Bertram</LastName>
				<Address>7684 Shoe Dr.</Address>
				<City>Chicago</City>
				<State>IN</State>
				<ZipCode>65729</ZipCode>
			</User>
		</Users>

	.INPUTS
		System.Data.DataRow

	.OUTPUTS
		System.IO.FileInfo

	.LINK
		https://github.com/adbertram/Random-PowerShell-Work/blob/master/Database-Datasets/ConvertDataRow-ToXml.ps1
	#>	
	
	[CmdletBinding()]
	[OutputType('System.IO.FileInfo')]
	param
	(
		[Parameter(Mandatory,ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[System.Data.DataRow[]]$Row,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ObjectType,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('\.xml$')]
		[ValidateScript({ -not (Test-Path -Path $_ -PathType Leaf) })]
		[string]$Path
	)
	begin {
		$ErrorActionPreference = 'Stop'
		
		$xmlWriter = New-Object System.XMl.XmlTextWriter($Path, $Null)
		$xmlWriter.Formatting = 'Indented'
		$xmlWriter.Indentation = 1
		$XmlWriter.IndentChar = "`t"
		$xmlWriter.WriteStartDocument()
		$xmlWriter.WriteStartElement('{0}s' -f $ObjectType)
	}
	process {
		try
		{
			foreach ($r in $row)
			{
				$properties = $r.psobject.Properties.where{ $_.Value -is [string] -and $_.Name -ne 'RowError' }
				$xmlWriter.WriteStartElement($ObjectType)
				foreach ($prop in $properties)
				{
					Write-Verbose -Message "Adding attribute name [$($prop.Name)] with value [$($prop.Value)]"
					$xmlWriter.WriteElementString($prop.Name, $prop.Value)
				}
				$xmlWriter.WriteEndElement()
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
	end
	{
		$xmlWriter.WriteEndDocument()
		$xmlWriter.Flush()
		$xmlWriter.Close()
		Get-Item -Path $Path
	}
}