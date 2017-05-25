#requires -Version 5

Configuration SQLStandalone
{
    param(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[pscredential]$SetupCredential,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('sxs$')]
		[string]$WindowsServerSource,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$SqlServerInstallSource,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$SysAdminAccount
    )
    ## Download the xSQLServer module from the PowerShell Gallery
    Import-DscResource -Module xSQLServer

    ## Run this DSC configuration on the localhost (gathered from configuration data)
    Node $AllNodes.NodeName
    {
        ## Install a prerequisite Windows feature
        WindowsFeature "NET-Framework-Core"
        {
            Ensure = "Present"
            Name = "NET-Framework-Core"
            Source = $WindowsServerSource
        }

        ## Have DSC grab install bits from the SourcePath, install under the instance name with the features
        ## using the specified SQL Sys admin accounts. Be sure to install the Windows feature first.
        xSqlServerSetup 'SqlServerSetup'
        {
            DependsOn = "[WindowsFeature]NET-Framework-Core"
            SourcePath = $SqlServerInstallSource
            SetupCredential = $SetupCredential
            InstanceName = 'MSSQLSERVER'
            Features = 'SQLENGINE,FULLTEXT,RS,AS,IS'
            SQLSysAdminAccounts = $SysAdminAccount
        }

        ## Add firewall exceptions for SQL Server but run SQL server setup first.
        xSqlServerFirewall 'SqlFirewall'
        {
            DependsOn = '[xSqlServerSetup]SqlServerSetup'
            SourcePath = $SqlServerInstallSource
            InstanceName = 'MSSQLSERVER'
            Features = 'SQLENGINE,FULLTEXT,RS,AS,IS'
        }
    }
}

if (-not (Get-Module -Name xSqlServer -ListAvailable)) {
	Install-Module -Name 'xSqlServer' -Confirm:$false
}

SQLStandAlone -SetupCredential (Get-Credential) -WindowServerSource '' -SqlServerInstallSource '' -SysAdminAccount '' -ConfigurationData '.\ConfiguraitonData.psd1'
Start-DscConfiguration –Wait –Force –Path '.\SQLStandalone' –Verbose