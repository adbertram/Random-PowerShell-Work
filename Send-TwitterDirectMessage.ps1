$VerbosePreference = 'continue'

## Works with Twitter API v1.1
[Reflection.Assembly]::LoadWithPartialName("System.Security") | Out-Null
[Reflection.Assembly]::LoadWithPartialName("System.Net") | Out-Null

$status = [System.Uri]::EscapeDataString("test")
$oauth_consumer_key = "qE0WtEleJzp8ErWI82B3Jw8gl"
$oauth_consumer_secret = "r06813yKNEjaErJc4mkacWmFSNwnT1H05Yyjd8XQ5bOhKxVBVc"
$oauth_token = "19891458-D4dvUVxHpHMCiTppg7OF4kPKgQQXM2O8rhXMFiNVc"
$oauth_token_secret = "ZPLaltGH39jdYagotyQL5C9IYAKty6xovhBUcvPc5IYbr"
$oauth_nonce = [System.Convert]::ToBase64String(([System.Text.Encoding]::ASCII.GetBytes("$([System.DateTime]::Now.Ticks.ToString())12345"))).Replace('=','g')
Write-Verbose "Using oauth_nonce of $oauth_nonce"
$ts = [System.DateTime]::UtcNow - [System.DateTime]::ParseExact("01/01/1970", "dd/MM/yyyy", $null)
$oauth_timestamp = [System.Convert]::ToInt64($ts.TotalSeconds).ToString();
Write-Verbose "Oauth timestamp is $oauth_timestamp"

## Keys must be in alphabetical order
$signature = "POST&";
$signature += [System.Uri]::EscapeDataString("https://api.twitter.com/1.1/statuses/update.json") + "&"
$signature += [System.Uri]::EscapeDataString("oauth_consumer_key=" + $oauth_consumer_key + "&");
$signature += [System.Uri]::EscapeDataString("oauth_nonce=" + $oauth_nonce + "&");
$signature += [System.Uri]::EscapeDataString("oauth_signature_method=HMAC-SHA1&");
$signature += [System.Uri]::EscapeDataString("oauth_timestamp=" + $oauth_timestamp + "&");
$signature += [System.Uri]::EscapeDataString("oauth_token=" + $oauth_token + "&");
$signature += [System.Uri]::EscapeDataString("oauth_version=1.0&");
$signature += [System.Uri]::EscapeDataString("status=" + $status);
Write-Verbose "Unencrypted signature = $signature"

$signature_key = [System.Uri]::EscapeDataString($oauth_consumer_secret) + "&" + [System.Uri]::EscapeDataString($oauth_token_secret);

$hmacsha1 = new-object System.Security.Cryptography.HMACSHA1;
$hmacsha1.Key = [System.Text.Encoding]::ASCII.GetBytes($signature_key);
$oauth_signature = [System.Convert]::ToBase64String($hmacsha1.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($signature)));
Write-Verbose "Using the signature '$oauth_signature'"

$oauth_authorization = 'OAuth ';
$oauth_authorization += 'oauth_consumer_key="' + [System.Uri]::EscapeDataString($oauth_consumer_key) + '", ';
$oauth_authorization += 'oauth_nonce="' + [System.Uri]::EscapeDataString($oauth_nonce) + '", ';
$oauth_authorization += 'oauth_signature="' + [System.Uri]::EscapeDataString($oauth_signature) + '", ';
$oauth_authorization += 'oauth_signature_method="HMAC-SHA1",'
$oauth_authorization += 'oauth_timestamp="' + [System.Uri]::EscapeDataString($oauth_timestamp) + '", '
$oauth_authorization += 'oauth_token="' + [System.Uri]::EscapeDataString($oauth_token) + '", ';
$oauth_authorization += 'oauth_version="1.0"';
Write-Verbose "Authorization string is $oauth_authorization"

$post_body = [System.Text.Encoding]::ASCII.GetBytes("status=" + $status);

Invoke-RestMethod -URI 'https://api.twitter.com/1.1/statuses/update.json' -Method Post -Body $post_body -Headers @{ 'Authorization' = $oauth_authorization } -ContentType "application/x-www-form-urlencoded"

<#
[System.Net.HttpWebRequest] $request = [System.Net.WebRequest]::Create("https://api.twitter.com/1.1/statuses/update.json");
$request.Method = "POST";
$request.Headers.Add("Authorization", $oauth_authorization);
$request.ContentType = "application/x-www-form-urlencoded";
$body = $request.GetRequestStream();
$body.write($post_body, 0, $post_body.length);
$body.flush();
$body.close();
$response = $request.GetResponse();
#>