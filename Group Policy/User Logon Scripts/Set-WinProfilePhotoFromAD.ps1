<#
    AD Photo to Windows Profile Photo Logon Script
               Dylan Bickerstaff - 2021
    ----------------------------------------------
    This script retrieves the "thumbnailPhoto"
    LDAP attribute from Active Directory and sets
    the Windows 10 user profile picture to it.
    ----------------------------------------------
    To use this script, create a GPO policy that
    runs this script at logon under the logged
    on user's context. Then create a computer
    security policy that allows "Everyone" full
    control on the following registry key:
    HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users
#>

$storePath = "C:\ProgramData\ADAccountPhotos\"

$pVals =
"Image1080",
"Image192",
"Image208",
"Image240",
"Image32",
"Image40",
"Image424",
"Image448",
"Image48",
"Image64",
"Image96"

$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$search = [System.DirectoryServices.DirectorySearcher]::new("objectSid=$sid")
$result = $search.FindOne()
$_ = New-Item -Path "$($storePath)$($sid)\" -ItemType Directory -Force
[System.IO.File]::WriteAllBytes("$($storePath)$($sid)\photo.jpg", $($result.Properties.thumbnailphoto))

$key = New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\$sid" -Force
foreach($val in $pVals) {
    $_ = New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\$sid" -Name $val -Value "$($storePath)$($sid)\photo.jpg" -Force
}