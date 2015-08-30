[CmdletBinding(DefaultParameterSetName = 'None')]
[OutputType()]
param
(
	[Parameter(ParameterSetName = 'DomainController')]
	[ValidateNotNullOrEmpty()]
	[string[]]$DomainController,
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[ValidateSet('DnsForwarders', 'DnsDelegation', 'DnsDynamicUpdate', 'DnsRecordRegistration', 'DnsResolveExtName', 'DnsAll')]
	[string[]]$DnsTest,
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$DnsInternetName,	

	[Parameter(ParameterSetName = 'DomainWide')]
	[ValidateNotNullOrEmpty()]
	[string]$DomainName = (Get-ADDomain).DNSRoot,
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
	[string]$DcDiagFilePath = 'C:\Windows\System32\dcdiag.exe'

)
process {
	try
	{
		$TestRegex = '(PASS|WARN|FAIL|n/a)|(PASS|WARN|FAIL|n/a)|(PASS|WARN|FAIL|n/a)|(PASS|WARN|FAIL|n/a)|(PASS|WARN|FAIL|n/a)|(PASS|WARN|FAIL|n/a)'
		$AllTestsPassedRegex = 'passed test DNS'
		if ($PSCmdlet.ParameterSetName -eq 'DomainController')
		{
			$ServerTestResults = & $DcDiagFilePath /s:$Dc /test:DNS
		}
		else
		{
			$ServerTestResults = & $DcDiagFilePath /a /test:DNS
		}
		if (-not $ServerTestResults)
		{
			throw 'Could not parse results'
		}
		Write-Verbose -Message 'Finished dcdiag.exe execution. Parsing result...'
		$ServerResults = [regex]::Matches($ServerTestResults, $TestRegex).Value
		$TestResults = @{
			'Authentication' = ''
			'Basic' = ''
			'Forwarders' = ''
			'Delegations' = ''
			'DynamicUpdates' = ''
			'RecordRegistrations' = ''
		}
		if ($ServerResults -and ($ServerResults.Count -ne 7))
		{
			Write-Verbose -Message "Successfully parsed dcdiag.exe summary results with $($ServerResults -join ',')"
			$SummaryResults += [pscustomobject]@{ 'DomainController' = $Dc; 'Test' = 'Authentication'; 'Result' = $ServerResults[0] }
			$SummaryResults += [pscustomobject]@{ 'DomainController' = $Dc; 'Test' = 'Basic'; 'Result' = $ServerResults[1] }
			$SummaryResults += [pscustomobject]@{ 'DomainController' = $Dc; 'Test' = 'Forwarders'; 'Result' = $ServerResults[2] }
			$SummaryResults += [pscustomobject]@{ 'DomainController' = $Dc; 'Test' = 'Delegations'; 'Result' = $ServerResults[3] }
			$SummaryResults += [pscustomobject]@{ 'DomainController' = $Dc; 'Test' = 'DynamicUpdates'; 'Result' = $ServerResults[4] }
			$SummaryResults += [pscustomobject]@{ 'DomainController' = $Dc; 'Test' = 'RecordRegistrations'; 'Result' = $ServerResults[5] }
		}
		elseif (-not $ServerResults)
		{
			## Either it couldn't parse the test summary values correctly or it passed all the tests and the summary values didn't come up
			$ServerResults = [regex]::Matches($ServerTestResults, $AllTestsPassedRegex).Value
			if (!$ServerResults)
			{
				throw "Could not determine test results for DC '$Dc'"
			}
			else
			{ ## It passed all the tests but just didn't display the summary values
				$SummaryResults += [pscustomobject]@{ 'DomainController' = $Dc; 'Test' = 'Authentication'; 'Result' = 'PASS' }
				$SummaryResults += [pscustomobject]@{ 'DomainController' = $Dc; 'Test' = 'Basic'; 'Result' = 'PASS' }
				$SummaryResults += [pscustomobject]@{ 'DomainController' = $Dc; 'Test' = 'Forwarders'; 'Result' = 'PASS' }
				$SummaryResults += [pscustomobject]@{ 'DomainController' = $Dc; 'Test' = 'Delegations'; 'Result' = 'PASS' }
				$SummaryResults += [pscustomobject]@{ 'DomainController' = $Dc; 'Test' = 'DynamicUpdates'; 'Result' = 'PASS' }
				$SummaryResults += [pscustomobject]@{ 'DomainController' = $Dc; 'Test' = 'RecordRegistrations'; 'Result' = 'PASS' }
			}
		}
		
		$SummaryResults = $SummaryResults | group test, result -NoElement
		$Output.'Authentication' = "{0} / {1} / {2}" -f ($SummaryResults | where { $_.Name -eq 'Authentication, PASS' }).Count, ($SummaryResults | where { $_.Name -eq 'Authentication, WARN' }).Count, ($SummaryResults | where { $_.Name -eq 'Authentication, FAIL' }).Count
		$Output.'Basic' = "{0} / {1} / {2}" -f ($SummaryResults | where { $_.Name -eq 'Basic, PASS' }).Count, ($SummaryResults | where { $_.Name -eq 'Basic, WARN' }).Count, ($SummaryResults | where { $_.Name -eq 'Basic, FAIL' }).Count
		$Output.'Forwarders' = "{0} / {1} / {2}" -f ($SummaryResults | where { $_.Name -eq 'Forwarders, PASS' }).Count, ($SummaryResults | where { $_.Name -eq 'Forwarders, WARN' }).Count, ($SummaryResults | where { $_.Name -eq 'Forwarders, FAIL' }).Count
		$Output.'Delegations' = "{0} / {1} / {2}" -f ($SummaryResults | where { $_.Name -eq 'Delegations, PASS' }).Count, ($SummaryResults | where { $_.Name -eq 'Delegations, WARN' }).Count, ($SummaryResults | where { $_.Name -eq 'Delegations, FAIL' }).Count
		$Output.'Dynamic Updates' = "{0} / {1} / {2}" -f ($SummaryResults | where { $_.Name -eq 'DynamicUpdates, PASS' }).Count, ($SummaryResults | where { $_.Name -eq 'DynamicUpdates, WARN' }).Count, ($SummaryResults | where { $_.Name -eq 'DynamicUpdates, FAIL' }).Count
		$Output.'Record Registrations' = "{0} / {1} / {2}" -f ($SummaryResults | where { $_.Name -eq 'RecordRegistrations, PASS' }).Count, ($SummaryResults | where { $_.Name -eq 'RecordRegistrations, WARN' }).Count, ($SummaryResults | where { $_.Name -eq 'RecordRegistrations, FAIL' }).Count
		
		[pscustomobject]$Output
	}
	catch
	{
		Write-Error $_.Exception.Message
	}
}