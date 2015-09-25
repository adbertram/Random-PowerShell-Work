#Requires -Module AWSPowerShell

<#	
.SYNOPSIS	
	This script creates a CNAME record on the Amazon Route 53 DNS service.  

.DESCRIPTION
	Before using this script you must download and install the AWS tools from https://aws.amazon.com/powershell.  Also,
	you must first ensure your credential profile is setup by using the 
	"Set-AWSCredentials -AccessKey <YourKey> -SecretKey <YourKey> -StoreAs default" command. Once the credentials are
	saved, this script will then use those credentials to connect to AWS.

.EXAMPLE
	PS> .\New-R53CNAMERecord.ps1 -Name hostname -ZoneName test.com -AliasName www.example.com

	This example will connect to the AWS Router 53 DNS service and will create a CNAME record with a name of 'hostname' with
	an alias of 'www.example.com' in the zone 'test.com'
		
.PARAMETER Name
	The hostname of the CNAME record you'd like to create.
	
.PARAMETER ZoneName
	The name of the zone in which you'd like to CNAME record created.

.PARAMETER AliasName
	The alias that will be assigned to the hostname provided.

.PARAMETER TTL
	The TTL to assign to the record set.

.PARAMETER AWSRegion
	The AWS region in which to connect to.
	
.INPUTS
	None. You cannot pipe objects to New-R53CNAMERecord.ps1

.OUTPUTS
	Amazon.Route53.Model.ChangeInfo
#>
[CmdletBinding()]
[OutputType([Amazon.Route53.Model.ChangeInfo])]
param
(
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$Name,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$ZoneName,
	
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$AliasName,
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[int]$TTL = 300,
	
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$AWSRegion = 'us-west-1'
	
)
begin
{
	try
	{
		if ((Get-AWSCredentials -ListStoredCredentials) -notcontains 'default')
		{
			throw 'No default AWS credentials set. To set use the "Set-AWSCredentials -AccessKey <YourKey> -SecretKey <YourKey> -StoreAs default" command'
		}
		Initialize-AWSDefaults -ProfileName default -Region $AWSRegion
	}
	catch 
	{
		$PSCmdlet.ThrowTerminatingError($_)
	}	
}
process {
	try
	{
		#region Validation
		$hostedZones = Get-R53HostedZones
		if ($hostedZones.Name.TrimEnd('.') -notcontains $ZoneName)
		{
			throw "Could not find any hosted DNS zones matching the domain name [$($ZoneName)]"
		}
		#endregion
		$hostedZone = $hostedZones | where { $_.Name -eq "$ZoneName." }
		
		#region Create the CNAME record
		$recordSet = New-Object -TypeName Amazon.Route53.Model.ResourceRecordSet
		$recordSet.Name = "$Name.$ZoneName."
		$recordSet.Type = 'CNAME'
		$recordSet.TTL = $TTL
		$recordSet.ResourceRecords.Add((New-Object Amazon.Route53.Model.ResourceRecord($AliasName)))
		$action = New-Object -TypeName Amazon.Route53.Model.Change
		$action.Action = 'CREATE'
		$action.ResourceRecordSet = $recordSet
		Edit-R53ResourceRecordSet -HostedZoneId $hostedZone.ID -ChangeBatch_Change $action
		#endregion
	}
	catch
	{
		$PSCmdlet.ThrowTerminatingError($_)
	}
}