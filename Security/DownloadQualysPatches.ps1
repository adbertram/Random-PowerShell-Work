param($scan_results_file)
$download_path = 'C:\Documents and Settings\abertram\Desktop\CONFIGMANAGER Vulnerabilities'

$mht_contents = gc $scan_results_file
$ie = New-Object -ComObject 'InternetExplorer.Application'
$webclient = New-Object System.Net.WebClient
$ie.Navigate2('file:///C:\Documents and Settings\abertram\Desktop\CONFIGMANAGER Vulnerabilities\Scan_Results_unnhs_tw1_20131121_scan_1385046170_57428.mht')

$links = $ie.Document.getElementsByTagName('a') | ? {($_.innertext -like '*Windows Server 2012*') -and ($_.innertext -notlike '*Core*') -and ($_.href -like 'http://*')} | select -ExpandProperty href
foreach ($link in $links) {
    $r = Invoke-WebRequest -Uri $link -UseBasicParsing
    $r.Links | ? {$_.outerhtml -like '*<span>Download</span>*'} | % {
        $_.href
        $y = Invoke-WebRequest "http://www.microsoft.com$($_.href)" -UseBasicParsing
    }
    $y.Links | ? {$_.outerhtml -like '*Click Here*'} | select -first 1 | % {$webclient.DownloadFile($_.href,"$download_path\$(split-path $_.href -Leaf)")}
}
