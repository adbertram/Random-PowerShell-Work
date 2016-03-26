$aDisabledAdComputers = Get-ADComputer -Filter * | Where-Object { $_.Enabled -eq $false };
foreach ($oAccount in $aDisabledAdComputers) {
	Remove-ADObject -Identity $oAccount -Confirm:$false -Recursive;
}##endforeach