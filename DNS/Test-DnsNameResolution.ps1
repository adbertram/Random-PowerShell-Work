
<#PSScriptInfo

.VERSION 1.1

.GUID e2603db1-b42d-4456-84f8-6031a8d247fd

.AUTHOR Adam Bertram

.COMPANYNAME Adam the Automator, LLC

.COPYRIGHT 

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

<# 

.DESCRIPTION 
 A script to test if a DNS name can be resolved. 

#> 
[CmdletBinding()]
param
(
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$Name,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$Server
)

$resolvParams = @{
	'Server' = $Server
	'DnsOnly' = $true
	'NoHostsFile' = $true
	'ErrorAction' = 'SilentlyContinue'
	'ErrorVariable' = 'err'
	'Name' = $Name
}
try
{
	if (Resolve-DnsName @resolvParams)
	{
		$true
	}
	elseif ($err -and ($err.Exception.Message -match '(DNS name does not exist)|(No such host is known)'))
	{
		$false
	}
	else
	{
		throw $err
	}
}
catch
{
	if ($_.Exception.Message -match 'No such host is known')
	{
		$false
	}
	else
	{
		throw $_	
	}
}