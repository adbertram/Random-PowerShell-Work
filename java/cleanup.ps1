$RegUninstallPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall')
$VersionsToKeep = @('Java 7 Update 5')

Get-WmiObject Win32_Process | Where {$_.ExecutablePath -like '*Program FilesJava*'} | 
    Select @{n='Name';e={$_.Name.Split('.')[0]}} | Stop-Process -Force

get-process -Name *iexplore* | Stop-Process -Force -ErrorAction SilentlyContinue

$UninstallSearchFilter = { ($_.GetValue('DisplayName') -like '*Java*') -and 
    (($_.GetValue('Publisher') -eq 'Oracle') -or
    ($_.GetValue('Publisher') -eq 'Sun Microsystems, Inc.')) -and
    ($VersionsToKeep -notcontains $_.GetValue('DisplayName'))} 

foreach ($Path in $RegUninstallPaths) {
    if (Test-Path $Path) {
        Get-ChildItem $Path | Where $UninstallSearchFilter | 
        Foreach { Start-Process 'C:\Windows\System32\msiexec.exe' "/x $($_.PSChildName) /qn" -Wait}
    }
}

New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
$ClassesRootPath = “HKCR:\InstallerProducts”
Get-ChildItem $ClassesRootPath | 
    Where { ($_.GetValue('ProductName') -like '*Java*7*') -or ($_.GetValue('ProductName') -like “Java*6*”)} |
    Foreach {Remove-Item $_.PsPath -Force -Recurse}


$JavaSoftPath = 'HKLM:\SOFTWARE\JavaSoft'
if (Test-Path $JavaSoftPath) {
    Remove-Item $JavaSoftPath -Force -Recurse
}

Remove-Item $env:ProgramfilesJava -Force -Recurse
