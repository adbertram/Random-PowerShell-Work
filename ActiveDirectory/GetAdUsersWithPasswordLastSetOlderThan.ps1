## Union (Get-ADUser -filter {enabled -eq $true} -Properties employeenumber,passwordlastset | ? {$_.Employeenumber -and ($_.PasswordLastSet -gt [DateTime]::Now.Subtract([TimeSpan]::FromDays(180)))}).Count
## UAP (Get-ADUser -filter {enabled -eq $true} -Properties employeenumber,passwordlastset | ? {$_.Employeenumber -and ($_.DistinguishedName -like '*AP&S*') -and ($_.PasswordLastSet -gt [DateTime]::Now.Subtract([TimeSpan]::FromDays(180)))}).Count

$MaxAge = 180

$rules = @(
    { $_.PasswordLastSet -lt [DateTime]::Now.Subtract([TimeSpan]::FromDays($MaxAge)) },
    { $_.LastLogonDate -lt [DateTime]::Now.Subtract([TimeSpan]::FromDays($MaxAge)) },
    { $_.Enabled -eq $false },
    { $_.PasswordExpired -eq $true }
)

Get-AdUser -Filter * -Properties PasswordLastSet,LastLogonDate