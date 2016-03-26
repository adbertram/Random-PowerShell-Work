$aPcs = Get-Content dddd.txt | where 
foreach ($oPc in $aPcs) {
	$sUser = $oPc.ToLower();
	if ($sUser -eq 'isspare23') {
		$sLName = 'spare23'
		$sLName = "spare23"
		$sDisplayName = "spare23 spare23";
		$sDesc = 'med cart laptop autologin';
	} else {
		$sLName = $sUser.substring($sUser.length - 4, 4);
		$sLName = "Cart $sLName"
		$sDisplayName = "Medication Cart $sLName";
		$sDesc = $sDisplayName;
	}
	New-AdUser $sUser -Path "<OUDNHere>" -accountpassword (ConvertTo-SecureString -AsPlainText "password" -Force) -Enabled $true -GivenName 'Medication' -Surname $sLName -DisplayName $sDisplayName -PasswordNeverExpires $true -CannotChangePassword $true -Description $sDesc;
}