#requires -Module AzureRm

param(
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$AzureWebAppName,

	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$AzureResourceGroup,

	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$VirtualPath,

	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$PhysicalPath,

	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[bool]$PreloadEnabled = $false
)

$webApp = Get-AzureRmWebApp -Name $AzureWebAppName -ResourceGroupName $AzureResourceGroup

$VirtualPath = $VirtualPath.Replace('\', '/')
$PhysicalPath = "site\$PhysicalPath"

$virtApp = New-Object Microsoft.Azure.Management.WebSites.Models.VirtualApplication
$virtApp.VirtualPath = $VirtualPath
$virtApp.PhysicalPath = $PhysicalPath
$virtApp.PreloadEnabled = $PreloadEnabled

$null = $webApp.siteconfig.VirtualApplications.Add($virtApp)

Set-AzureRmWebApp -WebApp $webApp

