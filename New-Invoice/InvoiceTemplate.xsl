<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="html"/>
    <xsl:template match="Invoice">
        <xsl:text disable-output-escaping='yes'>&lt;!DOCTYPE html&gt;</xsl:text>
        <html>
            <head>
                <title></title>
                <style>
input {
    border: 0;
    border: 1px;
    background: none;
    padding: 0;
    font-size: 15px;
    color: #222;
    font-family: "Helvetica Neue",arial,sans;
    line-height: 23px;
}

input, textarea {
    background: transparent;
    border: 1px;
}

#header input {
    width: 400px;
    margin: 0;
    padding: 0;
}

#company {
    font-size: 25px;
    font-weight: bold;
    padding-top: 15px;
    line-height: 56px;
    height: 56px;
    width: 420px !important;
}

input#title {
    font-size: 35px;
    font-weight: bold;
    height: 50px;
    margin-bottom: 0;
    text-align: right;
}

input.rr {
    text-align: right;
}

#address, #meta {
    margin-top: 15px;
}

.client {
    font-weight: bold;
    font-size: 18px;
    line-height: 24px;
}

textarea.notes {
    padding: 4px 70px 0px 70px;
    margin: 0 auto;
    font-family: "Helvetica Neue",arial,sans;
    font-size: 14px;
    background: none;
    line-height: 21px;
    border: 0;
    resize: none;
    font-size: 15px;
    width: 680px;
    overflow: hidden;
}

thead th input, tfoot th input, tfoot th.noteditable {
    background: rgba(0,0,0,0.1);
}

#total input, #total .noteditable {
    background: rgba(0,0,0,0.2);
}

table input {
    margin: 0 !important;
    width: 100% !important;
    margin-right: -10px;
    padding: 0!important;
    margin-top: -1px;
    line-height: 24px;
    text-indent: 10px;
    font-size: 14px;
    font-family: "Helvetica Neue",arial,sans;
}

table td, table th, table input {
    height: 25px !important;
}

tfoot tr th {
    border-top: 1px solid #aaa;
}

th input {
    font-weight: bold;
}

td, thead th {
    border-right: 1px solid #aaa;
}

table {
    margin-top: -5px;
    font-size: 14px;
    border: 1px solid #aaa;
    border-collapse: separate;
    border-spacing: 0;
    vertical-align: middle;
    width: 100%;
}

tbody td: last-child {
    font-weight: bold;
}

.noteditable {
    text-indent: 10px;
}

body {
    line-height: 1.5;
    background: white;
    font-size: 75%;
    color: #222;
    background: #fff;
    font-family: "Helvetica Neue", Arial, Helvetica, sans-serif;
}

th, td {
    text-align: left;
    font-weight: normal;
    float: none !important;
    vertical-align: middle;
}

textarea {
    width: 390px;
    height: 250px;
    padding: 5px;
}

.container {
    width: 820px;
    margin: 0 auto;
}

.span-2, .span-4, .span-10, .span-12 {
    float: left;
    margin-right: 20px;
}

.last {
    margin-right: 0;
}

.span-2 {
    width: 50px;
}

.span-4 {
    width: 120px;
}

.span-10 {
    width: 330px;
}

.span-12 {
    width: 400px;
}

input.span-2, textarea.span-2 {
    width: 38px;
}

input.span-4, textarea.span-4 {
    width: 108px;
}

input.span-10, textarea.span-10 {
    width: 318px;
}

hr {
    background: #ddd;
    color: #ddd;
    clear: both;
    float: none;
    width: 100%;
    height: 1px;
    margin: 0;
    border: none;
}
                </style>
                <script>
function updateTotals() {
    var table = document.getElementById('Items');
    var invoiceTotal = 0;
    for (var i = 0, row; row = table.rows[i]; i++) {
        if (!row.classList.contains('Item')) {
            continue;
        }
        var quantity = parseFloat(row.getElementsByClassName('ItemQuantity')[0].value);
        var price    = parseFloat(row.getElementsByClassName('ItemPrice')[0].value);
        var total    = quantity * price;
        row.getElementsByClassName('ItemTotal')[0].innerHTML = total;
        invoiceTotal += total;
    }
    document.getElementById('InvoiceTotal').innerHTML = invoiceTotal;
}

function updateHeight(textarea) {
    textarea.style.height = 'auto';
    textarea.style.height = textarea.scrollHeight + 'px';
}

function init() {
    updateHeight(document.getElementById('TopNote'));
    updateHeight(document.getElementById('BottomNote'));
}
                </script>
            </head>
            <body onload="init()">
                <div id="invoice" class="container">
                    <div id="header">
                        <input id="company" class="span-12 ll"><xsl:attribute name="value"><xsl:value-of select="MyCompany"/></xsl:attribute></input>
                        <input id="title" class="span-12 last rr"><xsl:attribute name="value"><xsl:value-of select="InvoiceTitle"/></xsl:attribute></input>
                        <div id="address" class="span-12">
                            <input id="MyAddress" class="ll"><xsl:attribute name="value"><xsl:value-of select="MyAddress"/></xsl:attribute></input>
                            <input id="MyCityState" class="ll"><xsl:attribute name="value"><xsl:value-of select="MyCityState"/></xsl:attribute></input>
							<input id="MyZipCode" class="ll"><xsl:attribute name="value"><xsl:value-of select="MyZipCode"/></xsl:attribute></input>
                            <input id="MyPhoneNumber" style="margin-top:20px;" class="ll"><xsl:attribute name="value"><xsl:value-of select="MyPhoneNumber"/></xsl:attribute></input>
                            <input id="MyEmail" style="margin-bottom:30px;" class="ll"><xsl:attribute name="value"><xsl:value-of select="MyEmail"/></xsl:attribute></input>
                        </div>
                        <div id="meta" class="span-12 last">
							<input id="Date" class="rr"><xsl:attribute name="value"><xsl:value-of select="Date"/></xsl:attribute></input>
                            <input id="InvoiceNumber" class="rr"><xsl:attribute name="value"><xsl:value-of select="InvoiceNumber"/></xsl:attribute></input>
                            <input id="ClientName" style="margin-top:20px;" class="client rr"><xsl:attribute name="value"><xsl:value-of select="ClientName"/></xsl:attribute></input>
                            <input id="ClientCompany" style="margin-bottom:30px;" class="client rr"><xsl:attribute name="value"><xsl:value-of select="ClientCompany"/></xsl:attribute></input>
                        </div>
                    </div>
                    <hr/>
                    <textarea id="TopNote" class="notes growfield" cols="95" rows="1" style="resize: none; overflow: hidden; height: 183px;"><xsl:value-of select="TopNote"/></textarea>
                    <table id="Items" class="span-24 last">
                        <thead>
                            <tr>
                                <th class="span-2"><input value="#"/></th>
                                <th class="span-10"><input value="Item Description"/></th>
                                <th class="span-4"><input value="Quantity"/></th>
                                <th class="span-4"><input value="Unit price ($)"/></th>
                                <th class="span-4"><input value="Total ($)"/></th>
                            </tr>
                        </thead>
                        <tbody>
                            <xsl:for-each select="Item">
                                <tr class="Item">
                                    <td class="ItemNumber noteditable"><xsl:value-of select="position()"/></td>
                                    <td><input class="ItemDescription"><xsl:attribute name="value"><xsl:value-of select="Description"/></xsl:attribute></input></td>
                                    <td><input class="ItemQuantity" oninput="updateTotals()"><xsl:attribute name="value"><xsl:value-of select="Quantity"/></xsl:attribute></input></td>
                                    <td><input class="ItemPrice" oninput="updateTotals()"><xsl:attribute name="value"><xsl:value-of select="Price"/></xsl:attribute></input></td>
                                    <td class="ItemTotal noteditable"><xsl:value-of select="Price * Quantity"/></td>
                                </tr>
                            </xsl:for-each>
                        </tbody>
                        <tfoot>
                            <tr id="total">
                                <th id="totallabel" colspan="4" class="span-20"><input value="Total"/></th>
                                <th id="InvoiceTotal" class="span-4 noteditable">
                                    <xsl:call-template name="sumProducts">
                                        <xsl:with-param name="left" select="Item/Price"/>
                                        <xsl:with-param name="right" select="Item/Quantity"/>
                                    </xsl:call-template>
                                </th>
                            </tr>
                        </tfoot>
                    </table>
                    <textarea id="BottomNote" class="notes growfield" cols="95" style="resize: none; overflow: hidden; height: 99px;"><xsl:value-of select="BottomNote"/></textarea>
                </div>
            </body>
        </html>
    </xsl:template>

    <xsl:template name="sumProducts">
        <xsl:param name="left"/>
        <xsl:param name="right"/>
        <xsl:param name="acc" select="0"/>
        <xsl:choose>
          <xsl:when test="$left">
            <xsl:call-template name="sumProducts">
              <xsl:with-param name="acc" select="$acc + $left[1] * $right[1]"/>
              <xsl:with-param name="left" select="$left[position() > 1]"/>
              <xsl:with-param name="right" select="$right[position() > 1]"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$acc"/>
          </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
</xsl:stylesheet>

