<#
.SYNOPSIS
	This script disjoins a computer from an Active Directory domain, performs a reboot and upon coming back up
	joins it to the domain again and performs another reboot.
.NOTES
	Requirements:	You must have local admin rights on the remote computer to connect to the remote computer
.PARAMETER Computername
	The name of the computer to rejoin to a domain
.PARAMETER DomainName
	The NetBIOS or FQDN of the domain to rejoin the computer to
.PARAMETER UnjoinLocalCredentialXmlFilePath
	If you'd rather not input a username and password every time for the local username and password to the remote
	computer, you can specify the XML path of the XML file you created that stores the credential set.  This will use
	a credential object to use as credentials to disjoin from the domain
.PARAMETER JoinDomainCredentialXmlFilePath
	If you'd rather not input a username and password every time for the domain username and password to the remote
	computer, you can specify the XML path of the XML file you created that stores the credential set.  This will use
	a credential object to use as credentials to join the computer back from the domain.
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory,
			   ValueFromPipeline,
			   ValueFromPipelineByPropertyName)]
	[string[]]$Computername,
	[Parameter(Mandatory)]
	[string]$DomainName,
	[Parameter(Mandatory)]
	[string]$UnjoinLocalCredentialXmlFilePath,
	[Parameter(Mandatory)]
	[string]$DomainCredentialXmlFilePath
)
begin {
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	function New-Credential {
		<#
		.SYNOPSIS
			This function creates a PSCrendential object from an XML file.
		.PARAMETER XmlFilePath
			The file path to the XML file containing the PS credentials
		#>
		[CmdletBinding()]
		[OutputType([System.Management.Automation.PSCredential])]
		param (
			[Parameter(Mandatory)]
			[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
			[string]$XmlFilePath
		)
		process {
			$Cred = Import-Clixml $XmlFilePath
			New-Object System.Management.Automation.PSCredential($Cred.username, $Cred.password)
		}
	}
	Function Test-Ping ($ComputerName) {
		$Result = ping $Computername -n 2
		if ($Result | where { $_ -match 'Reply from ' }) {
			$true
		} else {
			$false
		}
	}
	function Test-DomainTrust ($Computername) {
		$Result = netdom verify $Computername /Domain:$DomainName
		if ($Result -match 'command completed successfully') {
			$true
		} else {
			$false	
		}
	}
	function Wait-Reboot ($Computername,$Credential) {
		while (Test-Ping -ComputerName $Computername) {
			Write-Verbose "Waiting for $Computername to go offline..."
			Start-Sleep -Seconds 1
		}
		Write-Verbose "The computer $Computername has went down for a reboot. Waiting for it to come back up..."
		while (!(Test-Ping -ComputerName $Computername)) {
			Start-Sleep -Seconds 5
			Write-Verbose "Waiting for $Computername to come back online"
		}
		Write-Verbose "The computer $Computername has come online. Waiting for OS to initialize"
		$EapBefore = $ErrorActionPreference
		$ErrorActionPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
		while (!(Get-WmiObject -ComputerName $Computername -Class Win32_OperatingSystem -Credential $Credential)) {
			Start-Sleep -Seconds 5
			Write-Verbose "Waiting for OS to initialize..."
		}
		$ErrorActionPreference = $EapBefore
	}
}
process {
	foreach ($Computer in $Computername) {
		try {
			if (Test-Ping -ComputerName $Computer) { ## if the remote computer can be pinged
				Write-Verbose "The computer '$Computer' is online"
				## Import the XML files to create the PSCredential objects
				$LocalCredential = (New-Credential -XmlFilePath $UnjoinLocalCredentialXmlFilePath)
				$DomainCredential = (New-Credential -XmlFilePath $DomainCredentialXmlFilePath)
				Write-Verbose "Removing computer from domain and forcing restart"
				Remove-Computer -ComputerName $Computer -LocalCredential $LocalCredential -UnjoinDomainCredential $DomainCredential -Workgroup TempWorkgroup -Restart -Force
				Write-Verbose "The computer has been removed from domain. Waiting for a reboot."
				Wait-Reboot -Computername $Computer -Credential $LocalCredential
				Write-Verbose "The computer $Computer has been rebooted. Attempting to rejoin to domain."
				Add-Computer -ComputerName $Computer -DomainName $DomainName -Credential $DomainCredential -LocalCredential $LocalCredential -Restart -Force
				Write-Verbose "The computer $Computer has been rejoined to domain. Waiting for the final reboot"
				Wait-Reboot -Computername $Computer -Credential $DomainCredential 
				Write-Verbose "The computer $Computer has been successfully rejoined to the domain $DomainName"
				[pscustomobject]@{ 'Computername' = $Computer; 'Result' = $true }
			} else {
				throw "The computer '$Computer' is offline or name cannot be resolved"	
			}
		} catch {
			[pscustomobject]@{ 'Computername' = $Computer; 'Result' = $false; 'Error' = $_.Exception.Message }
		}
	}
}