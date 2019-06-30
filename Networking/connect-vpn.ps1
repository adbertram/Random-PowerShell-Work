## One Time only. This is to securely store your VPN password to an encrypted text file
Read-Host -AsSecureString | ConvertFrom-SecureString | Out-File encrypted_password.txt

## The VPN profile name configured in your client
$vpn_profile = 'Profile name'
$username = 'username'

## Decrypt the password
$enc_password = (gc .\encrypted_password.txt | ConvertTo-SecureString)

## Create the credentials
$credentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $username,$enc_password $password = $credentials.GetNetworkCredential().Password

## Pass the appropriate arguments to the VPN client EXE
Set-Location 'C:\Program Files (x86)\Cisco Systems\VPN Client'
.\vpnclient.exe connect $vpn_profile user $username pwd $password

## Use this if you have a need to disconnect via script
#Set-Location 'C:\Program Files (x86)\Cisco Systems\VPN Client'
#.\vpnclient.exe disconnect

## RDP to a device. mstsc /v:HOSTNAME /multimon
