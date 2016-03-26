## Set a variable to give control over the script where to just find the users
## or find and also remove them.
$remove_users_found = $false

## Set today's date as a variable now since this will not change (today)
## If this were in the Where-Object scriptblock the Get-Date cmdlet would be executed
## once for every user object that's retrieved
$today_object = Get-Date

## Find the date in a string to write to the log
$today_string = get-date -Format 'MM-dd-yyyy hh:mm tt'

## Create the Where-Object scriptblock ahead of time.  This is done for easy reading
## The AD Filter is not used due to the complexity of the conditions
$unused_conditions_met = {
    ## Ensure no built-in AD user objects are removed inadvertantly
    !$_.isCriticalSystemObject -and
    ## The account is disabled (account cannot be used)
    (!$_.Enabled -or
    ## The password is expired (account cannot be used)
    $_.PasswordExpired -or
    ## The account has never been used
    !$_.LastLogonDate -or
    ## The account hasn't been used for 60 days
    ($_.LastLogonDate.AddDays(60) -lt $today_object))
}

## Query all Active Directory user accounts with all of the conditions we defined above
$unused_accounts = Get-ADUser -Filter * -Properties passwordexpired,lastlogondate,isCriticalSystemobject | Where-Object $unused_conditions_met |
    Select-Object @{Name='Username';Expression={$_.samAccountName}},
        @{Name='FirstName';Expression={$_.givenName}},
        @{Name='LastName';Expression={$_.surName}},
        @{Name='Enabled';Expression={$_.Enabled}},
        @{Name='PasswordExpired';Expression={$_.PasswordExpired}},
        @{Name='LastLoggedOnDaysAgo';Expression={if (!$_.LastLogonDate) { 'Never' } else { ($today_object - $_.LastLogonDate).Days}}},
        @{Name='Operation';Expression={'Found'}},
        @{Name='On';Expression={$today_string}}

## Create the log file of what the script found
$unused_accounts | Export-Csv -Path unused_user_accounts.csv -NoTypeInformation

## If set, remove all of the accounts found and append to the log
if ($remove_users_found) {
    foreach ($account in $unused_accounts) {
        Remove-ADUser $account.Username -Confirm:$false
        Add-Content -Value "$($account.UserName),,,,,,Removed,$today_string" -Path unused_user_accounts.csv
    }
}