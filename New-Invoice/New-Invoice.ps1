<#
.SYNOPSIS
	Creates a HTML, XML and PDF invoice.
.DESCRIPTION
	Based off of a XML template, this script reads the template and adds any new field values
	passed to it via parameters from this script.  It then creates either a XML, HTML or PDF file
	based on the extension of the output file you specify.
.NOTES
	Created on: 	11/15/2014
	Created by: 	Adam Bertram
	Filename:		New-Invoice.ps1
.EXAMPLE
	PS> .\New-Invoice.ps1 -InvoiceTitle 'New Title' -InvoiceNumber '12334' -ClientCompany 'new client' -ClientName 'new clent name' -Item @{'Description'='mydsc';'Price'='445';'Quantity'='6'} -Force -TopNote 'this is the top note' -BottomNote 'this is the bottom note' -InvoiceFilePath c:\invoice.pdf

	This example will create a PDF invoice in C:\ called invoice.pdf with a single item and will overwrite any invoice that exists in that location.
.PARAMETER InvoiceTitle
	The title of the invoice
.PARAMETER InvoiceNumber
	The invoice number
.PARAMETER ClientCompany
	Your client's company name
.PARAMETER ClientName
	The person in the company you'd like to send the invoice to
.PARAMETER Item
	One or more items you'd like to add to the invoice.  This can either be a single item as
	a hashtable or multiple hashtables all with required keys of Price,Description and Quantity
.PARAMETER TopNote
	The text to display above the item table
.PARAMETER BottomNote
	The text to display below the item table
.PARAMETER Force
	Use this to overwrite both file paths $XmlInvoiceFIlePath and $HtmlInvoiceFilePath.
.PARAMETER TemplateXmlFilePath
	The file path to where the XML data used to prepopulate the invoice is
.PARAMETER TemplateXslFilePath
	The file path to where the XSL styling sheet is located
.PARAMETER InvoiceFilePath
	The file that will be output containing your invoice data
.LINK
	http://www.psclistens.com/blog/2014/3/powershell-tip-convert-html-to-pdf.aspx
	http://pdfgenerator.codeplex.com
#>
[CmdletBinding()]
[OutputType()]
param (
	[Parameter(Mandatory)]
	[string]$InvoiceTitle,
	[Parameter(Mandatory)]
	[string]$InvoiceNumber,
	[Parameter(Mandatory)]
	[string]$ClientCompany,
	[Parameter(Mandatory)]
	[string]$ClientName,
	[Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
	[hashtable[]]$Item,
	[Parameter()]
	[string]$TopNote,
	[Parameter()]
	[string]$BottomNote,
	[Parameter()]
	[switch]$Force,
	[Parameter()]
	[ValidateScript({ Test-Path -Path $_ -PathType Leaf})]
	[string]$TemplateXmlFilePath = "$PSScriptRoot\InvoiceTemplate.xml",
	[Parameter()]
	[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
	[string]$TemplateXslFilePath = "$PSScriptRoot\InvoiceTemplate.xsl",
	[Parameter()]
	[string]$InvoiceFilePath = "$PSScriptRoot\Invoice.pdf"
)

begin {
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	Set-StrictMode -Version Latest
	try {
		## Check to ensure an invoice doesn't already exist if Force was not chosen
		if (!$Force.IsPresent) {
			if (Test-Path -Path $InvoiceFilePath -PathType Leaf) {
				throw 'Existing invoice already exists at specified path.  To overwrite, use the -Force parameter'
			}
		}
		
		function New-InvoiceItem ($ItemDescription, $ItemPrice, $ItemQuantity) {
			## Adds a new item to the invoice
			$NewItem = $InvoiceXml.CreateElement("Item")
			[void]$NewItem.AppendChild($InvoiceXml.CreateElement("Description"))
			[void]$NewItem.AppendChild($InvoiceXml.CreateElement("Price"))
			[void]$NewItem.AppendChild($InvoiceXml.CreateElement("Quantity"))
			$NewItem.Description = $ItemDescription
			$NewItem.Price = $ItemPrice
			$NewItem.Quantity = $ItemQuantity
			[void]$InvoiceXml.Invoice.AppendChild($NewItem)
		}
		
		Function ConvertTo-PDF {
			[CmdletBinding()]
			param(
				[Parameter(ValueFromPipeline)]
				[string]$Html,
				[Parameter()]
				[string]$FileName
			)
			begin {
				$DllLoaded = $false
				$PdfGenerator = "$PsScriptRoot\NReco.PdfGenerator.dll"
				if (Test-Path $PdfGenerator) {
					try {
						$Assembly = [Reflection.Assembly]::LoadFrom($PdfGenerator)
						$PdfCreator = New-Object NReco.PdfGenerator.HtmlToPdfConverter
						$DllLoaded = $true
					} catch {
						Write-Error ('ConvertTo-PDF: Issue loading or using NReco.PdfGenerator.dll: {0}' -f $_.Exception.Message)
					}
				} else {
					Write-Error ('ConvertTo-PDF: NReco.PdfGenerator.dll was not found.')
				}
			}
			PROCESS {
				if ($DllLoaded) {
					$ReportOutput = $PdfCreator.GeneratePdf([string]$HTML)
					Add-Content -Value $ReportOutput -Encoding byte -Path $FileName
				} else {
					Throw 'Error Occurred'
				}
			}
			END { }
		}
	
	
} catch {
	Write-Error $_.Exception.Message
	break
}
}

process {
	try {
		Write-Verbose 'Building XML object'
		## Build the initial XML object with default values from template XML
		Write-Verbose "Getting template XML file $TemplateXmlFilePath"
		$script:InvoiceXml = [xml](Get-Content $TemplateXmlFilePath)
		
		## Add per-invoice specific attributes to the XML object
		$InvoiceXml.Invoice.InvoiceTitle = $InvoiceTitle
		$InvoiceXml.Invoice.Date = (Get-Date).ToShortDateString()
		$InvoiceXml.Invoice.ClientCompany = $ClientCompany
		$InvoiceXml.Invoice.ClientName = $ClientName
		$InvoiceXml.Invoice.InvoiceNumber = $InvoiceNumber
		$InvoiceXml.Invoice.TopNote = $TopNote
		$InvoiceXml.Invoice.BottomNote = $BottomNote
		
		## Add each item to the invoice XML object
		foreach ($i in $Item) {
			if (!($i.ContainsKey('Description')) -or !($i.ContainsKey('Price')) -or !($i.ContainsKey('Quantity'))) {
				Write-Warning "Item found that does not have all necessary fields to add to invoice"
			} else {
				Write-Verbose "Adding invoice item '$($i.Description)' to invoice"
				New-InvoiceItem -ItemDescription $i.Description -ItemPrice $i.Price -ItemQuantity $i.Quantity
			}
		}
		
		## Remove any existing invoices if they exist
		Write-Verbose "Removing existing invoice '$InvoiceFilePath'"
		Remove-Item -Path $InvoiceFilePath -Force -ea 'SilentlyContinue'
		
		## Save the invoice XML object to file
		if (([System.IO.FileInfo]$InvoiceFilePath).Extension -eq '.xml') {
			$XmlOutput = $InvoiceFilePath
		} else {
			$XmlOutput = "$PsScriptRoot\TempXml.xml"
		}
		Write-Verbose "Saving XML file output as '$XmlOutput'"
		$InvoiceXml.Save($XmlOutput)
		
		Write-Verbose "Loading XSL file '$TemplateXslFilePath'"
		$xslt = New-Object System.Xml.Xsl.XslCompiledTransform
		$xslt.Load($TemplateXslFilePath)
		
		if (([System.IO.FileInfo]$InvoiceFilePath).Extension -eq '.html') {
			$HtmlOutput = $InvoiceFilePath
		} else {
			$HtmlOutput = "$PsScriptRoot\TempHtml.Html"
		}
		Write-Verbose "Transforming XML to HTML file '$HtmlOutput'"
		$xslt.Transform($XmlOutput, $HtmlOutput)

	} catch {
		Write-Error $_.Exception.Message
	}
}
end {
	try {
		switch (([System.IO.FileInfo]$InvoiceFilePath).Extension) {
			'.xml' {
				Write-Verbose "XML output chosen.  Removing temporary HTML file '$HtmlOutput'"
				Remove-Item -Path $HtmlOutput -Force -ea 'SilentlyContinue'
			}
			'.html' {
				Write-Verbose "HTML output chosen.  Removing temporary XML file '$XmlOutput'"
				Remove-Item -Path $XmlOutput -Force -ea 'SilentlyContinue'
			}
			'.pdf' {
				Write-Verbose "Converting '$HtmlOutput' content to PDF file '$InvoiceFilePath'"
				ConvertTo-PDF -Html (Get-Content $HtmlOutput -Raw) -FileName $InvoiceFilePath
				Write-Verbose "PDF output chosen.  Removing temporary HTML and XML files"
				Remove-Item -Path $HtmlOutput -Force -ea 'SilentlyContinue'
				Remove-Item -Path $XmlOutput -Force -ea 'SilentlyContinue'
			}
		}
	} catch {
		Write-Error $_.Exception.Message	
	}
}