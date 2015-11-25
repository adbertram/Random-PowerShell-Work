function New-XmlSchema
{
	<#
	.SYNOPSIS
		This function infers a XML schema (XSD) from an existing XML file.

	.DESCRIPTION
		By accepting input for an existing XML file, this function reads the XML file, creates a schema that matches the
		XML structure and then creates a schema file on the file system.  This is useful to quickly create XSDs to validate
		your XML files against in case they may get changed later.

		The XML file will first be checked if it well-formed before the schema is created. Because of this, this function
		depends on the Test-Xml function in the PowerShell Commmunity Extensions module https://pscx.codeplex.com/releases

		Much of the heavy lifting was already done by Will at http://learningpcs.blogspot.com/2012/08/powershell-v3-inferring-schema-xsd-from.html.

	.PARAMETER XmlFilePath
		This is a mandatory parameter that you must use to specify the file path to the XML file. This XML file will be read
		to infer a schema from. This file must exist. The file extension must be XML.

	.PARAMETER SchemaFilePath
		This is a parameter you can specify to point to the future file path of the schema file. The directory
		for this file path must exist. The file can or cannot exist. How the function handles this depends on if the
		-Force parameter is used. The file extension must be XSD. IF this parmaeter is not used, the function will create a
		schema file with the same name as the XML file in the same directory.

	.PARAMETER Force
		Use this parameter if you suspect an existing schema file already exists at SchemaFilePath. If this parameter is used
		and the file already exists, the file will be removed and a new schema will be created.  If this parameter is not used
		and the file already exists, an error will be thrown notifying you that a file exists.  If the schema does not exist,
		this parameter has no effect.

	.EXAMPLE
		PS> New-XmlSchema -XmlFilePath C:\Users.xml -SchemaFielPath C:\Users.xsd

		This example will read the conts of C:\Users.xml to ensure it is well-formed. If so, it will then create a schema
		file and place it at C:\Users.xsd.

	.INPUTS
		None

	.OUTPUTS
		System.IO.FileInfo

	.LINK
		https://github.com/adbertram/Random-PowerShell-Work/blob/master/XML/New-XmlSchema.ps1
	#>	
	
	[CmdletBinding()]
	[OutputType('System.IO.FileInfo')]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[ValidatePattern('\.xml$')]
		[string]$XmlFilePath,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path ($_ | Split-Path -Parent) -PathType Container })]
		[ValidatePattern('\.xsd$')]
		[string]$SchemaFilePath = "$($XmlFilePath | Split-Path -Parent)\$([System.IO.Path]::GetFileNameWithoutExtension($XmlFilePath)).xsd",
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$Force
		
	)
	process {
		try
		{
			$ErrorActionPreference = 'Stop'
			
			if (-not (Get-Module -Name Pscx) -and (-not (Get-Module -Name Pscx -ListAvailable)))
			{
				throw "The PowerShell Community Extensions module is not installed. This module can be downloaded at https://pscx.codeplex.com/releases."
			}
			
			if (Test-Path -Path $SchemaFilePath -PathType Leaf)
			{
				if ($Force.IsPresent)
				{
					Remove-Item -Path $SchemaFilePath
				}
				else
				{
					throw "The schema file path [$($SchemaFilePath)] already exists. Remove the existing schema or use -Force to overwrite."
				}
			}
			
			if (-not (Test-Xml -Path $XmlFilePath))
			{
				throw "The XML file [$($XmlFilePath)] is malformed. Please run Test-Xml against the XML file to see what is wrong."
			}
			
			$reader = [System.Xml.XmlReader]::Create($XmlFilePath)
			
			# Instantiate XmlSchemaSet and XmlSchemaInference to process new XSD
			$schemaSet = New-Object System.Xml.Schema.XmlSchemaSet
			$schema = New-Object System.Xml.Schema.XmlSchemaInference
			
			# Infer schemaSet from XML document in $reader
			$schemaSet = $schema.InferSchema($reader)
			
			# Create new output file
			$xsdFilePath = New-Object System.IO.FileStream($SchemaFilePath, [IO.FileMode]::CreateNew)
			
			# Create XmlTextWriter with UTF8 Encoding to write to file
			$xwriter = New-Object System.Xml.XmlTextWriter($xsdFilePath, [Text.Encoding]::UTF8)
			
			# Set formatting to indented
			$xwriter.Formatting = [System.Xml.Formatting]::Indented
			
			# Parse SchemaSet objects
			$schemaSet.Schemas() | ForEach-Object {
				[System.Xml.Schema.XmlSchema]$_.Write($xwriter)
			}
			
			$xwriter.Close()
			$reader.Close()
			
			if (-not (Test-Xml -Path $XmlFilePath -SchemaPath $SchemaFilePath))
			{
				throw "Schema generation has failed for XML file [$($XmlFilePath)]."
			}
			Get-Item -Path $SchemaFilePath
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}