#$ErrorActionPreference = "SilentlyContinue"
$error.PSBase.Clear()

$aRegRoots = @('HKCU\Software','HKLM\System','HKLM\Software');
$aGpos = Get-Gpo -All;
$aUniqueSettings = @();
$aUniqueDups = @();

function findRegValues($sName,$sId,$sKeyPath,$aKeyPathHistory = $null) {
	$aPath = Get-GPRegistryValue -GUID $sId -Key $sKeyPath -ErrorAction 'silentlycontinue'
	$aKeyPathHistory = @();
	foreach ($oKeyPath in $aPath) {
		if ($oKeyPath) {
			if (Test-Member $oKeyPath Value) {
				if ($aKeyPathHistory -notcontains $oKeyPath.FullKeyPath) {
					$o = New-Object System.Object;
					$o | Add-Member -type NoteProperty -Name 'GUID' -Value $sId;
					$o | Add-Member -type NoteProperty -Name 'Name' -Value $sName;
					$o | Add-Member -type NoteProperty -Name 'Key' -Value $sKeyPath;
					$o | Add-Member -type NoteProperty -Name 'Value' -Value $oKeyPath.Value;
					if ($aUniqueSettings -notcontains "$sKeyPath|$($oKeyPath.Value)") {
						$aUniqueSettings += "$sKeyPath|$($oKeyPath.Value)";
					} elseif ($aUniqueDups -notcontains "$sKeyPath|$($oKeyPath.Value)") {
						"$sName|$sKeyPath|$($oKeyPath.Value)";
						$aUniqueDups += "$sKeyPath|$($oKeyPath.Value)";
					}
				}
			} elseif (Test-Member $oKeyPath FullKeyPath) {
				$aKeyPathHistory += $oKeyPath.FullKeyPath;
				findRegValues $sName $sId $oKeyPath.FullKeyPath $aKeyPathHistory
			}
		}
	}
}

$aRegValues = @();

foreach ($oGpo in $aGpos) {
	$sGuid = $oGpo.Id;
	$sName = $oGpo.DisplayName;
	foreach ($sRegRoot in $aRegRoots) {
		findRegValues $sName $sGuid $sRegRoot
	}
}