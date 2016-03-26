Import-Module ActiveDirectory
try {
    $uap_docs = Import-Csv C:\scripts\All-Doc-2013-Password-Policy\all-docs-2013-password-policy.csv
    $ad_pw_ages = @();
    foreach ($user in $uap_docs) {
        $ad_pw_ages += Get-AdUser $user.Username -Properties passwordlastset | % {"$($_.Givenname) $($_.Surname), $($_.PasswordLastSet)`n"}
    }

    ## Email
    $oFrom = New-Object system.net.Mail.MailAddress 'adbertram@gmail.com','Adam Bertram';
    $oTo = New-Object system.net.Mail.MailAddress 'jdoe@email.com', 'John Doe'
    $oMsg = New-Object System.Net.Mail.MailMessage $oFrom, $oTo
    $oMsg.Subject = 'Daily Doc Password Changes'
    $oMsg.Body = "Here is the most recent list of docs and their password ages.`n`n$ad_pw_ages"
    $sSmtpServer = 'smtp.email.com';
    $oSmtpClient = new-object Net.Mail.SmtpClient($sSmtpServer);
	
	$oSmtpClient.Send($oMsg);
} catch [System.Exception] {
	return $_.Exception.Message;
}##endtry