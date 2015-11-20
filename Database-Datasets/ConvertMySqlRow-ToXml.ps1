function ConvertMySqlRow-ToXml
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory,ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[System.Data.DataRow[]]$Row,
	
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('\.xml$')]
		[ValidateScript({ -not (Test-Path -Path $_ -PathType Leaf) })]
		[string]$Path
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			$xmlWriter = New-Object System.XMl.XmlTextWriter($Path, $Null)
			$xmlWriter.Formatting = 'Indented'
			$xmlWriter.Indentation = 1
			$XmlWriter.IndentChar = "`t"
			$xmlWriter.WriteStartDocument()
			$xmlWriter.WriteComment('This is a list of all the users necessary for whatever app to use.')
			$xmlWriter.WriteStartElement('Users')
			
			foreach ($r in $row)
			{
				$xmlWriter.WriteStartElement('User')
				$xmlWriter.WriteAttributeString('VIN', '123567891')
				
				$xmlWriter.WriteEndElement()
			}
			
			## End the Users element
			$xmlWriter.WriteEndElement()
			
			
			
			<User FirstName="" LastName="" Address="" City="" State="" ZipCode="" />
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
		finally
		{
			$xmlWriter.WriteEndDocument()
			$xmlWriter.Flush()
			$xmlWriter.Close()
		}
	}
}