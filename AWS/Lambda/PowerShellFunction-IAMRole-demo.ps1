# Prepare the S3 Bucket
    $bucket = New-S3Bucket -BucketName "NameOfYourBucket"
    Add-S3PublicAccessBlock -BucketName $bucket.BucketName -PublicAccessBlockConfiguration_BlockPublicAcl $true -PublicAccessBlockConfiguration_BlockPublicPolicy $true -PublicAccessBlockConfiguration_IgnorePublicAcl $true -PublicAccessBlockConfiguration_RestrictPublicBucket $true
    Write-S3BucketVersioning -BucketName $bucket.BucketName -VersioningConfig_Status "Enabled"
    
    # Lambda Function Role
    $policy = @"
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "",
                "Effect": "Allow",
                "Principal": {
                    "Service": "lambda.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }
    "@
    $role = New-IAMRole -RoleName "ROLE-RoleManager" -AssumeRolePolicyDocument $policy
    $policy = @"
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "",
                "Effect": "Allow",
                "Action": "iam:*",
                "Resource": "*"
            }
        ]
    }
    "@
    Write-IAMRolePolicy -RoleName "ROLE-RoleManager" -PolicyDocument $policy -PolicyName "POLICY-ROLE-RoleManager"
    Register-IAMRolePolicy -RoleName "ROLE-RoleManager" -PolicyArn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    
    # Bucket Policy
    $policy = @"
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "AWS": [
                        "$($role.Arn)"
                    ]
                },
                "Action": [
                    "s3:*"
                ],
                "Resource": [
                    "arn:aws:s3:::$($bucket.BucketName)",
                    "arn:aws:s3:::$($bucket.BucketName)/*"
                ]
            }
        ]
    }
    "@
    Write-S3BucketPolicy -BucketName $($bucket.BucketName) -Policy $policy
    
    # Create the Lambda Function
    New-AWSPowerShellLambda -ScriptName FUNCTION-RoleManager-1 -Template Basic
    $function = @"
    `$objects = Get-S3Object -BucketName $($bucket.BucketName)
    foreach(`$object in `$objects)
    {
        `$firstSlash = `$object.Key.IndexOf("/")
        `$secondSlash = `$object.Key.IndexOf("/",`$firstSlash+1)-`$firstSlash-1
        `$entity = `$object.Key.Substring(0,`$firstSlash)
        `$roleName = `$object.Key.Substring(`$firstSlash+1,`$secondSlash)
        `$policyName = `$object.Key.Substring(`$firstSlash+`$secondSlash+2,`$object.Key.IndexOf(".")-`$firstSlash-`$secondSlash-2)
        if(`$entity -match "^[0-9]{12}$")
        {
            `$policy = @'
            {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Sid": "",
                        "Effect": "Allow",
                        "Principal": {
                            "AWS": "`$entity"
                        },
                        "Action": "sts:AssumeRole"
                    }
                ]
            }
            '@
            `$role = New-IAMRole -RoleName "`$roleName" -AssumeRolePolicyDocument `$policy
        }
        else
        {
            `$policy = @'
            {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Sid": "",
                        "Effect": "Allow",
                        "Principal": {
                            "Service": "`$entity.amazonaws.com"
                        },
                        "Action": "sts:AssumeRole"
                    }
                ]
            }
            '@
            `$role = New-IAMRole -RoleName "`$roleName" -AssumeRolePolicyDocument `$policy
        }
        if(`$policyName -eq "managed")
        {
            `$file = Invoke-WebRequest (Get-S3PreSignedURL -BucketName $($bucket.BucketName) -Expire (Get-Date).AddMinutes(1) -Protocol HTTP -Key "`$entity/`$roleName/`$policyName.json")
            `$json = [System.Text.Encoding]::ASCII.GetString(`$file.content)
            `$jsonObject = ConvertFrom-Json `$json
            foreach(`$arn in `$jsonObject.arn)
            {
                Register-IAMRolePolicy -RoleName "`$roleName" -PolicyArn "`$arn"
            }
        }
        else
        {
            `$file = Invoke-WebRequest (Get-S3PreSignedURL -BucketName $($bucket.BucketName) -Expire (Get-Date).AddMinutes(1) -Protocol HTTP -Key "`$entity/`$roleName/`$policyName.json")
            `$json = [System.Text.Encoding]::ASCII.GetString(`$file.content)
            Write-IAMRolePolicy -RoleName "`$roleName" -PolicyDocument `$json -PolicyName "`$policyName"
        }
    }
    "@
    Add-Content C:\FUNCTION-RoleManager-1\FUNCTION-RoleManager-1.ps1 -Value $function
    Publish-AWSPowerShellLambda -ScriptPath C:\FUNCTION-RoleManager-1\FUNCTION-RoleManager-1.ps1 -Name FUNCTION-RoleManager-1 -Region us-west-2 -IAMRoleArn $role.Arn
    
    # Configure the Trigger
    $lambda = Get-LMFunctionList|Where-Object{$_.Role -eq $role.Arn}
    $rule = Write-CWERule -Name "RULE-CronHourly" -ScheduleExpression "rate(1 hour)" -State ENABLED
    $target = New-Object Amazon.CloudWatchEvents.Model.Target
    $target.Arn = $lambda.FunctionArn
    $target.Id = $lambda.RevisionId
    Write-CWETarget -Rule $rule.Substring($rule.IndexOf("/")+1) -Target $target
    
    # Create a Test Role
    $policy = @"
    {
        "arn": [
            "arn:aws:iam::aws:policy/AdministratorAccess"
        ]
    }
    "@
    Write-S3Object -BucketName $bucket.BucketName -Key "$((Get-STSCallerIdentity).Account)/ROLE-Name/managed.json" -Content $policy
    $policy = @"
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "",
                "Effect": "Allow",
                "Action": "*",
                "Resource": "*"
            }
        ]
    }
    "@
    Write-S3Object -BucketName $bucket.BucketName -Key "$((Get-STSCallerIdentity).Account)/ROLE-Name/inline/POLICY-FullAdmin.json" -Content $policy
    
    # Test the Function
    Invoke-LMFunction -FunctionName $lambda.FunctionName
    Get-IAMRole -RoleName "ROLE-Name"
