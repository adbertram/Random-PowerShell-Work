$remove_ous = $false

$ous_to_keep = @('UAP - PEAP TLS','UAP - PEAP TLS Only','Disabled Users');

$ad_objects = Get-ADObject -Filter "ObjectClass -eq 'user' -or ObjectClass -eq 'computer' -or ObjectClass -eq 'group' -or ObjectClass -eq 'organizationalUnit'";

$aOuDns = @();
foreach ($o in $ad_objects) {
	$sDn = $o.DistinguishedName;
	if ($sDn -like '*OU=*' -and $sDn -notlike '*LostAndFound*') {
		$sOuDn = $sDn.Substring($sDn.IndexOf('OU='));
		$aOuDns += $sOuDn;
	}##endif
}##endforeach

$a0CountOus = $aOuDns | Group-Object | Where-Object { $_.Count -eq 1 } | % { $_.Name };
$empty_ous = 0;
$ous_removed = 0;
foreach ($sOu in $a0CountOus) {
	if (!(Get-ADObject -Filter "ObjectClass -eq 'organizationalUnit'" | where { $_.DistinguishedName -like "*$sOu*" -and $_.DistinguishedName -ne $sOu })) {
		$ou = Get-AdObject -Filter { DistinguishedName -eq $sOu };
		if ($ous_to_keep -notcontains $ou.Name) {
			if ($remove_ous) {
				Set-ADOrganizationalUnit -Identity $ou.DistinguishedName -ProtectedFromAccidentalDeletion $false -confirm:$false;
				Remove-AdOrganizationalUnit -Identity $ou.DistinguishedName -confirm:$false
				$ous_removed++
			}##endif
			$ou
			$empty_ous++;
		}##endif
	}##endif
}##endforeach
echo '-------------------'
echo "Total Empty OUs Removed: $ous_removed"
echo "Total Empty OUs: $empty_ous"