Configuration PullMode {
    param (
        [string]$Computername,
        [string]$Guid
    )
    Node $Computername {
        LocalConfigurationManager {
            ConfigurationMode = 'ApplyOnly'
            ConfigurationID = $Guid
            RefreshMode = 'Pull'
            DownloadManagerName = 'WebDownloadManager’
            DownloadManagerCustomData = @{
                ServerUrl = 'http://LABDC.LAB.LOCAL:8080/PSDSCPullServer.svc'
                AllowUnsecureConnection = 'true'
            }
        }
    }
}

PullMode -Computername 'LABDC2.LAB2.LAB.LOCAL' –Guid 'f91e9587-8013-4714-99d5-8e4ffb2dc23f'
Set-DSCLocalConfigurationManager –Computer 'LABDC2.LAB2.LAB.LOCAL' -Path ./PullMode -Verbose