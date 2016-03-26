param ([string]$Computername,[string]$GroupName,[string]$Username)
$group = [ADSI]"WinNT://$Computername/$GroupName,group"
$group.Add("WinNT://$Computername/$Username,user")