$RoomNumber = '407559'
$postUrl = "https://adambertram.campfirenow.com/room/$RoomNumber/speak.json"
$body = 'test message'
$token = '25f1733faf39d63ac8a860430fc18448df179b28'
 
$message = '<message><type>TextMessage</type><body>'+$body+'</body></message>'
$baseuri = $base_url + '/speak.xml'
$contentType = 'application/xml'
$headers = @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($token+": x"))}
Invoke-WebRequest -Uri $postUrl -Headers $headers -Method Post -body $message -contenttype 'application/xml'