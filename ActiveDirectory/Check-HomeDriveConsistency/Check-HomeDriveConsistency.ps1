# Title: Check-HomeDriveConsistency
# Version: 1.0
# Author: Dylan Bickerstaff
# Description: This script checks users' Home Drive settings in a particular OU (Adding or Removing Home Drive access).
# Date: May 2020

# .NET References
$InheritaceFlags = [System.Security.AccessControl.InheritanceFlags]
$FileSystemRights = [System.Security.AccessControl.FileSystemRights]
$AccessControlType = [System.Security.AccessControl.AccessControlType]
$SecurityIdentifier = [System.Security.Principal.SecurityIdentifier]
$FileSystemAccessRule = [System.Security.AccessControl.FileSystemAccessRule]
$PropagationFlags = [System.Security.AccessControl.PropagationFlags]

$InformationPreference = [System.Management.Automation.ActionPreference]::Continue

$Global:ErrorOccured = $false

Write-Information "Reading config.xml..."
$config = Select-Xml -Path ".\config.xml" -XPath "/HDriveCheck"
$homeDriveLetter = $config.Node.HDriveLetter

Write-Information "Gathering list of users in configured HDrive AD group..."
$groupMembers = Get-ADGroupMember -Identity $config.Node.SecurityGroupDN | Select-Object -Property "distinguishedName"

Write-Information ""

#Checks if a user is a member of the configured Home Drive group.
function InHomeDriveGroup($User) {
    foreach($membersDN in $groupMembers) {
        if($membersDN.distinguishedName -eq $User.DistinguishedName) { return $true }
    }
    return $false
}

#Sets the AD attributes for a Home Drive on a user.
function SetADHomeDriveAttributes($User) {
    $homeDirectory = Join-Path -Path $config.Node.HDrivePath -ChildPath $User.SamAccountName
    $User.HomeDrive = $config.Node.HDriveLetter
    $User.HomeDirectory = $homeDirectory
    Set-ADUser -Instance $User
}

#Removes the Home Drive AD attributes on a user.
function RemoveADHomeDriveAttributes($User) {
    $User.HomeDrive = $null
    $User.HomeDirectory = $null
    Set-ADUser -Instance $User
}

#Verifies user has full access to its own configured Home Drive folder.
function IsHDriveACLSetupRight($User) {
    $acls = Get-Acl -Path $User.HomeDirectory
    foreach($acl in $acls.GetAccessRules($true, $false, $SecurityIdentifier)) {
        if(-not ($acl.IdentityReference -eq $User.SID)) { continue }
        if(-not ($acl.AccessControlType -eq $AccessControlType::Allow)) { continue }
        if(-not (($acl.FileSystemRights -band $FileSystemRights::FullControl) -eq $FileSystemRights::FullControl)) { continue }
        if($acl.InheritanceFlags -eq ($InheritaceFlags::ContainerInherit -bor $InheritaceFlags::ObjectInherit)) { return $true }
    }
    return $false
}

#Sets full access permission on a users' configured Home Drive.
function RepairHomeDriveACLs($User) {
    $acls = Get-Acl -Path $User.HomeDirectory
    $rule = $FileSystemAccessRule::new(
        $User.SID,
        $FileSystemRights::FullControl,
        ($InheritaceFlags::ContainerInherit -bor $InheritaceFlags::ObjectInherit),
        $PropagationFlags::None,
        $AccessControlType::Allow
    )
    $acls.SetAccessRule($rule)
    Set-Acl -Path $User.HomeDirectory -AclObject $acls
}

#Ensures a user is set up correctly for a Home Drive.
function AddHomeDriveConfig($User) {
    try {
        Write-Information "Checking if user is in Home Drive AD Group..."
        if(-not (InHomeDriveGroup($User))) {
            Write-Warning "User is missing from group, adding now..."
            Add-ADGroupMember -Identity $config.Node.SecurityGroupDN -Members $User
        }
        Write-Information "Checking if the homeDirectory AD attribute is set..."
        if($User.HomeDirectory -eq $null) {
            Write-Warning "homeDirectory not set, setting now..."
            SetADHomeDriveAttributes($User)
        }
        Write-Information "Checking if the homeDrive AD attribute is set to: `"$($homeDriveLetter)`"..."
        if(-not ($User.HomeDrive -eq $homeDriveLetter)) {
            Write-Warning "homeDrive not set correctly, setting now..."
            SetADHomeDriveAttributes($User)
        }
        Write-Information "Checking if the homeDirectory AD attribute is a real existing path: `"$($User.HomeDirectory)`"..."
        if(-not (Test-Path $User.HomeDirectory)) {
            Write-Warning "Not an existing path, creating folder now..."
            New-Item -ItemType Directory -Path $User.HomeDirectory -Force
        }
        Write-Information "Checking if Home Directory path's permissions are setup correctly..."
        if(-not (IsHDriveACLSetupRight($User))) {
            Write-Warning "Permissions wrong, fixing now..."
            RepairHomeDriveACLs($User)
        }
        return $true
    } catch {
        Write-Information ""
        Write-Error $_
        Write-Information ""
        return $false
    }
}

#Ensures a user does not have a configured Home Drive. (Won't delete Home Drive path)
function RemoveHomeDriveConfig($User) {
    try {
        Write-Information "Checking if user is in Home Drive AD Group..."
        if(InHomeDriveGroup($User)) {
            Write-Warning "User is in this group, removing now..."
            Remove-ADGroupMember -Identity $config.Node.SecurityGroupDN -Members $User -Confirm:$false
        }
        Write-Information "Checking if the homeDirectory AD attribute is set..."
        if(-not ($User.HomeDirectory -eq $null)) {
            Write-Warning "homeDirectory is set, removing setting now..."
            RemoveADHomeDriveAttributes($User)
        }
        Write-Information "Checking if the homeDrive AD attribute is set..."
        if(-not ($User.HomeDrive -eq $null)) {
            Write-Warning "homeDrive is set, removing setting now..."
            RemoveADHomeDriveAttributes($User)
        }
        return $true
    } catch {
        Write-Information ""
        Write-Error $_
        Write-Information ""
        return $false
    }
}

#OU Add Loop
function ActionAdd($DN) {
    foreach($user in Get-ADUser -Filter * -SearchBase $DN -Properties "homeDirectory", "homeDrive", "sAMAccountName") {
        Write-Information ""
        Write-Information "Action: ADD - $($user.SamAccountName)"
        Write-Information "------------------"
        if(AddHomeDriveConfig($user)) {
            Write-Information "Home Drive is healthy."
        } else {
            $Global:ErrorOccured = $true
            Write-Warning "Home Drive needs attention! Something went wrong when checking / repairing this Home Drive."
        }
    }
}

#OU Remove Loop
function ActionRemove($DN) {
    foreach($user in Get-ADUser -Filter * -SearchBase $DN -Properties "homeDirectory", "homeDrive", "sAMAccountName") {
        Write-Information ""
        Write-Information "Action: REMOVE - $($user.SamAccountName)"
        Write-Information "------------------"
        if(RemoveHomeDriveConfig($user)) {
            Write-Information "Home Drive is disabled."
        } else {
            $Global:ErrorOccured = $true
            Write-Warning "There was an error removing Home Drive access from this user."
        }
    }
}

#Configuration Loop / Script Entry Point
foreach($OU in $config.Node.OUs.OU) {
    if($OU.Action -eq "ADD") {
        ActionAdd($OU.DN)
    }
    if($OU.Action -eq "REMOVE") {
        ActionRemove($OU.DN)
    }
}

#Check if an error occured above.
if($ErrorOccured) {
    Write-Information ""
    Throw "A fatal error occured at some point. Check the log above for more information."
}