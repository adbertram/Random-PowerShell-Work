function Test-PendingReboot {
	<#
		.SYNOPSIS
			This function tests various registry values to see if the local computer is pending a reboot
		.NOTES
			Inspiration from: https://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542
		.EXAMPLE
			PS> Test-PendingReboot
			
			This example checks various registry values to see if the local computer is pending a reboot.
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$icmParams = @{
				'ComputerName' = $ComputerName
			}
			
			$OperatingSystem = Invoke-Command @icmParams -ScriptBlock { Get-CimInstance -ClassName 'Win32_OperatingSystem' -Property 'BuildNumber', 'CSName' }

			# If Vista/2008 & Above query the CBS Reg Key
			If ($OperatingSystem.BuildNumber -ge 6001) {
				$icmParams.ScriptBlock = { Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing' -Name 'RebootPending' -ErrorAction SilentlyContinue }
				if (Invoke-Command @icmParams) {
					Write-Verbose -Message 'Reboot pending detected in the Component Based Servicing registry key'
					$true
				}
			}

			# Query WUAU from the registry
			$icmParams.ScriptBlock = { Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Name 'RebootRequired' -ErrorAction SilentlyContinue }
			if (Invoke-Command @icmParams) {
				Write-Verbose -Message 'WUAU has a reboot pending'
				$true
			}
			
			# Query PendingFileRenameOperations from the registry
			$icmParams.ScriptBlock = { Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue }
			$PendingReboot = Invoke-Command @icmParams
			if ($PendingReboot -and $PendingReboot.PendingFileRenameOperations) {
				Write-Verbose -Message 'Reboot pending in the PendingFileRenameOperations registry value'
				$true
			}
		} catch {
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}
