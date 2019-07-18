Write-Progress -Activity "Remove Apps" -Status "Looking for apps to remove..." -PercentComplete 0

$PackagesToRemove = 
"Microsoft.3DBuilder",
"Microsoft.Microsoft3DViewer",
"Microsoft.BingFinance",
"Microsoft.BingNews",
"Microsoft.BingSports",
"Microsoft.BingTranslator",
"Microsoft.CommsPhone",
"Microsoft.Getstarted",
"Microsoft.Messaging",
"Microsoft.MicrosoftOfficeHub",
"Microsoft.MicrosoftSolitaireCollection",
"Microsoft.Office.OneNote",
"Microsoft.Office.Sway",
"Microsoft.SkypeApp",
"Microsoft.People",
"Microsoft.WindowsAlarms",
"Microsoft.WindowsCamera",
"Microsoft.WindowsCommunicationsApps",
"Microsoft.WindowsMaps",
"Microsoft.WindowsPhone",
"Microsoft.WindowsSoundRecorder",
"Microsoft.XboxApp",
"Microsoft.ZuneMusic",
"Microsoft.ZuneVideo",
"Microsoft.OneConnect",
"Microsoft.WindowsFeedbackHub"

$ProvisionPackagesToRemove = @()
$AllUserPackagesToRemove = @()

foreach($ProvisionedPackage in Get-AppxProvisionedPackage -Online) {
    foreach($PackageToRemove in $PackagesToRemove) {
        if($ProvisionedPackage.PackageName.Contains($PackageToRemove)) {
            $ProvisionPackagesToRemove += $ProvisionedPackage
        }
    }
}

foreach($AllUserPackage in Get-AppxPackage -AllUsers) {
    foreach($PackageToRemove in $PackagesToRemove) {
        if($AllUserPackage.PackageFullName.Contains($PackageToRemove)) {
             $AllUserPackagesToRemove += $AllUserPackage
        }
    }
}

$Total = $ProvisionPackagesToRemove.Count + $AllUserPackagesToRemove.Count
$Progress = 0

foreach($ProvisionedPackage in $ProvisionPackagesToRemove) {
    Write-Progress -Activity "Remove Apps" -Status ("Removing Provisioned App: " + $ProvisionedPackage.PackageName + "...") -PercentComplete (($Progress++ / $Total) * 100)
    $ProvisionedPackage | Remove-AppxProvisionedPackage -Online
}

foreach($AllUserPackage in $AllUserPackagesToRemove) {
    Write-Progress -Activity "Remove Apps" -Status ("Removing AllUsers App: " + $AllUserPackage.Name + "...") -PercentComplete (($Progress++ / $Total) * 100)
    $AllUserPackage | Remove-AppxPackage -AllUsers
}