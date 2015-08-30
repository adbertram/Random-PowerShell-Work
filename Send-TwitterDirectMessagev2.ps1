function Get-OAuthAuthorization {
	<#
	.SYNOPSIS
		This function is used to setup all the appropriate security stuff needed to issue
		API calls against Twitter's API.  It has been tested with v1.1 of the API.  It currently
		includes support only for sending tweets from a single user account and to send DMs from
		a single user account.
	.EXAMPLE
		Get-OAuthAuthorization -DmMessage 'hello' -HttpEndPoint 'https://api.twitter.com/1.1/direct_messages/new.json' -Username adam
	
		This example gets the authorization string needed in the HTTP POST method to send a direct
		message with the text 'hello' to the user 'adam'.
	.EXAMPLE
		Get-OAuthAuthorization -TweetMessage 'hello' -HttpEndPoint 'https://api.twitter.com/1.1/statuses/update.json'
	
		This example gets the authorization string needed in the HTTP POST method to send out a tweet.
	.PARAMETER HttpEndPoint
		This is the URI that you must use to issue calls to the API.
	.PARAMETER TweetMessage
		Use this parameter if you're sending a tweet.  This is the tweet's text.
	.PARAMETER DmMessage
		If you're sending a DM to someone, this is the DM's text.
	.PARAMETER Username
		If you're sending a DM to someone, this is the username you'll be sending to.
	.PARAMETER ApiKey
		The API key for the Twitter application you previously setup.
	.PARAMETER ApiSecret
		The API secret key for the Twitter application you previously setup.
	.PARAMETER AccessToken
		The access token that you generated within your Twitter application.
	.PARAMETER
		The access token secret that you generated within your Twitter application.
	#>
	[CmdletBinding(DefaultParameterSetName = 'None')]
	[OutputType('System.Management.Automation.PSCustomObject')]
	param (
		[Parameter(Mandatory)]
		[string]$HttpEndPoint,
		[Parameter(Mandatory,ParameterSetName='NewTweet')]
		[string]$TweetMessage,
		[Parameter(Mandatory, ParameterSetName = 'DM')]
		[string]$DmMessage,
		[Parameter(Mandatory,ParameterSetName='DM')]
		[string]$Username,
		[Parameter()]
		[string]$ApiKey = 'qE0WtEleJzp8ErWI82B3Jw8gl',
		[Parameter()]
		[string]$ApiSecret = 'r06813yKNEjaErJc4mkacWmFSNwnT1H05Yyjd8XQ5bOhKxVBVc',
		[Parameter()]
		[string]$AccessToken = '19891458-FL3362GmrreMWUfoPM9Y1gpluAigRbsS36Fv2t2d0',
		[Parameter()]
		[string]$AccessTokenSecret = 'muMHKAbmdIu1P462gZel4HhhnySGx6VwoaeN2cBVt8EEf'
	)
	
	begin {
		$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
		Set-StrictMode -Version Latest
		try {
			[Reflection.Assembly]::LoadWithPartialName("System.Security") | Out-Null
			[Reflection.Assembly]::LoadWithPartialName("System.Net") | Out-Null
		} catch {
			Write-Error $_.Exception.Message
		}
	}
	
	process {
		try {
			## Generate a random 32-byte string. I'm using the current time (in seconds) and appending 5 chars to the end to get to 32 bytes
			## Base64 allows for an '=' but Twitter does not.  If this is found, replace it with some alphanumeric character
			$OauthNonce = [System.Convert]::ToBase64String(([System.Text.Encoding]::ASCII.GetBytes("$([System.DateTime]::Now.Ticks.ToString())12345"))).Replace('=', 'g')
			Write-Verbose "Generated Oauth none string '$OauthNonce'"
			
			## Find the total seconds since 1/1/1970 (epoch time)
			$EpochTimeNow = [System.DateTime]::UtcNow - [System.DateTime]::ParseExact("01/01/1970", "dd/MM/yyyy", $null)
			Write-Verbose "Generated epoch time '$EpochTimeNow'"
			$OauthTimestamp = [System.Convert]::ToInt64($EpochTimeNow.TotalSeconds).ToString();
			Write-Verbose "Generated Oauth timestamp '$OauthTimestamp'"
			
			## Build the signature
			$SignatureBase = "$([System.Uri]::EscapeDataString($HttpEndPoint))&"
			$SignatureParams = @{
				'oauth_consumer_key' = $ApiKey;
				'oauth_nonce' = $OauthNonce;
				'oauth_signature_method' = 'HMAC-SHA1';
				'oauth_timestamp' = $OauthTimestamp;
				'oauth_token' = $AccessToken;
				'oauth_version' = '1.0';
			}
			if ($TweetMessage) {
				$SignatureParams.status = $TweetMessage
			} elseif ($DmMessage) {
				$SignatureParams.screen_name = $Username
				$SignatureParams.text = $DmMessage
			}
			
			## Create a string called $SignatureBase that joins all URL encoded 'Key=Value' elements with a &
			## Remove the URL encoded & at the end and prepend the necessary 'POST&' verb to the front
			$SignatureParams.GetEnumerator() | sort name | foreach { $SignatureBase += [System.Uri]::EscapeDataString("$($_.Key)=$($_.Value)&") }
			$SignatureBase = $SignatureBase.TrimEnd('%26')
			$SignatureBase = 'POST&' + $SignatureBase
			Write-Verbose "Base signature generated '$SignatureBase'"
			
			## Create the hashed string from the base signature
			$SignatureKey = [System.Uri]::EscapeDataString($ApiSecret) + "&" + [System.Uri]::EscapeDataString($AccessTokenSecret);
			
			$hmacsha1 = new-object System.Security.Cryptography.HMACSHA1;
			$hmacsha1.Key = [System.Text.Encoding]::ASCII.GetBytes($SignatureKey);
			$OauthSignature = [System.Convert]::ToBase64String($hmacsha1.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($SignatureBase)));
			Write-Verbose "Using signature '$OauthSignature'"
			
			## Build the authorization headers using most of the signature headers elements.  This is joining all of the 'Key=Value' elements again
			## and only URL encoding the Values this time while including non-URL encoded double quotes around each value
			$AuthorizationParams = $SignatureParams
			$AuthorizationParams.Add('oauth_signature', $OauthSignature)
			
			## Remove any API call-specific params from the authorization params
			$AuthorizationParams.Remove('status')
			$AuthorizationParams.Remove('text')
			$AuthorizationParams.Remove('screen_name')
			
			$AuthorizationString = 'OAuth '
			$AuthorizationParams.GetEnumerator() | sort name | foreach { $AuthorizationString += $_.Key + '="' + [System.Uri]::EscapeDataString($_.Value) + '", ' }
			$AuthorizationString = $AuthorizationString.TrimEnd(', ')
			Write-Verbose "Using authorization string '$AuthorizationString'"
			
			$AuthorizationString
			
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Send-Tweet {
	<#
	.SYNOPSIS
		This sends a tweet under a username.
	.EXAMPLE
		Send-Tweet -Message 'hello, world'
	
		This example will send a tweet with the text 'hello, world'.
	.PARAMETER Message
		The text of the tweet.
	#>
	[CmdletBinding()]
	[OutputType('System.Management.Automation.PSCustomObject')]
	param (
		[Parameter(Mandatory)]
		[ValidateLength(1, 140)]
		[string]$Message
	)
	
	process {
		$HttpEndPoint = 'https://api.twitter.com/1.1/statuses/update.json'
		
		$AuthorizationString = Get-OAuthAuthorization -TweetMessage $Message -HttpEndPoint $HttpEndPoint
		
		## Convert the message to a Byte array
		$Body = [System.Text.Encoding]::ASCII.GetBytes("status=$Message");
		Write-Verbose "Using POST body '$Body'"
		Invoke-RestMethod -URI $HttpEndPoint -Method Post -Body $Body -Headers @{ 'Authorization' = $AuthorizationString } -ContentType "application/x-www-form-urlencoded"
	}
}

function Send-TwitterDm {
	<#
	.SYNOPSIS
		This sends a DM to another Twitter user.
	.EXAMPLE
		Send-TwitterDm -Message 'hello, Adam' -Username 'adam'
	
		This sends a DM with the text 'hello, Adam' to the username 'adam'
	.PARAMETER Message
		The text of the DM.
	.PARAMETER Username
		The username you'd like to send the DM to.
	#>
	[CmdletBinding(DefaultParameterSetName='None')]
	[OutputType('System.Management.Automation.PSCustomObject')]
	param (
		[Parameter(Mandatory)]
		[ValidateLength(1, 140)]
		[string]$Message,
		[Parameter(Mandatory,ParameterSetName='Username')]
		[string]$Username
	)
	
	process {
		$HttpEndPoint = 'https://api.twitter.com/1.1/direct_messages/new.json'
		
		$AuthorizationString = Get-OAuthAuthorization -DmMessage $Message -HttpEndPoint $HttpEndPoint -Username $Username -Verbose
		
		## Convert the message to a Byte array
		$Message = [System.Uri]::EscapeDataString($Message)
		$Username = [System.Uri]::EscapeDataString($Username)
		$Body = [System.Text.Encoding]::ASCII.GetBytes("text=$Message&screen_name=$Username");
		Write-Verbose "Using POST body '$Body'"
		Invoke-RestMethod -URI $HttpEndPoint -Method Post -Body $Body -Headers @{ 'Authorization' = $AuthorizationString } -ContentType "application/x-www-form-urlencoded"

	}
}