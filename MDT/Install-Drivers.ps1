Write-Host -NoNewLine "Enter the path to the MDT Deployment Share (E.g `"\\util01\mdt$`" or `"Z:\`"): "
$share = Read-Host
Write-Progress -Activity "Driver Scan..." -PercentComplete 0 -Status "Gathering list of devices on this PC..."
$devices = (Get-PnpDevice).HardwareID;
$devices_list = New-Object -TypeName "System.Collections.Generic.List[string]"
foreach($device in $devices) {
    $devices_list.Add($device);
}
Write-Progress -Activity "Driver Scan..." -PercentComplete 0 -Status "Gathering list of drivers in the store..."
$drivers = Select-Xml -Path (Join-Path -Path $share -ChildPath "\Control\Drivers.xml") -XPath "/drivers/driver"
$count = 0
$drivers_found = New-Object -TypeName "System.Collections.Generic.Dictionary[string, object]"
foreach($driver in $drivers) {
    Write-Progress -Activity "Driver Scan..." -PercentComplete (($count / $drivers.Count) * 100) -Status "Scanning driver: $($driver.Node.Name)"
    foreach($hwid in $driver.Node.PNPId) {
        if($devices_list.Contains($hwid)) {
            if($drivers_found.ContainsKey($hwid)) {
                $added_driver = [System.Version]::new($drivers_found[$hwid].Version)
                $tobe_driver = [System.Version]::new($driver.Node.Version)
                if($added_driver.CompareTo($tobe_driver) -lt 0) {
                    $drivers_found[$hwid] = $driver.Node
                }
            } else {
                $drivers_found.Add($hwid, $driver.Node);
            }
        }
    }
    $count++
}
$count = 0
foreach($driver in $drivers_found.Values) {
    Write-Progress -Activity "Driver Install..." -PercentComplete (($count / $drivers_found.Count) * 100) -Status "Installing driver: $($driver.Name)..."
    Start-Process -FilePath "pnputil.exe" -ArgumentList "/add-driver `"$(Join-Path -Path $share -ChildPath $driver.Source)`" /install" -WindowStyle Hidden -Wait
    $count++
}