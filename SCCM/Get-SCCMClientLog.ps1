Function Get-SccmClientLog ($ComputerName,$LogName) {
	try {
		Write-Debug "Initiating the $($MyInvocation.MyCommand.Name) function...";
        $output_properties = @{'ComputerName'=$ComputerName;'Log'=$LogName}

		if ($LogName -ne 'setup') {
			$sPath = "\\$ComputerName\admin$\ccmlogs";
			$aLogData = @();
			$aDir = Get-ChildItem $sPath | where { !$_.PsIsContainer };
			foreach ($sLog in $aDir) {
				if ($sLog -match $LogName) {
					$aLogData += Get-Content "$sPath\$sLog";
				}##endif
			}##endif
			if ($LogName -eq 'smsts') {
				if (Test-Path "$sPath\SMSTSLog\smsts.log") {
					$aLogData += Get-Content "$sPath\SMSTSLog\smsts.log";
				}##endif
			}##endif
			if ($LogName -eq 'smsts') {
                $log_data = Format-SccmClientLogData $aLogData | Format-SccmClientSmsTsLog;
                $output_properties.Add('LogData',$log_data)
                New-Object –TypeName PSObject –Prop $output_properties
			} else {
				$log_data = Format-SccmClientLogData $aLogData;
                $output_properties.Add('LogData',$log_data)
                New-Object –TypeName PSObject –Prop $output_properties
			}##endif
		} else {
			$sPath = "\\$ComputerName\admin$\ccmsetup\logs";
			$aLogData = Get-Content "$sPath\ccmsetup.log";
			$log_data = Format-SccmClientLogData $aLogData;
            $output_properties.Add('LogData',$log_data)
            New-Object –TypeName PSObject –Prop $output_properties
		}##endif
	} catch [System.Exception] {
		Write-Warning "$($MyInvocation.MyCommand.Name): $($_.Exception.Message)";
		return $false;
	}##endtry
}##endfunction

##Removes all the SMS-specific stuff like [LOG, component, etc
##Get-SccmClientLog passes all potential output to this cmdlet
Filter Format-SccmClientLogData ($aLogData) {
	try {
		Write-Debug "Initiating the $($MyInvocation.MyCommand.Name) function...";
		$aFilteredLog = @();
		foreach ($sLine in $aLogData) {
			$reLine = ([regex]'<time="(.+)" date="(.+)" component').matches($sLine); 
			foreach ($oLine in $reLine) {
				$aSplit = ($oLine.Groups[2].Value).Split('.');
				[datetime]$sDateTime = "$($oLine.Groups[3].Value) $($aSplit[0])";
				$oLog = New-Object System.Object;
				$oLog | Add-Member -type NoteProperty -name DateTime -value $sDateTime;
				$oLog | Add-Member -type NoteProperty -name Message -value  $oLine.Groups[1].Value;
				$oLog = $oLog | Sort-Object 'DateTime'
				#$aFilteredLog += $oLog;
				$oLog;
			}##endforeach
		}##endforeach
		#return $aFilteredLog
	} catch [System.Exception] {
		Write-Debug "$($MyInvocation.MyCommand.Name): $($_.Exception.Message)";
		return $false;
	}##endtry
}##endfilter

##Used in the pipeline to take SMSTS log data and only pick out the interesting lines
Filter Format-SccmClientSmsTsLog ($oTsLogLine) {
		try {
			Write-Debug "Initiating the $($MyInvocation.MyCommand.Name) function...";
			$aInterestingLines = @('Successfully complete the action',
				'The action (',
				'System shutdown request is received',
				'Waiting for installation job to complete',
				'Installing software for PackageID',
				'Successfully connected to',
				'Installation completed with exit code',
				'The condition for the action',
				'The group (',
				'Task Sequence Manager ServiceMain finished execution',
				'Waiting for CcmExec service to be fully operational',
				'Waiting for job status notification');
			$aInterestingData = @();
			foreach ($sLine in $aInterestingLines) {
				if ($oTsLogLine.Message -like "$sLine*") {
					$oLog = New-Object System.Object;
					$oLog | Add-Member -type NoteProperty -name DateTime -value $oTsLogLine.DateTime;
					$oLog | Add-Member -type NoteProperty -name Message -value  $oTsLogLine.Message;
					if ($oTsLogLine.Message -like '*Error*') {
						$oLog | Add-Member -type NoteProperty -name LineResult -value 'Red';
					} else {
						$oLog | Add-Member -type NoteProperty -name LineResult -value 'Green';
					}##endif
					$oLog;
				}##endif
			}##endforeach
		} catch [System.Exception] {
			Write-Debug "$($MyInvocation.MyCommand.Name): $($_.Exception.Message)";
			return $false;
		}##endtry
}##endfilter
