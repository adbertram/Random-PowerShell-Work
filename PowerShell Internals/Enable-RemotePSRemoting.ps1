<#
.SYNOPSIS
    
.NOTES
	 Created on:   	5/9/2014 3:46 PM
	 Created by:   	Adam Bertram
	 Organization: 	
	 Filename:     	
.DESCRIPTION
   
.EXAMPLE
    
.EXAMPLE
    
.PARAMETER Computername
 	The remote computer to enable PS remoting on

#>
[CmdletBinding()]
param (
	[Parameter(Mandatory = $True,
			   ValueFromPipeline = $True,
			   ValueFromPipelineByPropertyName = $True)]
	[string]$Computername,
	[Parameter(Mandatory = $False,
			   ValueFromPipeline = $False,
			   ValueFromPipelineByPropertyName = $False)]
	[string]$PsExecPath = 'C:\PsExec.exe'
)

begin {
	## http://www.leeholmes.com/blog/2009/11/20/testing-for-powershell-remoting-test-psremoting/
	function Test-PsRemoting {
		param (
			[Parameter(Mandatory = $true)]
			$computername
		)
		
		try {
			$errorActionPreference = "Stop"
			$result = Invoke-Command -ComputerName $computername { 1 }
		} catch {
			return $false
		}
		
		## I’ve never seen this happen, but if you want to be
		## thorough….
		if ($result -ne 1) {
			Write-Verbose "Remoting to $computerName returned an unexpected result."
			return $false
		}
		$true
	}
	
	if (!(Test-Ping $Computername)) {
		throw 'Computer is not reachable'
	} elseif (!(Test-Path $PsExecPath)) {
		throw 'Psexec.exe not found'	
	}
}

process {
	if (Test-PsRemoting $Computername) {
		Write-Warning "Remoting already enabled on $Computername"
	} else {
		Write-Verbose "Attempting to enable remoting on $Computername..."
		& $PsExecPath "\\$Computername" -s c:\windows\system32\winrm.cmd quickconfig -quiet
		if (!(Test-PsRemoting $Computername)) {
			Write-Warning "Remoting was attempted but not enabled on $Computername"
		} else {
			Write-Verbose "Remoting successfully enabled on $Computername"
		}
	}
}

end {
	
}