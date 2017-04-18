
<#PSScriptInfo

.VERSION 1.0

.GUID 68c7b9b3-5093-47e7-bbae-a1c43e555899

.AUTHOR Adam Bertram

.COMPANYNAME Adam the Automator, LLC

.COPYRIGHT 

.TAGS Azure

.LICENSEURI 

.PROJECTURI https://github.com/adbertram/Random-PowerShell-Work/tree/master/Azure

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

#Requires -Module AzureRm

<#
	.SYNOPSIS
		This is a script that expedites the process of assigning permissions to Azure Management APIs.

	.DESCRIPTION
		This is a script that expedites the process of assigning permissions to Azure Management APIs.

	.PARAMETER ApiManagementServiceName
		 A mandatory string parameter representing the name of the API Service Management gateway the APIs live under.

	.PARAMETER ApiManagementServiceResourceGroup
		 A mandatory string parameter representing the name of the resource group the API Service Management gateway 
		 is in.
	.PARAMETER ApiMatchPattern
		 A mandatory string parameter representing a regex pattern to match one or more APIs to assign permissions against,

	.PARAMETER AzureRoleName
		 A mandatory string parameter representing the name of the Azure role definition that will be created to scope
		 the APIs to.

	.PARAMETER AzureRoleDescription
		 A mandatory string parameter representing the description of the Azure role.

	.PARAMETER Rights
		 A mandatory string parameter representing the level of access to give the principal to the APIs. Currently, only
		 read access is configured.

	.PARAMETER PrincipalName
		 A mandatory string parameter representing the name of the Azure AD user or group to assign permissions to the
		 APIs.

	.PARAMETER AzureSubscriptionId
		 A optional string parameter representing the Azuren subsription ID that the API gateway and APIs are created
		 under.

	.EXAMPLE
		
		PS> $params = @{
				ApiManagementServiceName = 'APIGateway'
				ApiManagementServiceResourceGroup = 'GatewayRG'
				ApiMatchPattern = 'FOO'
				AzureRoleName = 'FOO Reader'
				AzureRoleDescription = 'FOO Reader'
				Rights = 'Read'
				PrincipalName = 'FOO-Readers
				AzurSubscriptionId = (Get-AzureRmSubscription).SubscriptionId
			}
		PS> .\Grant-AzureApiAccess.ps1 @params

		Ths example will assign the read only permission on all APIs matching 'FOO' to the FOO-Readersn Azure AD group
		on the API Management Service APIGateway. It will do this by creating an Azure role definition called FOO Reader 
		scoped to just the APIs matched and assign that role to all APIs.

#>
param(
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$ApiManagementServiceName,

	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$ApiManagementServiceResourceGroup,

	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$ApiMatchPattern,

	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$AzureRoleName,

	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$AzureRoleDescription,

	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$Rights,

	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$PrincipalName,

	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$AzurSubscriptionId = (Get-AzureRmSubscription).SubscriptionId
)

## Establish context
$azrContext = New-AzureRmApiManagementContext -ResourceGroupName $ApiManagementServiceResourceGroup -ServiceName $ApiManagementServiceName

## Enumerate all of the APIs to assign access to
if (-not ($apis = @(Get-AzureRmApiManagementApi -Context $azrContext).where({ $_.Name -match $ApiMatchPattern }))) {
	throw "No APIs found matching [$($ApiMatchPattern)] under API service gateway [$($ApiManagementServiceName)]"
}

## Create scopes that the Azure cmdlets understand
$scopes = $apis.ApiId | foreach {
	$strFormat = $AzureSubscriptionId,$ApiManagementServiceResourceGroup,$ApiManagementServiceName,$_
	'/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.ApiManagement/service/{2}/apis/{3}' -f $strFormat
}

## Create the role. Only Read access is implemented now. This assigns all of the scopes for all APIs as assignable
if (-not (Get-AzureRmRoleDefinition -Name $AzureRoleName)) {
	Write-Verbose -Message "No role with name [$($AzureRoleName)] found. Creating..."

	switch ($APIRights) {
		'Read' {
			## Use the API Management Service Reader Role as a template
			$role = Get-AzureRmRoleDefinition 'API Management Service Reader Role'
			$role.Actions.Add('Microsoft.ApiManagement/service/apis/read')
		}
		default {
			throw "Unrecognized input: [$_]"
		}
	}

	$role.Id = $null
	$role.Name = $AzureRoleName
	$role.Description = $AzureRoleDescription
	$role.AssignableScopes.Clear()

	$scopes | foreach {
		$role.AssignableScopes.Add($_)
	}
	New-AzureRmRoleDefinition -Role $role
}

## Assign the previously created role to the APIs to take effect
$principal = Get-AzureRmADGroup -SearchString $PrincipalName
$principalId = $principal.Id.Guid

$scopes | foreach {
	New-AzureRmRoleAssignment -ObjectId $principalId -RoleDefinitionName $AzureRoleName -Scope $_
}
