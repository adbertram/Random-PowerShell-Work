## Based off of a CSV, sets printer comments for a set of printers

$Csv = Import-Csv "C:\Dropbox\Powershell\scripts\PrinterModelAndIPs.csv"
$server_printers = Get-WMIObject -Class "Win32_Printer" -NameSpace "root\cimv2" -computername ctxps
foreach ($row in $Csv) {
    $model = $row.Model; 
    $ip = $row.IP;
    $printer = $server_printers | ? {$_.comment -eq $ip }
    if ($printer) {
           #$printer | foreach {"Name: $($_.Name) | $($_.PortName) | $ip | $model"}
           $printer | foreach { $_.Comment = "$ip $model"; $_.Put() | Out-Null}
           
        
    }
}