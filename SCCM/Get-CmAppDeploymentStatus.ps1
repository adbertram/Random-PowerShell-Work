<#
.SYNOPSIS
	This script checks status of a deployed application to members of a SCCM collection or a single SCCM client
.NOTES
	Requires the SQL PSCX modules here https://sqlpsx.codeplex.com/documentation
.EXAMPLE
	PS> Get-CmAppDeploymentStatus.ps1 -CollectionName 'My Collection' -ApplicationName MyApplication

	This example enumerates all collection members in the collection 'My Collection' then evaluates each of them
	to see what the status of the application MyApplication is.
.PARAMETER CollectionName
 	The name of the SCCM collection you'd like to query members in
.PARAMETER Computername
	The name of one or more PCs to check application deployment status
.PARAMETER ApplicationName
	The name of the application to check the status of
.PARAMETER SiteServer
	Your SCCM site server
.PARAMETER SiteCode
	The 3 character SCCM site code
#>
[CmdletBinding(DefaultParameterSetName = 'None')]
param (
	[Parameter(ParameterSetName = 'Collection', Mandatory)]
	[string]$CollectionName,
	[Parameter(ParameterSetName = 'Computer', Mandatory)]
	[string[]]$Computername,
	[string]$ApplicationName,
	[string]$SiteServer = 'MYSITESERVER',
	[string]$SiteCode = 'CON'
)

begin {
	Set-StrictMode -Version Latest
	
	function Get-CmCollectionMember ($Collection) {
		try {
			$Ns = "ROOT\sms\site_$SiteCode"
			$Col = Get-CimInstance -ComputerName $SiteServer -Class 'SMS_Collection' -Namespace $Ns -Filter "Name = '$Collection'"
			$ColId = $Col.CollectionID;
			Get-CimInstance -Computername $SiteServer -Namespace $Ns -Class "SMS_CM_RES_COLL_$ColId"
		} catch {
			Write-Error $_.Exception.Message
		}
	}
	
	function Get-CmClientAppDeploymentStatus ($Computername,$ApplicationName) {
		$EvalStates = @{
			0 = 'No state information is available';
			1 = 'Application is enforced to desired/resolved state';
			2 = 'Application is not required on the client';
			3 = 'Application is available for enforcement (install or uninstall based on resolved state). Content may/may not have been downloaded';
			4 = 'Application last failed to enforce (install/uninstall)';
			5 = 'Application is currently waiting for content download to complete';
			6 = 'Application is currently waiting for content download to complete';
			7 = 'Application is currently waiting for its dependencies to download';
			8 = 'Application is currently waiting for a service (maintenance) window';
			9 = 'Application is currently waiting for a previously pending reboot';
			10 = 'Application is currently waiting for serialized enforcement';
			11 = 'Application is currently enforcing dependencies';
			12 = 'Application is currently enforcing';
			13 = 'Application install/uninstall enforced and soft reboot is pending';
			14 = 'Application installed/uninstalled and hard reboot is pending';
			15 = 'Update is available but pending installation';
			16 = 'Application failed to evaluate';
			17 = 'Application is currently waiting for an active user session to enforce';
			18 = 'Application is currently waiting for all users to logoff';
			19 = 'Application is currently waiting for a user logon';
			20 = 'Application in progress, waiting for retry';
			21 = 'Application is waiting for presentation mode to be switched off';
			22 = 'Application is pre-downloading content (downloading outside of install job)';
			23 = 'Application is pre-downloading dependent content (downloading outside of install job)';
			24 = 'Application download failed (downloading during install job)';
			25 = 'Application pre-downloading failed (downloading outside of install job)';
			26 = 'Download success (downloading during install job)';
			27 = 'Post-enforce evaluation';
			28 = 'Waiting for network connectivity';
		}
		
		$Params = @{
			'Computername' = $Computername
			'Namespace' = 'root\ccm\clientsdk'
			'Class' = 'CCM_Application'
		}
		if ($ApplicationName) {
			Get-WmiObject @Params | Where-Object { $_.FullName -eq $ApplicationName } | Select-Object PSComputerName, Name, InstallState, ErrorCode, @{ n = 'EvalState'; e = { $EvalStates[[int]$_.EvaluationState] } }, @{ label = 'ApplicationMadeAvailable'; expression = { $_.ConvertToDateTime($_.StartTime) } }
		} else {
			Get-WmiObject @Params | Select-Object PSComputerName, Name, InstallState, ErrorCode, @{ n = 'EvalState'; e = { $EvalStates[[int]$_.EvaluationState] } }, @{ label = 'ApplicationMadeAvailable'; expression = { $_.ConvertToDateTime($_.StartTime) } }
		}
	}
	
	function Test-Ping ($ComputerName) {
		try {
			$oPing = new-object system.net.networkinformation.ping;
			if (($oPing.Send($ComputerName, 200).Status -eq 'TimedOut')) {
				$false
			} else {
				$true	
			}
		} catch [System.Exception] {
			$false
		}
	}
}

process {
	if ($CollectionName) {
		$Clients = (Get-CmCollectionMember -Collection $CollectionName).Name
	} else {
		$Clients = $Computername
	}
	Write-Verbose "Will query '$($Clients.Count)' clients"
	foreach ($Client in $Clients) {
		try {
			if (!(Test-Ping -ComputerName $Client)) {
				throw "$Client is offline"
			} else {
				$Params = @{ 'Computername' = $Client }
				if ($ApplicationName) {
					$Params.ApplicationName = $ApplicationName
				}
				Get-CmClientAppDeploymentStatus @Params
			}
		} catch {
			Write-Warning $_.Exception.Message
		}
	}
}