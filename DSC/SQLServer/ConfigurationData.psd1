@{
    AllNodes = @(
        @{
            NodeName = '*'
            PSDscAllowPlainTextPassword = $true
        },
        @{
            NodeName = 'localhost'
        }
    )
}