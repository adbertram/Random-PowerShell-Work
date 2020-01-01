[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SeedScreenName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$NeverFollow = @('adbertram')
)
# $OAuthSettings = @{
#     ApiKey            = ''
#     ApiSecret         = ''
#     AccessToken       = ''
#     AccessTokenSecret = ''
# }
# Set-TwitterOAuthSettings @OAuthSettings

# #requires -Module PSTwitterApi

function Show-Countdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [int]$MaxWaitMin
    )

    $timer =  [system.diagnostics.stopwatch]::StartNew()
    do {
        $totalMinsWaited =  [math]::Round($timer.Elapsed.TotalMinutes, 0)
        Write-Host "$($MaxWaitMin - $totalMinsWaited)..." -NoNewline
        Start-Sleep -Seconds 60
    } while ($timer.Elapsed.TotalMinutes -lt $MaxWaitMin)

    $timer.Stop()
}

function Get-FriendlyApiErrorResponse {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.ErrorRecord]$ErrorResponse
    )
    if ($ErrorResponse.Exception.Message -match 'You are unable to follow more people at this time') {
        $ErrorResponse.Exception.Message
    } else {
        ($ErrorResponse.ErrorDetails.Message | ConvertFrom-Json).errors.message
    }
}

function Test-ApiRateLimitResponse {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ErrorResponse
    )

    $ErrorResponse -match '(Too many requests)|(Rate limit exceeded)'
}

function Get-TwitterFollowers {
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ScreenName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int]$RetryInterval = 15
    )

    do {
        try {
            $getFollowParams = @{
                ErrorAction = 'Stop'
                count       = 200
            }
            if ($PSBoundParameters.ContainsKey('ScreenName')) {
                $getFollowParams.screen_name = $ScreenName
            }
            if (Get-Variable -Name 'response' -ErrorAction 'Ignore') {
                $getFollowParams.cursor = $response.next_cursor
            }
            if ($response = Get-TwitterFollowers_List @getFollowParams) {
                Write-Verbose -Message "Get-TwitterFollowers: Retrieved $($response.users.Count) followers from user $ScreenName..."
                $response.users
                
            }
        } catch {
            $errResponse = Get-FriendlyApiErrorResponse -ErrorResponse $_
            if (Test-ApiRateLimitResponse -ErrorResponse $errResponse) {
                Write-Host "Hit API rate limit. Waiting $RetryInterval minutes..."
                Show-Countdown -MaxWaitMin $RetryInterval
            } else {
                throw $errResponse
            }
        }
    } while ($response.next_cursor)
}

function Get-MyTwitterFriends {
    ## Users I'm following
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int]$RetryInterval = 15 ## minutes
    )

    do {
        try {
            $getTwitterFriendsParams = @{
                count       = 200
                ErrorAction = 'Stop'
            }
            if (Get-Variable -Name 'response' -ErrorAction 'Ignore') {
                $getTwitterFriendsParams.cursor = $response.next_cursor
            }
            if ($response = Get-TwitterFriends_List @getTwitterFriendsParams) {
                Write-Verbose -Message "Retrieved $($response.users.Count) friends from API call..."
                $response.users
            }
        } catch {
            $errResponse = Get-FriendlyApiErrorResponse -ErrorResponse $_
            if (Test-ApiRateLimitResponse -ErrorResponse $errResponse) {
                Write-Host 'Hit API rate limit. Waiting...'
                Show-Countdown
            } else {
                throw $errResponse
            }
        }
    } while ($response.next_cursor)
}

function Follow-TwitterUser {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ScreenName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int]$RetryInterval = 15, ## minutes

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int]$MaxRetries = 5
    )

    $retriesPerformed = 0
    $success = $false
    do {
        try {
            $followParams = @{
                ErrorAction = 'Stop'
                screen_name = $ScreenName
            }
            Write-Verbose -Message "Attempting to follow screen name $ScreenName..."
            $response = Send-TwitterFriendships_Create @followParams
            Write-Verbose -Message 'Successfully followed user.'
            $success = $true
        } catch {
            $errResponse = Get-FriendlyApiErrorResponse -ErrorResponse $_
            if (Test-ApiRateLimitResponse -ErrorResponse $errResponse) {
                $retriesPerformed++
                if ($retriesPerformed -le $MaxRetries) {
                    Write-Host "Hit API rate limit. Waiting $RetryInterval minutes..."
                    Show-Countdown -MaxWaitMin $RetryInterval
                } else {
                    throw $errResponse
                }
            } else {
                throw $errResponse
            }
        }
    } while (-not $success)
}

$profileDescKeywords = @('sccm', 'powershell', 'geek', 'engineer', 'azure', 'cloud', 'devops', 'admin', 'mcp', 'microsoft', 'aws', ' IT ', 'SQL')

# $myExistingFollowerScreenNames = (Get-TwitterFollowers).users.screen_name

foreach ($user in $SeedScreenName) {
    try {
        ## filter unwanted users
        <#
            - following target screen name
            - is not protected
            - is not following me
            - I am not following them
            - they have a profile
            - does not have a default profile image
            - has at least one keyword in list in profile
            #>
        Get-TwitterFollowers -ScreenName $user -Verbose:$VerbosePreference | where {
            $desc = $_.description;
            -not $_.protected -and ## is not a protected account
            -not $_.following -and ## I am not following them already
            -not $_.followed_by -and ## They are not following me
            $_.description -and ## They have a profile
            $_.profile_image_url -notmatch 'default_profile_images' -and ## They don't have a default profilate image
            ($profileDescKeywords | ? { $desc -match $_ }) -and ## They have at least one interesting word in their profile
            $_.screen_name -notin $NeverFollow
        } | foreach {
            Follow-TwitterUser -ScreenName $_.screen_name -Verbose:$VerbosePreference
        }
    } catch {
        throw $_.Exception.Message
    }
}
Write-Verbose -Message 'Twitter following complete.'
