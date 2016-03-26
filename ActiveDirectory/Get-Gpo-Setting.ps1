$sDefaultGpoGuid = '{F6FE3FDE-4CD0-455D-B9BC-D134111BBF09}';

$sDefaultGpoGuid = "*$($sDefaultGpoGuid)*";
$ErrorActionPreference = "Stop";
#$aComputerGPOs = Get-ADObject -Filter {(ObjectClass -eq "groupPolicyContainer") -and (Name -eq '{F6FE3FDE-4CD0-455D-B9BC-D134111BBF09}')}
$aComputerGPOs = Get-ADObject -Filter {(ObjectClass -eq "groupPolicyContainer")}
#$aUserGPOs = Get-ADObject -Filter {(ObjectClass -eq "groupPolicyContainer") -and (gPCUserExtensionNames -like $sDefaultGpoGuid)}


$test = @();

if ($aComputerGpos -ne $null) { 
	$aReport = @() 
	foreach ($oGpo in $aComputerGpos) { 
		[XML]$xGpoReport = Get-GPOReport -Guid $oGpo.Name -ReportType XML;
		try {
			if (($xGpoReport.GPO.Computer.Enabled -eq 'true') -and (Test-Member $xGpoReport.GPO.Computer 'ExtensionData')) {
				$aSettings = @();
				foreach ($oExt in $xGpoReport.GPO.Computer.ExtensionData) { 
					$aSettings += $oExt.Extension.ChildNodes 
				}##endforeach
				if ($aSettings.Count -ne 0) {
					echo '11111111'
					echo "======NAME:$($xGpoReport.GPO.Name)========="
					$aSettings
					echo '22222222'
					foreach ($oSetting in $aSettings) {
						if ($oSetting.Name -match '^q\d+:RegistrySetting') {
							$xGpoReport.GPO.Name
							#$oSetting.ChildNodes
							#$sSetting = ($oSetting.ChildNodes).Item(0).InnerText
							#$sSetting
							#echo '22222222222222'
							#$sSetting = 'N/A - Actual setting is deeper in XML tree';
							#$($oSetting.ChildNodes | Select-Object -ExpandProperty '#text')[0];
							#echo '-----------start---------'
							#$oSetting.Name
							#$oSetting.ChildNodes
							#echo '-----------end---------'
						} elseif ($oSetting.Name -notmatch '^q\d+') {
							#$sSetting = $oSetting.Name;
						}##endif
						
#						$aReportItem = New-Object -TypeName PSObject -Property @{ 
#							Name = $xGpoReport.GPO.Name 
#							GUID = $oGpo.Name 
#							SettingName = $sSetting
#						}##endnewobject
#						$aReportItem
#						$aReport += $aReportItem 
					}##endforeach 
				}##endif
			}##endif
		} catch {  
			Write-Error $_.Exception
		}##endtrycatch
	}##endforeach
}##endif

$test | Select -Unique