<#
.SYNOPSIS
    This script adds a random sampling of online clients from another ConfigMgr collection
.DESCRIPTION
    This script is useful for creating test collections for testing software deployments. It pings a random sampling of clients from
    one collection and adds them into another collection.
.EXAMPLE
    .\CreateRandomMemberConfigMgrCollection.ps1 -Server CONFIGMANAGER -SourceCollectionName COLLECTIONNAME -DestinationCollectionName COLLECTIONNAME -NumberOfClients 30
.PARAMETER Server
    The ConfigMgr site server name
.PARAMETER SourceCollectionName
    The name of the ConfigMgr collection that will be used to sample clients from
.PARAMETER DestinationCollectionName
    The name of the ConfigMgr collection that will be used (or created if doesn't exist) to place the random sampling of clients
.PARAMETER NumberOfClients
    This is how many clients are taken at random from the source collection to make the destination collection's members
.NOTES
	Revisions: 06/11/2014 
				- filtered $SourceClients by only including OSes 'Microsoft Windows NT'
				- modified the way a random client is chosen
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory = $False,
			   ValueFromPipeline = $False,
			   ValueFromPipelineByPropertyName = $False,
			   HelpMessage = 'What site server would you like to connect to?')]
	[string]$Server = 'CONFIGMANAGER',
	[Parameter(Mandatory = $False,
			   ValueFromPipeline = $False,
			   ValueFromPipelineByPropertyName = $False,
			   HelpMessage = 'What site does your ConfigMgr site server exist in?')]
	[string]$Site = 'UHP',
	[Parameter(Mandatory = $True,
			   ValueFromPipeline = $True,
			   ValueFromPipelineByPropertyName = $True,
			   HelpMessage = 'What device collection would you like to get clients from?')]
	[string]$SourceCollectionName,
	[Parameter(Mandatory = $True,
			   ValueFromPipeline = $True,
			   ValueFromPipelineByPropertyName = $True,
			   HelpMessage = 'What device collection would you like to put the random clients into?')]
	[string]$DestinationCollectionName,
	[Parameter(Mandatory = $True,
			   ValueFromPipeline = $False,
			   ValueFromPipelineByPropertyName = $True,
			   HelpMessage = 'How many random clients would you like to put into the destination collection?')]
	[int]$NumberOfClients
)

begin {
	try {
		## I capture the drive path first because I have to switch to the ConfigMgr provider drive
		## to use the ConfigMgr cmdlets.  I will change the drive path to the original after the
		## script is complete.
		$BeforeLocation = (Get-Location).Path
		Set-Location "$Site`:"
		
		$ConfigMgrWmiProps = @{
			'ComputerName' = $Server;
			'Namespace' = "root\sms\site_$Site"
		}
		
		Write-Verbose 'Verifying parameters...'
		if (!(Get-CmDeviceCollection -Name $SourceCollectionName)) {
			throw "$SourceCollectionName does not exist"
		} elseif (!(Get-CmDeviceCollection -Name $DestinationCollectionName)) {
			throw "$DestinationCollectionName does not exist"
		}
		$SourceCollectionId = (Get-WmiObject @ConfigMgrWmiProps -Class SMS_Collection -Filter "Name = '$SourceCollectionName'").CollectionId
		$DestinationCollectionId = (Get-WmiObject @ConfigMgrWmiProps -Class SMS_Collection -Filter "Name = '$DestinationCollectionName'").CollectionId
		$SourceClients = Get-WmiObject @ConfigMgrWmiProps -Class "SMS_CM_RES_COLL_$SourceCollectionId" | where { $_.DeviceOS -match 'Microsoft Windows NT' } | select Name, DeviceOS | group DeviceOS | sort count -Descending
		$ExistingDestinationClients = Get-WmiObject @ConfigMgrWmiProps -Class "SMS_CM_RES_COLL_$DestinationCollectionId" | select -ExpandProperty Name
		if ($SourceClients.Count -eq 0) {
			throw 'Source collection does not contain any members'
		}
		$TargetClients = @()
	} catch {
		## TODO: Ensure this breaks out of the entire script rather than just the BEGIN block
		Write-Error $_.Exception.Message
	}
}

process {
	try {
		if ($NumberOfClients -lt $SourceClients.Count) {
			Write-Verbose "Number of clients needed ($NumberOfClients) are less than total number of operating system groups ($($SourceClients.Count))..."
			## Find the OSes that have the highest count and get random clients from each of those
			## $SourceClients was sorted desc above so I know the lowest array indexes have the highest counts
			$OsGroups = $SourceClients[0..($NumberOfClients - 1)]
		} else {
			Write-Verbose "Number of clients needed ($NumberOfClients) are equal to or exceed total operating system groups ($($SourceClients.Count))..."
			$OsGroups = $SourceClients
		}
		Write-Verbose "Total OS groupings: $($OsGroups.Count)"
		
		## TODO: What if the number of clients needed is greater than the online source clients?
		for ($i = 0; $TargetClients.Count -lt $NumberOfClients; $i++) {
			$GroupIndex = $i % $OsGroups.Count
			Write-Verbose "Using group index $GroupIndex..."
			$OsGroup = $OsGroups[$GroupIndex].Group
			Write-Verbose "Using group $($OsGroups[$GroupIndex].Name)..."
			$ClientName = ($OsGroups[$GroupIndex].Group | Get-Random).Name
			Write-Verbose "Testing $ClientName for validity to add to target collection..."
			if (($TargetClients -notcontains $ClientName) -and ($ExistingDestinationClients -notcontains $ClientName) -and (Test-Ping $ClientName)) {
				Write-Verbose "$ClientName found to be acceptable. Adding to target collection array..."
				$TargetClients += $ClientName
			}
		}
		Write-Verbose 'Finished checking clients.  Begin adding to target collection...'
		
		## The TargetClients array is necessary instead of directly adding membership rules in the for loop
		## before if not, I couldn't ensure dups aren't added
		$TargetClients |
		foreach {
			Write-Verbose "Adding $($_) to target collection $DestinationCollectionName..."
			Add-CMDeviceCollectionDirectMembershipRule -CollectionName $DestinationCollectionName -ResourceId (Get-CmDevice -Name $_).ResourceID
		}
	} catch {
		Write-Error $_.Exception.Message
	}
}

end {
	Set-Location $BeforeLocation
}