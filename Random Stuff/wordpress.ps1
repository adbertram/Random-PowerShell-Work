#requires -version 3

#http://www.verboon.info/2013/12/powershell-using-the-wordpress-rest-api/
#http://developer.wordpress.com/docs/api/
#http://developer.wordpress.com/docs/oauth2/

## requires the JSON API plugin

## To get a client id, redirect URI, and a client secret key
#https://developer.wordpress.com/wp-login.php?redirect_to=https%3A%2F%2Fdeveloper.wordpress.com%2Fapps%2F
# 1. Create an application with wordpress.com
# 2. Get client ID, client secret and redirect URL

$global:BlogUrl = 'www.adamtheautomator.com'
$global:WpApiUri = "https://public-api.wordpress.com/rest/v1/sites/$global:BlogUrl/posts"
$global:WpAuthorizeEndPoint = 'https://public-api.wordpress.com/oauth2/authorize'
$global:WpTokenEndpoint = 'https://public-api.wordpress.com/oauth2/token'
$global:WpComUserName = ''
$global:WpComPassword = ''
$global:WpBlogUserName = ''
$global:WpBlogPassword = ''

$oAuthTokens = @{
    'ClientID' = ''
    'CilentSecret' = ''
    'Code' = '' ## This need to be retrieved via manual authorization https://public-api.wordpress.com/oauth2/authorize/?client_id=35190&redirect_uri=http%3A%2F%2Fwww.adamtheautomator.com&response_type=code&blog=www.adamtheautomator.com
}



## Wordpress API Authentication Functions

Function Get-WpAccessToken() {
    #Access tokens are currently per blog per user for most of our endpoints. 
    #This means that you will need a separate access token for each blog that a 
    #user owns and that you want access to. There are certain endpoints like 
    #likes and follows where you can use a user’s token on any blog to act on their behalf.

    #“Token” should be used for client side applications. This is called “Implicit OAuth”. Tokens currently only last 2 weeks
    #and users will need to authenticate with your app once the token expires. Tokens are returned via the hash/fragment of the URL.

    $PostParams = @{
        'client_id' = $oAuthTokens['ClientID']
        'redirect_uri' = "http://$global:BlogUrl"
        'response_type' = 'token'
        'blog' = $global:BlogUrl
    }

    ## Get the inital username/password authorization page
    $a = Invoke-WebRequest -Uri $global:WpAuthorizeEndPoint -Body $PostParams -SessionVariable sb
    $login_form = $a.Forms[0]

    ## Provide Wordpress.com credentials to authorize app and retrieve the Authorization button
    $login_form.Fields['user_login'] = $global:WpComUserName
    $login_form.Fields['user_pass'] = [System.Web.HttpUtility]::UrlEncode($global:WpComPassword)
    $b = Invoke-WebRequest -Uri $login_form.Action -Body $login_form.Fields -Method Post -WebSession $sb
    $auth_form = $b.Forms[0]
    
    ## "Click" Authorize to authorize app and retrieve the blog username/password form
    $auth_form.Fields['user_login'] = $global:WpComUserName
    $auth_form.Fields['user_pass'] = [System.Web.HttpUtility]::UrlEncode($global:WpComPassword)
    $c = Invoke-WebRequest -Uri $auth_form.Action -Body $auth_form.Fields -WebSession $sb
    $blog_login_form = $c.Forms[0]
    
    ## Submit self-hosted blog username/password to get redirected and authenticated
    $blog_login_form.Fields['user_login'] = $global:WpBlogUserName
    $blog_login_form.Fields['user_pass'] = [System.Web.HttpUtility]::UrlEncode($global:WpBlogPassword)
    $z = Invoke-WebRequest -Uri $blog_login_form.Action  -Body $blog_login_form.Fields -WebSession $sb
    
    
    
    #$login_form2 = $z.Forms[0]
    #$login_form2.Fields['user_login'] = $global:WpBlogUserName
    #$login_form2.Fields['user_pass'] = $global:WpBlogPassword
    #$g = Invoke-WebRequest -Uri ' -Body $login_form2.Fields -Method Post -WebSession $sb

    ## Authorize this script to retrieve the access token
}






Function Get-WpPost($PostLimit = 50) {
    $posts = Invoke-RestMethod -uri "$global:WpApiUri/?number=$PostLimit"
    $posts.posts
}

Function New-WpPost() {
    $Url = "$global:WpApiUri/new"
    $Attribs = @{
        'title'= 'testtest'
        'status' = 'draft'
    }
    $x = Invoke-RestMethod -Uri $Url -Method Post -Body $Attribs -Headers @{'Authorization' = "BEARER FIo9SNBGZO"}
}

Invoke-RestMethod -Uri "$global:WpApiUri/new/?title=testtitle&status=draft" -Method Post -



$x = Invoke-WebRequest -Uri 'http://www.adamtheautomator.com/api/get_recent_posts/' | ConvertFrom-Json



## create post
$nonce = Invoke-WebRequest -Uri 'http://www.adamtheautomator.com/api/get_nonce' -Body @{'controller' = 'posts';'method' = 'create_post'} -Method Post | ConvertFrom-Json
$post = Invoke-WebRequest -Uri 'http://www.adamtheautomator.com/api/posts/create_post' -Body @{'title' = 'testing';'status' = 'draft';'author' = 'adam';'password' = 'xhOkngWcvqHAuPm56qd';'nonce' = $nonce} -Method Post | ConvertFrom-Json


## Login to your site
$postdata = @{
    'log' = 'adam'
    'pwd' = 'xhOkngWcvqHAuPm56qd'
    'wp-submit' = 'Log%In'
    'redirect_to' = 'http://www.adamtheautomator.com/wp-admin/'
    'testcookie' = '1'
}

$a = Invoke-WebRequest -Uri 'http://www.adamtheautomator.com/wp-login.php' -Method Post -Body $postdata -SessionVariable sv


$login_form = $a.Forms[0]
$login_form.Fields.user_login = 'adam'
$login_form.Fields.user_pass = 'xhOkngWcvqHAuPm56qd'
$r = Invoke-WebRequest -Uri $login_form.Action -Method Post -Body $login_form.Fields -WebSession $v