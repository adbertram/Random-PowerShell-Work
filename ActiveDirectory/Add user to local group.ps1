$de = [ADSI]"WinNT://a-xp-2/administrators,group"
$de.psbase.Invoke("Add",([ADSI]"WinNT://apollo/support").path)