param($Computername,$Group)
$group = [ADSI]"WinNT://$Computername/$Group"
@($group.Invoke("Members")) |

foreach { $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null) }