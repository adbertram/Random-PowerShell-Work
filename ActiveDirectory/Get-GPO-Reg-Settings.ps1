function findRegValues($sName,$sId,$sKeyPath,$aKeyPathHistory = $null) {
	$aPath = Get-GPRegistryValue -GUID $sId -Key $sKeyPath
	$aKeyPathHistory = @()
	$aUniqueSettings = @()
	$aUniqueDups = @()
	
	foreach ($oKeyPath in $aPath) {
		if ($oKeyPath) {
			if ('Value' -in $oKeyPath.PSObject.Properties.Name) {
				if ($aKeyPathHistory -notcontains $oKeyPath.FullKeyPath) {
					$o = @{
						'GUID' = $sId
						'Name' = $sName
						'Key' = $sKeyPath
						'Value' = $oKeyPath.Value
					}
					if ($aUniqueSettings -notcontains "$sKeyPath|$($oKeyPath.Value)") {
						$aUniqueSettings += "$sKeyPath|$($oKeyPath.Value)";
					} elseif ($aUniqueDups -notcontains "$sKeyPath|$($oKeyPath.Value)") {
						$o.Value = "$sName|$sKeyPath|$($oKeyPath.Value)";
						$aUniqueDups += "$sKeyPath|$($oKeyPath.Value)";
					}
					[pscustomobject]$o
				}
			} elseif ('FullKeyPath' -in $oKeyPath.PSObject.Properties.Name) {
				$aKeyPathHistory += $oKeyPath.FullKeyPath;
				findRegValues $sName $sId $oKeyPath.FullKeyPath $aKeyPathHistory
			}
		}
	}
}

$aRegRoots = @('HKCU\Software','HKLM\System','HKLM\Software')

foreach ($oGpo in (Get-Gpo -All)) {
	foreach ($sRegRoot in $aRegRoots) {
		findRegValues $oGpo.DisplayName $oGpo.Id $sRegRoot
	}
}
