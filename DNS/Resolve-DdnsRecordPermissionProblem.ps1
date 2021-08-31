#Requires -Module ActiveDirectory

<#
.SYNOPSIS
	Sometimes AD-integrated dynamic DNS records' permissions become inconsistent.  By default, a dynamically-registered
	record that was registered by a Windows host has the AD computer object as the owner and has either Modify or Full Control
	permissions to the record.  This script is meant to search for and fix any record that has strayed from this configuration.
 
	Once fixed, this then allows the computer again to successfully update it's record.
.NOTES
	Created on: 	10/3/2014
	Created by: 	Adam Bertram
	Filename:		Resolve-DynamicDnsRecordPermissionProblem.ps1
.EXAMPLE
	PS> .\Resolve-DynamicDnsRecordPermissionProblem.ps1 -Zone myzone.com 
 
	This example will search all records in the myzone.com DNS zone and fix any permissions problems it finds.
.PARAMETER Zone
	The name of the DNS zone that contains records you'd like to check
.PARAMETER Name
	This is the name of a single DNS record.  Use this if you just want to check a single record.
.PARAMETER DnsServer
	The DNS server that is hosting the zone you'd like to check. This defaults to a domain controller.
.PARAMETER DomainName
 	The Active Directory domain name.  This defaults to the current domain
.PARAMETER IntegrationScope
	This is the DNS integration type.  This can either be Forest and Domain.
.PARAMETER DhcpServiceAccount
	This is the account to be used for client's that can't update their own record and allow the DHCP server to do so.
#>
[CmdletBinding(SupportsShouldProcess)]
[OutputType()]
param (
	[Parameter(Mandatory,
			   ValueFromPipeline,
			   ValueFromPipelineByPropertyName)]
	[string]$Zone,
	
	[Parameter(ValueFromPipeline,
			   ValueFromPipelineByPropertyName)]
	[string]$Name,
	
	[Parameter(ValueFromPipeline,
			   ValueFromPipelineByPropertyName)]
	[string]$DnsServer = (Get-ADDomain).ReplicaDirectoryServers[0],
	
	[Parameter(ValueFromPipeline,
			   ValueFromPipelineByPropertyName)]
	[string]$DomainName = (Get-ADDomain).Forest,
	
	[ValidateSet('Forest', 'Domain')]
	[Parameter(ValueFromPipeline,
			   ValueFromPipelineByPropertyName)]
	[string]$IntegrationScope = 'Forest',
	
	[Parameter(ValueFromPipeline,
			   ValueFromPipelineByPropertyName)]
	[string]$DhcpServiceAccount = 'dhcpdns.svc'
)

begin
{
	$ErrorActionPreference = 'Stop'
	Set-StrictMode -Version Latest
	
	function Remove-DsAce ([Microsoft.ActiveDirectory.Management.ADObject]$AdObject, [string]$Identity, [System.DirectoryServices.ActiveDirectorySecurity]$Acl)
	{
		$AceToRemove = $Acl.Access | Where-Object { $_.IdentityReference.Value.Split('\')[1] -eq "$Identity<code>$" }
		$Acl.RemoveAccessRule($AceToRemove)
		Set-Acl -Path "ActiveDirectory:://RootDSE/$($AdObject.DistinguishedName)" -AclObject $Acl
	}
	
	function New-DsAce ([Microsoft.ActiveDirectory.Management.ADObject]$AdObject, [string]$Identity, [string]$ActiveDirectoryRights, [string]$Right, [System.DirectoryServices.ActiveDirectorySecurity]$Acl)
	{
		$Sid = (Get-ADObject -Filter "name -eq '$Identity' -and objectClass -eq 'Computer'" -Properties ObjectSID).ObjectSID
		$NewAccessRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($Sid, $ActiveDirectoryRights, $Right)
		$Acl.AddAccessRule($NewAccessRule)
		Set-Acl -Path "ActiveDirectory:://RootDSE/$($AdObject.DistinguishedName)" -AclObject $Acl
	}
	
	function Set-DsAclOwner ([Microsoft.ActiveDirectory.Management.ADObject]$AdObject, [string]$Identity, [string]$NetbiosDomainName)
	{
		$User = New-Object System.Security.Principal.NTAccount($NetbiosDomainName, "$Identity$")
		$Acl.SetOwner($User)
		Set-Acl -Path "ActiveDirectory:://RootDSE/$($AdObject.DistinguishedName)" -AclObject $Acl
	}
	
	$ModifyRights = 'CreateChild, DeleteChild, ListChildren, ReadProperty, DeleteTree, ExtendedRight, Delete, GenericWrite, WriteDacl, WriteOwner'
	$FullControlRights = 'GenericAll'
	$Domain = Get-AdDomain -Server $DomainName
	$DomainDn = $Domain.DistinguishedName
}

process
{
	try
	{
		$DnsRecordQueryParams = @{
			'Computername' = $DnsServer
			'Class' = 'MicrosoftDNS_AType'
			'Namespace' = 'root\MicrosoftDNS'
		}
		$DnsNodeObjectQueryParams = @{
			## Some may need to replace $IntegrationScope with 'System' here
			'SearchBase' = "CN=MicrosoftDNS,DC=$IntegrationScope`DnsZones,$DomainDn"
		}
		
		if ($Name)
		{
			Write-Verbose -Message "Script started using a single record '$Name'"
			$DnsNodeObjectQueryParams.Filter = "objectClass -eq 'dnsNode' -and name -eq '$Name' "
			$DnsRecordQueryParams.Filter = "ContainerName = '$Zone' AND Timestamp <> 0 AND OwnerName = '$Name.$Zone'"
		}
		else
		{
			## No specific record was chosen so we'll look through the whole zone
			Write-Verbose "No name specified. Will process all records in the zone '$Zone'"
			$DnsNodeObjectQueryParams.Filter = " objectClass -eq 'dnsNode' "
			$DnsRecordQueryParams.Filter = "ContainerName = '$Zone' AND Timestamp <> 0 AND OwnerName <> '$Zone'"
		}
		
		## Find all dynamic DNS records in the zone.  The output has to be trimmed to 15 characters to make a match on the AD object below
		Write-Verbose -Message "Gathering dynamic records on the '$DnsServer' server in the '$Zone' zone"
		## I must query the records directly instead of just finding the AD objects because I need the timestamp values
        $DynamicDnsRecords = (Get-WmiObject @DnsRecordQueryParams | Where-Object {$_.DomainName -eq $Zone}).OwnerName -replace "`.$Zone$","" | ForEach-Object { $_.SubString(0, [math]::Min(15, $_.Length)) }
		Write-Verbose -Message "Found $(($DynamicDnsRecords | measure -sum -ea SilentlyContinue).Count) dynamic DNS records in the '$Zone' zone"
		
		## Find all AD dnsNode objects in the specified zone that correspond to a dynamic DNS record
		Write-Verbose -Message "Finding all dnsNode Active Directory objects"
		$DnsNodeObjects = Get-ADObject @DnsNodeObjectQueryParams | Where-Object { ($DynamicDnsRecords -contains $_.Name) }
		Write-Verbose -Message "Found $(($DnsNodeObjects | measure -sum -ea SilentlyContinue).Count) matching AD objects"
		
		Write-Verbose -Message "Processing AD objects"
		foreach ($DnsNodeObject in $DnsNodeObjects)
		{
			try
			{
				$RecordName = $DnsNodeObject.Name
				## Get the current ACL on the dnsNode object
				$Acl = Get-Acl -Path "ActiveDirectory:://RootDSE/$($DnsNodeObject.DistinguishedName)"
				## Put together all the possible valid accounts that should be the owner and should have Modify or Full Control access to the DNS record object
				## This can either be the computer account itself or the DHCP service account
				$ValidAceIdentities = @("$($Domain.NetBIOSName)\$RecordName$", "$($Domain.NetBIOSName)\$DhcpServiceAccount")
				if ($ValidAceIdentities -notcontains $Acl.Owner)
				{
					Write-Warning -Message "ACL owner '$($Acl.Owner)' for object '$RecordName' is not valid"
					if (!(Get-ADObject -Filter "name -eq '$RecordName' -and objectClass -eq 'Computer'" -ea SilentlyContinue))
					{
						Write-Warning -Message "No AD computer account exists for '$RecordName'. Removing DNS record."
						Get-WmiObject -Computername $DnsServer -Namespace 'root\MicrosoftDNS' -Class MicrosoftDNS_AType -Filter "OwnerName = '$RecordName.$Zone'" | Remove-WmiObject
					}
					elseif ($PSCmdlet.ShouldProcess($RecordName, 'Set-DsAclOwner'))
					{
						Write-Verbose -Message "Setting correct owner '$RecordName' on record '$RecordName'"
						Set-DsAclOwner -AdObject $DnsNodeObject -Identity $RecordName -NetbiosDomainName $Domain.NetbiosName
					}
				}
				if (!($Acl.Access.IdentityReference | Where-Object { $ValidAceIdentities -contains $_ }))
				{
					Write-Warning -Message "No ACE found for computer account or DHCP account for '$($DnsNodeObject.Name)'"
					if (!(Get-ADObject -Filter "name -eq '$RecordName' -and objectClass -eq 'Computer'" -ea SilentlyContinue))
					{
						Write-Warning -Message "No AD computer account exists for '$RecordName'. Removing DNS record."
						Get-WmiObject -Computername $DnsServer -Namespace 'root\MicrosoftDNS' -Class MicrosoftDNS_AType -Filter "OwnerName = '$RecordName.$Zone'" | Remove-WmiObject
					}
					elseif ($PSCmdlet.ShouldProcess($RecordName, 'New-DsAce'))
					{
						Write-Verbose -Message "Creating correct ACE for record '$RecordName'"
						New-DsAce -AdObject $DnsNodeObject -Identity $RecordName -ActiveDirectoryRights $ModifyRights -Right 'Allow' -Acl $Acl
					}
				}
				else
				{
					$Identities = $Acl.Access | Where-Object { $ValidAceIdentities -contains $_.IdentityReference }
					if ($Identities -and @($FullControlRights, $ModifyRights) -notcontains $Identities.ActiveDirectoryRights)
					{
						Write-Warning -Message "'$RecordName' does not have sufficient rights to it's object"
						if (!(Get-ADObject -Filter "name -eq '$RecordName' -and objectClass -eq 'Computer'" -ea SilentlyContinue))
						{
							Write-Warning -Message "No AD computer account exists for '$RecordName'. Removing DNS record."
							Get-WmiObject -Computername $DnsServer -Namespace 'root\MicrosoftDNS' -Class MicrosoftDNS_AType -Filter "OwnerName = '$RecordName.$Zone'" | Remove-WmiObject
						}
						elseif ($PSCmdlet.ShouldProcess($RecordName, 'Recreate ACE'))
						{
							## Check to see if an orphaned SID exists
							#$sidregex = "^S-\d-\d-\d{2}-\d{9}-\d{10}-\d{10}-\d{5}$"
							#$OrphanedIdentity = $Acl.Access | where { $_.IdentityReference.Value -match $sidregex }
							#Remove-DsAce -AdObject $DnsNodeObject -Identity $OrphanedIdentity -Acl $Acl
							Write-Verbose -Message "Creating correct ACE for record '$RecordName'"
							New-DsAce -AdObject $DnsNodeObject -Identity $RecordName -ActiveDirectoryRights $ModifyRights -Right 'Allow' -Acl $Acl
						}
					}
				}
			}
			catch
			{
				Write-Warning "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
			}
		}
		Write-Verbose -Message "Finished processing AD objects"
	}
	catch
	{
		Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
	}
}
