## CREDIT: Module originally created by Sarah Dutkiewicz (http://sadukie.com)

# TODO: Get App ID and API Key from: https://twit-tv.3scale.net/
$appid = 'APPID'
$appkey = 'APPKEY'

# Setup some headers for consuming the TWiT API RESTfully
$acceptheader = 'application/json'

$headers = @{
	'Accept' = $acceptheader
	'app-id' = $appid
	'app-key' = $appkey
}

# Comment-based help: https://technet.microsoft.com/en-us/library/hh847834.aspx

function Get-TWiTShow()
{
	[CmdletBinding()]
	param ()
	<#
	.SYNOPSIS 
		Gets a list of the shows on TWiT.tv

	.DESCRIPTION
		Get-TWiTShow queries the Twit REST API to gather a list of all shows.  

		It returns a PSObject that contains:
		- count: The number of shows in the result set
		- shows: A list of the shows on TWiT.tv. See the TWiT.tv API guide for more details.

	.INPUTS
		None. You cannot pipe objects to Get-TWiTShow

	.OUTPUTS
		Generates a PSObject that contains:
		- count: The number of shows in the result set
		- shows: A list of the shows on TWiT.tv. See the TWiT.tv API guide for more details.

	.LINK
		http://docs.twittv.apiary.io/#reference/shows            
	#>	
	
	Invoke-RestMethod https://twit.tv/api/v1.0/shows -Headers $headers
}

function Get-TWiTEpisode
{
	<#
    .SYNOPSIS 
    	Gets a list of the episodes on TWiT.tv for a particular show

    .DESCRIPTION
	    Gets a list of the episodes on TWiT.tv for a particular show
		
		Returns a PSObject that contains:
		- count: The number of episodes in the result set
		- episodes: A list of the episodes on TWiT.tv for a particular show. See the TWiT.tv API guide for more details.
    
	.INPUTS
		None. You cannot pipe objects to Get-TWiTEpisode
	
	.OUTPUTS
		Generates a PSObject that contains:
		- count: The number of episodes for a particular show in the result set
		- episodes: A list of the episodes on TWiT.tv for a particular show. See the TWiT.tv API guide for more details.
	
	.EXAMPLE
		Get all the episodes for the show with the ID of 1680
		
		Get-TWiTEpisode -ShowID 1680
	
	.EXAMPLE
		Get all episodes for Coding 101
		
		$Shows = Get-TWiTShow
		$ShowID = $Shows.shows | where { $_.label -eq "Coding 101"} | Select $_.id
		Get-TWiTEpisode -ShowID $ShowID.id
	
	.LINK
    	http://docs.twittv.apiary.io/#reference/episodes           
    #>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[int]$ShowId
	)
	
	Invoke-RestMethod https://twit.tv/api/v1.0/episodes?filter[shows]=$ShowID -Headers $headers

}

# Leaving out help for this one to show default help behavior
function Get-TWiTCategory()
{
	[CmdletBinding()]
	param ()
	
	Invoke-RestMethod https://twit.tv/api/v1.0/categories -Headers $headers
	
}

# Export all of the Get cmdlets --not necessary unless there might be functions that don't start with Get-*
Export-ModuleMember -Function 'Get-*'