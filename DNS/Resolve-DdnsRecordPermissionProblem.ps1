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
	This is the account that client's that can't update their own record allow the DHCP server to do.
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
	
	Start-Transcript -Path 'C:\transscript.txt'
	
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
	
	function Write-Log
	{
	<#
	.SYNOPSIS
		This function creates or appends a line to a log file
 
	.DESCRIPTION
		This function writes a log line to a log file in the form synonymous with 
		ConfigMgr logs so that tools such as CMtrace and SMStrace can easily parse 
		the log file.  It uses the ConfigMgr client log format's file section
		to add the line of the script in which it was called.
 
	.PARAMETER  Message
		The message parameter is the log message you'd like to record to the log file
 
	.PARAMETER  LogLevel
		The logging level is the severity rating for the message you're recording. Like ConfigMgr
		clients, you have 3 severity levels available; 1, 2 and 3 from informational messages
		for FYI to critical messages that stop the install. This defaults to 1.
 
	.EXAMPLE
		PS C:\> Write-Log -Message 'Value1' -LogLevel 'Value2'
		This example shows how to call the Write-Log function with named parameters.
 
	.NOTES
 
	#>
		[CmdletBinding()]
		param (
			[Parameter(
					   Mandatory = $true)]
			[string]$Message,
			
			[Parameter()]
			[ValidateSet(1, 2, 3)]
			[int]$LogLevel = 1
		)
		
		try
		{
			$TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
			## Build the line which will be recorded to the log file
			$Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
			$LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)", $LogLevel
			$Line = $Line -f $LineFormat
			
			## Record the line to the log file if it's declared.  If not, just write to Verbose stream
			## This is helpful when using these functions interactively when you don't preface a function
			## with a Write-Log entry with Start-Log to create the $ScriptLogFilePath variable
			if (Test-Path variable:\ScriptLogFilePath)
			{
				Add-Content -Value $Line -Path $ScriptLogFilePath
			}
			else
			{
				Write-Verbose $Line
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
	
	function Start-Log
	{
	<#
	.SYNOPSIS
		This function creates the initial log file and sets a few global variables
		that are common among the session.  Call this function at the very top of your
		installer script.
 
	.PARAMETER  FilePath
		The file path where you'd like to place the log file on the file system.  If no file path
		specified, it will create a file in the system's temp directory named the same as the script
		which called this function with a .log extension.
 
	.EXAMPLE
		PS C:\> Start-Log -FilePath 'C:\Temp\installer.log
 
	.NOTES
 
	#>
		[CmdletBinding()]
		param (
			[ValidateScript({ Split-Path $_ -Parent | Test-Path })]
			[string]$FilePath = "$([environment]::GetEnvironmentVariable('TEMP', 'Machine'))\$((Get-Item $MyInvocation.ScriptName).Basename + '.log')"
		)
		
		try
		{
			if (!(Test-Path $FilePath))
			{
				## Create the log file
				New-Item $FilePath -ItemType File | Out-Null
			}
			
			## Set the global variable to be used as the FilePath for all subsequent Write-Log
			## calls in this session
			$global:ScriptLogFilePath = $FilePath
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
	
	$ModifyRights = 'CreateChild, DeleteChild, ListChildren, ReadProperty, DeleteTree, ExtendedRight, Delete, GenericWrite, WriteDacl, WriteOwner'
	$FullControlRights = 'GenericAll'
	$Domain = Get-AdDomain -Server $DomainName
	$DomainDn = $Domain.DistinguishedName
	
	Start-Log
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
			## Some may need to replcae $IntegrationScope with 'System' here
			'SearchBase' = "CN=MicrosoftDNS,DC=$IntegrationScope`DnsZones,$DomainDn"
		}
		
		if ($Name)
		{
			Write-Log -Message "Script started using a single record '$Name'"
			$DnsNodeObjectQueryParams.Filter = "objectClass -eq 'dnsNode' -and name -eq '$Name' "
			$DnsRecordQueryParams.Filter = "ContainerName = '$Zone' AND Timestamp <> 0 AND OwnerName = '$Name.$Zone'"
		}
		else
		{
			## No specific record was chosen so we'll look through the whole zone
			Write-Log "No name specified. Will process all records in the zone '$Zone'"
			$DnsNodeObjectQueryParams.Filter = " objectClass -eq 'dnsNode' "
			$DnsRecordQueryParams.Filter = "ContainerName = '$Zone' AND Timestamp <> 0 AND OwnerName <> '$Zone'"
		}
		
		## Find all dynamic DNS records in the zone.  The output has to be trimmed to 15 characters to make a match on the AD object below
		Write-Log -Message "Gathering dynamic records on the '$DnsServer' server in the '$Zone' zone"
		## I must query the records directly instead of just finding the AD objects because I need the timestamp valuec
		$DynamicDnsRecords = (Get-WmiObject @DnsRecordQueryParams | Select-Object -ExpandProperty OwnerName).Trim(".$Zone") | ForEach-Object { $_.SubString(0, [math]::Min(15, $_.Length)) }
		Write-Log -Message "Found $(($DynamicDnsRecords | measure -sum -ea SilentlyContinue).Count) dynamic DNS records in the '$Zone' zone"
		
		## Find all AD dnsNode objects in the specified zone that correspond to a dynamic DNS record
		Write-Log -Message "Finding all dnsNode Active Directory objects"
		$DnsNodeObjects = Get-ADObject @DnsNodeObjectQueryParams | Where-Object { ($DynamicDnsRecords -contains $_.Name) }
		Write-Log -Message "Found $(($DnsNodeObjects | measure -sum -ea SilentlyContinue).Count) matching AD objects"
		
		Write-Log -Message "Processing AD objects"
		foreach ($DnsNodeObject in $DnsNodeObjects)
		{
			try
			{
				$RecordName = $DnsNodeObject.Name
				## Get the current ACL on the dnsNode object
				$Acl = Get-Acl -Path "ActiveDirectory:://RootDSE/$($DnsNodeObject.DistinguishedName)"
				## Put together all the possible valid accounts that should be the owner and should have Modify or Full Control access to the DNS record object
				## This can either be the computer account itself or the DHCP service account
				$ValidAceIdentities = @("$($Domain.NetBIOSName)\$RecordName</code>$", "$($Domain.NetBIOSName)\$DhcpServiceAccount")
				if ($ValidAceIdentities -notcontains $Acl.Owner)
				{
					Write-Log -Message "ACL owner '$($Acl.Owner)' for object '$RecordName' is not valid" -LogLevel '3'
					if (!(Get-ADObject -Filter "name -eq '$RecordName' -and objectClass -eq 'Computer'" -ea SilentlyContinue))
					{
						Write-Log -Message "No AD computer account exists for '$RecordName'. Removing DNS record." -LogLevel '2'
						Get-WmiObject -Computername $DnsServer -Namespace 'root\MicrosoftDNS' -Class MicrosoftDNS_AType -Filter "OwnerName = '$RecordName.$Zone'" | Remove-WmiObject
					}
					elseif ($PSCmdlet.ShouldProcess($RecordName, 'Set-DsAclOwner'))
					{
						Write-Log -Message "Setting correct owner '$RecordName' on record '$RecordName'"
						Set-DsAclOwner -AdObject $DnsNodeObject -Identity $RecordName -NetbiosDomainName $Domain.NetbiosName
					}
				}
				if (!($Acl.Access.IdentityReference | Where-Object { $ValidAceIdentities -contains $_ }))
				{
					Write-Log -Message "No ACE found for computer account or DHCP account for '$($DnsNodeObject.Name)'" -LogLevel '3'
					if (!(Get-ADObject -Filter "name -eq '$RecordName' -and objectClass -eq 'Computer'" -ea SilentlyContinue))
					{
						Write-Log -Message "No AD computer account exists for '$RecordName'. Removing DNS record." -LogLevel '2'
						Get-WmiObject -Computername $DnsServer -Namespace 'root\MicrosoftDNS' -Class MicrosoftDNS_AType -Filter "OwnerName = '$RecordName.$Zone'" | Remove-WmiObject
					}
					elseif ($PSCmdlet.ShouldProcess($RecordName, 'New-DsAce'))
					{
						Write-Log -Message "Creating correct ACE for record '$RecordName'"
						New-DsAce -AdObject $DnsNodeObject -Identity $RecordName -ActiveDirectoryRights $ModifyRights -Right 'Allow' -Acl $Acl
					}
				}
				else
				{
					$Identities = $Acl.Access | Where-Object { $ValidAceIdentities -contains $_.IdentityReference }
					if ($Identities -and @($FullControlRights, $ModifyRights) -notcontains $Identities.ActiveDirectoryRights)
					{
						Write-Log -Message "'$RecordName' does not have sufficient rights to it's object" -LogLevel '3'
						if (!(Get-ADObject -Filter "name -eq '$RecordName' -and objectClass -eq 'Computer'" -ea SilentlyContinue))
						{
							Write-Log -Message "No AD computer account exists for '$RecordName'. Removing DNS record." -LogLevel '2'
							Get-WmiObject -Computername $DnsServer -Namespace 'root\MicrosoftDNS' -Class MicrosoftDNS_AType -Filter "OwnerName = '$RecordName.$Zone'" | Remove-WmiObject
						}
						elseif ($PSCmdlet.ShouldProcess($RecordName, 'Recreate ACE'))
						{
							## Check to see if an orphaned SID exists
							#$sidregex = "^S-\d-\d-\d{2}-\d{9}-\d{10}-\d{10}-\d{5}$"
							#$OrphanedIdentity = $Acl.Access | where { $_.IdentityReference.Value -match $sidregex }
							#Remove-DsAce -AdObject $DnsNodeObject -Identity $OrphanedIdentity -Acl $Acl
							Write-Log -Message "Creating correct ACE for record '$RecordName'"
							New-DsAce -AdObject $DnsNodeObject -Identity $RecordName -ActiveDirectoryRights $ModifyRights -Right 'Allow' -Acl $Acl
						}
					}
				}
			}
			catch
			{
				Write-Log -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" -LogLevel '2'
				Write-Warning "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
			}
		}
		Write-Log -Message "Finished processing AD objects"
	}
	catch
	{
		Write-Log -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" -LogLevel '3'
		Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
	}
}
