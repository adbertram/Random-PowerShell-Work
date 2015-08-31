<#	
	===========================================================================
	 Created on:   	1/29/2015 6:22 PM
	 Created by:   	Adam Bertram
	 Filename:     	Sharepoint.psm1
	-------------------------------------------------------------------------
	 Module Name: Sharepoint
	===========================================================================
#>

function Get-SpPurchaseOrder {
	<#
	.SYNOPSIS
		This functions finds a purchase order in Sharepoint
	.PARAMETER PoNumber
		The company purchase order
	#>
	[CmdletBinding()]
	param (
		[string]$PoNumber
	)
	process {
		try {
			if ($PoNumber) {
                $SpPunchSite.Lists["Inkoop / Verkoop"].GetItems()| where {$_.xml -match "ows_Inkooporder='$PoNumber'"}
			} else {
                $SpPunchSite.Lists["Inkoop / Verkoop"].GetItems()
			}
		} catch {
			#Write-Log -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" -LogLevel '3'
			$false
		}
	}
}
function Get-SpOrder {
	<#
	.SYNOPSIS
		This functions finds an order inside a purchase order in Sharepoint.
    .PARAMETER OrderNumber
		The Dell order number
	#>
	[CmdletBinding()]
	param (
		[Parameter()]
        [string]$OrderNumber
	)
	process {
		try {
            if ($OrderNumber) {
				$AllOrders | Where-Object { $_.Title -eq $OrderNumber }
			} else {
                $AllOrders
			}
		} catch {
			#Write-Log -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" -LogLevel '3'
			$false
		}
	}
}
function New-SpOrder {
	<#
	.SYNOPSIS
		This functions adds a Dell order to a purchase order.
	.PARAMETER PurchaseOrder
		The company purchase order Sharepont object to link the Dell order to
	.PARAMETER OrderNumber
		The new Sharepoint order number you'd like to add.
	.PARAMETER TotalCost
		The total cost of the order
	.PARAMETER OrderDate
		The date in which the order was placed
	.PARAMETER PdfAttachemntFileUrl
		The Sharepoint URL to where the PDF you'd like added to this order is found
	.PARAMETER PassThru
		By default, you will get a [bool] $true value if the order was successfully created.  Use this parameter
		to get the [Microsoft.SharePoint.SPListItem] order list item back.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true,ValueFromPipeline = $true)]
		[Microsoft.Sharepoint.Splistitem]$PurchaseOrder,
		[Parameter(Mandatory = $true)]
		[string]$OrderNumber,
		[string]$TotalCost,
		[string]$OrderDate,
		[string]$PdfAttachmentFileUrl,
		[switch]$PassThru
	)
	process {
		try {
			if (Get-SpOrder -OrderNumber $OrderNumber) {
				throw "Order number $OrderNumber already exists"
			}
			$OrderList = $SpPunchSite.Lists["Inkoop items"]
           
			$Order = $OrderList.Items.Add()
			$Order["Title"] = $OrderNumber
			$Order["IWParentWebID"] = "{21cdf5a5-b347-4f4d-8083-76945c99af51}"
			$Order["IWParentListID"] = "{02fe688c-e030-42e4-b724-c39a0b7785ec}"
			$Order["IWParentItemID"] = $PurchaseOrder['Inkoop items']
            
            $PurchaseOrder.Xml -match "ows_Inkooporder='(.*?)'" | Out-Null
            $PoNumber = $Matches[1]

            $Order["inkoopnummer"] = $PoNumber
			$Order["IWFieldName"] = "Inkoop_x0020_items"
			$Order["IWParentLink"] = "$SpSiteUrl/punch/Lists/Inkoop  Verkoop/DispForm.aspx?id=$($PurchaseOrder.ID), $($PurchaseOrder.Title)"
			$Order["Bestellink"] = "http://www.dell.com/support/orderstatus/OrderStatus/Order?c=nl&l=nl&s=biz&SearchByValue=$OrderNumber&VerifyWithValue=NL2812310&SearchID=OrderNumber&VerifyID=CustomerNumber"
			
			if ($TotalCost) {
				$Order["Totaal bedrag"] = $TotalCost
			}
			if ($OrderDate) {
				$Order["Dell besteldatum"] = $OrderDate
				$Order["Geschatte leveringsdatum"] = $OrderDate
			}
			$Order.Update()
			if ($PdfAttachmentFileUrl) {
				$Order | Set-SpOrder -PdfAttachmentFileUrl $PdfAttachmentFileUrl
			}
			if ($PassThru) {
				$Order	
			} else {
				$true	
			}
		} catch {
			#Write-Log -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" -LogLevel '3'
			$false
		}
	}
}
function Set-SpOrder {
	<#
	.SYNOPSIS
		This functions modfies a Sharepoint order.
	.PARAMETER InputObject
		The Sharepoint order object
	.PARAMETER PdfAttachmentFileUrl
		The Sharepoint URL pointing to a PDF file
	.PARAMETER InvoiceNumber
		The Dell invoice that matches to the order
	.PARAMETER DeliveryStatus
		Where the order is at
	.PARAMETER EstimatedDeliveryDate
		When the order should be here
	.PARAMETER PoNumber
		The PO to attach this order to
	.PARAMETER
		By default, this function will return a [bool] value indicating failure or success.  If the PassThru
		parameter is used it will return the [Microsoft.Sharepoint.SPListItem] object that it modified.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Microsoft.Sharepoint.Splistitem]$Order,
		[string]$PdfAttachmentFileUrl,
		[string]$InvoiceNumber,
		[string]$DeliveryStatus,
		[string]$EstimatedDeliveryDate,
		[string]$PoNumber,
		[switch]$PassThru
	)
	process {
		try {
			if ($PdfAttachmentFileUrl) {
				$Split = $PdfAttachmentFileUrl.Split('\')
				$PdfName = $Split[$Split.Length - 1]
				if ($Order.Attachments -contains $PdfName) {
					Write-Warning "Could not attach PDF URL $PdfAttachmentFileUrl to order number $($Order.Title) because it already exists"
				} else {
			        $File = $SpDocSite.GetFile($PdfAttachmentFileUrl).OpenBinary()
			        $Order.Attachments.Add($PdfAttachmentFileUrl, $File)
			        $Order.Update()
				}
			}   
			$UpdatedFields = 0
            if ($InvoiceNumber -and ($Order["Factuurnummer Leverancier"] -ne $InvoiceNumber)) {	
				$Order["Factuurnummer Leverancier"] = $InvoiceNumber
                $UpdatedFields++
			}
			if ($DeliveryStatus -and ($Order["Afleverstatus"] -ne $DeliveryStatus)) {
				$Order["Afleverstatus"] = $DeliveryStatus
                $UpdatedFields++
			}
			if ($EstimatedDeliveryDate -and ($Order["Geschatte leveringsdatum"] -ne $EstimatedDeliveryDate)) {
				$Order["Geschatte leveringsdatum"] = $EstimatedDeliveryDate
                $UpdatedFields++
			}
			if ($PoNumber -and ($Order["inkoopnummer"] -ne $PoNumber)) {
				$Order["inkoopnummer"] = $PoNumber
                $UpdatedFields++
			}
            if ($UpdatedFields -gt 0) {
			    $Order.Update()
            }
			if ($PassThru) {
				$Order
			} else {
				$true
			}
		} catch {
			Write-Error -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
			$false
		}
	}
}

function Remove-SpOrder {
	<#
	.SYNOPSIS
		This functions removes a Sharepoint order.
	.PARAMETER Order
		The Sharepoint order object
	.PARAMETER OrderNumber
		The order number of the Sharepoint order
	#>
	[CmdletBinding(DefaultParameterSetName = 'OrderObject')]
	param (
		[Parameter(ValueFromPipeline = $true,ParameterSetName = 'OrderObject')]
		[Microsoft.SharePoint.SPListItem]$Order,
		[Parameter(ParameterSetName = 'OrderNumber')]
		[string]$OrderNumber
	)
	process {
		try {
			if ($Order) {
				$Order.Delete()
			} elseif ($OrderNumber) {
				$Order = Get-SpOrder -OrderNumber $OrderNumber
				$Order.Delete()
			}
			$true
		} catch {
			#Write-Log -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" -LogLevel '3'
			$false
		}
	}
}