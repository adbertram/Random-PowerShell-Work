echo "Starting UAP --> POB replication test..."
echo "-----------"
#Set-AdUser abertram -Server UAPDC01 -Description "Keller Schroeder Vendor - Set on UAPDC01"
Set-ADAccountPassword abertramtest -NewPassword (ConvertTo-SecureString 'p@$$w0rd14' -AsPlainText -Force) -Reset -Server UAPDC01
$passwordlastset = (Get-Aduser abertramtest -Properties passwordlastset -Server UAPDC01).passwordlastset
Write-Host "Waiting for replication from UAPDC01 to DC01..." -ForegroundColor Yellow
$i = 0
do { 
    $i++
    sleep 1
#} while ((Get-AdUser abertram -Properties description -Server DC01).description -ne "Keller Schroeder Vendor - Set on UAPDC01")
} while ((Get-Aduser abertramtest -Properties passwordlastset -Server DC01).passwordlastset -ne $passwordlastset)

Write-Host "Replication from DC01 from UAPDC01 successful.  Replication time: $i seconds ($($i / 60) minutes)" -ForegroundColor Green


echo "Starting POB --> UAP replication test..."
echo "-----------"
#Set-AdUser abertram -Server DC01 -Description "Keller Schroeder Vendor - Set on DC01"
Write-Host "Waiting for replication from DC01 to UAPDC01..." -ForegroundColor Yellow
Set-ADAccountPassword abertramtest -NewPassword (ConvertTo-SecureString 'p@$$w0rd15' -AsPlainText -Force) -Reset -Server DC01
$passwordlastset = (Get-Aduser abertramtest -Properties passwordlastset -Server DC01).passwordlastset
$i = 0
do { 
    $i++
    sleep 1
#} while ((Get-AdUser abertram -Properties description -Server UAPDC01).description -ne "Keller Schroeder Vendor - Set on DC01")
} while ((Get-Aduser abertramtest -Properties passwordlastset -Server UAPDC01).passwordlastset -ne $passwordlastset)

Write-Host "Replication from UAPDC01 from DC01 successful. Replication time: $i seconds ($($i / 60) minutes)" -ForegroundColor Green


Set-AdUser abertram -Server DC01 -Description "Keller Schroeder Vendor"

echo '-----------'
echo 'Checking last replication status between UHHG and UHC sites...'
echo "-----------"
Get-ADReplicationLink -SiteName uhhg | ? { $_.sourceserver -eq 'DC1' } | select sourceserver,destinationserver,LastSuccessfulsync,lastsyncmessage
Get-ADReplicationLink -SiteName UAPMain | ? { $_.sourceserver -eq 'DC02' } | select sourceserver,destinationserver,LastSuccessfulsync,lastsyncmessage
