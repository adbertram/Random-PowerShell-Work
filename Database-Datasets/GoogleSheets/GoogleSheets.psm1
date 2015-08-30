function Get-GoogleSpreadsheet {
    [CmdletBinding()]
    [OutputType('Google.GData.Spreadsheets.SpreadsheetEntry')]
    param (
        [string]$Username = 'adbertram@gmail.com',
        [string]$Password = 'Ilikegmail.'
    )
    begin {
        Add-Type -Path "${env:ProgramFiles(x86)}\Google\Google Data API SDK\Redist\Google.GData.Client.dll"
        Add-Type -Path "${env:ProgramFiles(x86)}\Google\Google Data API SDK\Redist\Google.GData.Extensions.dll"
        Add-Type -Path "${env:ProgramFiles(x86)}\Google\Google Data API SDK\Redist\Google.GData.Spreadsheets.dll"
        
        $service = New-Object Google.GData.Spreadsheets.SpreadsheetsService('TestGoogleDocs')
        $service.setUserCredentials($userName, $password)
        $query = New-Object Google.GData.Spreadsheets.SpreadsheetQuery
    }
    process {
        try {   
            $feed = $service.Query($query)
            foreach ($Entry in $feed.Entries) {
                $Entry | Add-Member -MemberType NoteProperty -Name 'SpreadsheetService' -Value $service
                $Entry
            }
        } catch {
            Write-Error "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
        }
    }
}

function Get-GoogleWorksheet {
    [CmdletBinding()]
    [OutputType('Google.GData.Spreadsheets.WorksheetEntry')]
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [Google.GData.Spreadsheets.SpreadsheetEntry]$Spreadsheet
        
    )
    process {
        try {
            $Service = $Spreadsheet.Service
            $WorksheetFeed = $Spreadsheet.Links | Where-Object {$_.Rel -eq 'http://schemas.google.com/spreadsheets/2006#worksheetsfeed'}
            foreach ($WsFeed in $WorksheetFeed) {
                $query = New-Object Google.GData.Spreadsheets.WorksheetQuery($WsFeed.Href)
                $feed = $Service.Query($query)
                foreach ($Entry in $feed.Entries) {
                    $Entry | Add-Member -MemberType NoteProperty -Name 'SpreadsheetService' -Value $service
                    $Entry
                }
            }
        } catch {
            Write-Error "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
        }
    }
}

function Get-GoogleData {
    [CmdletBinding()]
    [OutputType('System.Management.Automation.PSCustomObject')]
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [Google.GData.Spreadsheets.WorksheetEntry]$WorkSheet
    )
    process {
        try {
        
        
        
        PS C:\users\adam\dropbox\powershell\scripts\GoogleSheets> $feed.Entries | % { $ColLetter = $_.Title.Text -replace '\d+',''; $ColName = ($Columns.Where({$_.Column -eq $ColLetter})).Value;
for ($i=0;$i -lt $Columns.Count;$i++) { $Row = @{}; $Row.Row = $_.Title.Text -replace '[A-Z]+',''; $Row[$ColName] = $_.Value; $Row}}
        
            $Service = $Worksheet.Service
            foreach ($Entry in $WorkSheet) {
                $query = New-Object Google.GData.Spreadsheets.CellQuery($Entry.CellFeedLink)
                $feed = $Service.Query($query)
                foreach ($Cell in $feed.Entries) {
                    if ($Cell.Title.Text -match '^[A-Z]1$') {
                        $ColumnHeader = $Cell.Value
                    }
                    [pscustomobject]@{$ColumnHeader = $Cell.Value}
                }
            }
        } catch {
            Write-Error "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
        }
    }
}