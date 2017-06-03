#requires -Module PSWebDeploy
#requires -Version 4

function Save-AzrWebApp
{
	<#
		.SYNOPSIS
			This function saves all of the contents of an Azure web app to a local folder.

		.EXAMPLE
			PS> $publishSettings = Get-AzrWebAppPublishInfo -Name 'BDT002-biq' -ResourceGroup 'BDT002'
			PS> $msDeploySettings = @($publishSettings).where({ $_.publishMethod -eq 'MSDeploy' })
			PS> $cred = New-Credential -UserName $msDeploySettings.userName -Password $msDeploySettings.userPWD
			PS> Save-AzrWebApp -Name bdt002-biq -TargetPath C:\WebAppDownloaded -Credential $cred

		.PARAMETER Name
			 A mandatory string parameter representing the name of the Azure app service. To retrieve all available web apps
			 use Get-AzureRmWebApp.
		.PARAMETER TargetPath
			 A mandatory string parameter representing the local folder path. This folder must exist.

		.PARAMETER Credential
			 A mandatory pscredential parameter containing the username and password with permission to read the web app's
			 file contents via msdeploy.
	#>
	[OutputType([System.IO.FileInfo])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$TargetPath,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
	)
	try
	{
		$syncParams = @{
			SourcePath = 'wwwroot'
			TargetPath = $TargetPath
			ComputerName = "https://$Name.scm.azurewebsites.net:443/msdeploy.axd?site=$Name"
			Credential = $Credential

		}
		Sync-Website @syncParams
		Get-Item -Path $TargetPath
	}
	catch
	{
		$PSCmdlet.ThrowTerminatingError($_)
	}
}