#Requires -Version 3

<#
.SYNOPSIS
	This script checks a ConfigMgr site backup to ensure success and performs various post-backup functions that 
	back up other critical data that the built-in ConfigMgr site backup task does not.
.DESCRIPTION
	This script checks any previous backup attempt ran within the last hour of this script running for a
	a successful run if backup check is selected.  It assumes you also have SSRS installed on the site DB server 
	and backs up both SSRS databases, exports out the SSRS encryption keys, backs up the export file and the 
	entire ReportingServices folder on the server.  Once SSRS has been backed up, it then also copies the entire 
	SCCMContentLib folder, client install folder and the afterbackup.bat file to the destination backup folder path.  
	Once complete, it then attaches the log file it creates as part of the process and emails it out to the defined recipient.

	The script intends on creating 7 days worth of backups in a central location labeled Monday through Friday
	and places a copy of all backed up components in each day's folder.
.NOTES
	Created on: 	6/13/2014
	Created by: 	Adam Bertram
	Filename:		Start-PostConfigMgrBackupSteps.ps1
	Credits:		http://bit.ly/1i24NgC
	Requirements:	ConfigMgr, Reporting Point installed on the site DB server
	Todos:			Use the Sync framework to only copy deltas (http://bit.ly/1nh3FmP)
					Backup custom updates added via SCUP
					Verify copies were actually successful
					Retrieve more params automatically
.EXAMPLE
	.\Start-PostConfigMgrBackupSteps.ps1
	This example uses all default parameters for the script which will be the most likely way it is executed.
.PARAMETER SiteCode
	The ConfigMgr site code that the site server is a part of
.PARAMETER SiteDbServer
	The Configmgr site server that has the Reporting Services Point and the Site database server role installed.
.PARAMETER DestDbBackupFolderPath
	The UNC root folder path where the days' backup folders will be copied to
.PARAMETER SrcReportingServicesFolderPath
	The UNC folder path where you have installed reporting services to on the server.
.PARAMETER ReportingServicesDbBackupSqlFilePath
	The UNC file path to the SQL file that is dynamically created (if not exists) that the script passes to the 
	sqlcmd utility to kick off a backup of the SSRS databases.  This does not have to exist.  It is recommended
	to allow the script to create this.
.PARAMETER ReportingServicesEncKeyPassword
	The password that's set on the exported SSRS keys
.PARAMETER SrcContentLibraryFolderPath
	The folder path to ConfigMgr's content library on the site server.  This folder is called SCCMContentLib. The
	default path probably does not need to be changed.
.PARAMETER SrcClientInstallerFolderPath
	The folder path where the ConfigMgr client install is located on the site server.  This is backed up if you
	have any hotfixes being installed with your clients and may be located in here.
.PARAMETER SrcAfterBackupFilePath
	The file path where the afterbackup.bat file is located.  You should not have to change this from the default.
.PARAMETER LogFilesFolderPath
	The folder path where the script will create a log file for each day it runs.
.PARAMETER CheckBackup
	Use this switch to first check to ensure a recent backup was successful.  This parameter is recommended
	when running inside the afterbackup.bat file.
#>
[CmdletBinding()]
param (
	[string]$SiteCode = 'UHP',
    [ValidateScript({Test-Connection $_ -Quiet -Count 1})]
	[string]$SiteDbServer = 'CONFIGMANAGER',
	[ValidateScript({ Test-Path $_ -PathType 'Container' })]
	[string]$DestDbBackupFolderPath = '\\sanstoragea\lt_archive\30_Days\ConfigMgr',
	[ValidateScript({ Test-Path $_ -PathType 'Container' })]
	[string]$SrcReportingServicesFolderPath = "\\$SiteDbServer\f$\Sql2012Instance\MSRS11.MSSQLSERVER\Reporting Services",
	[string]$ReportingServicesDbBackupSqlFilePath = "\\$SiteDbServer\c$\ReportingServicesDbBackup.sql",
	[string]$ReportingServicesEncKeyPassword = 'my_password',
	[ValidateScript({ Test-Path $_ -PathType 'Container' })]
	[string]$SrcContentLibraryFolderPath = "\\$SiteDbServer\f$\SCCMContentLib",
	[ValidateScript({ Test-Path $_ -PathType 'Container' })]
	[string]$SrcClientInstallerFolderPath = "\\$SiteDbServer\c$\Program Files\Microsoft Configuration Manager\Client",
	[ValidateScript({ Test-Path $_ -PathType 'Leaf' })]
	[string]$SrcAfterBackupFilePath = "\\$SiteDbServer\c$\Program Files\Microsoft Configuration Manager\inboxes\smsbkup.box\afterbackup.bat",
	[string]$LogFilesFolderPath = "$DestDbBackupFolderPath\Logs",
	[switch]$CheckBackup
)

begin {
	Set-StrictMode -Version Latest
	try {
		## This function builds a SQL file called $ReportingServicesDbBackupSqlFile that backs up both
		## reporting services databases to a subfolder called ReportsBackup under today's
		## destination backup folder
		function New-ReportingServicesBackupSqlFile($TodayDbDestFolderPath) {
			Add-Content -Value "declare @path1 varchar(100);
			declare @path2 varchar(100);
			SET @path1 = '$TodayDbDestFolderPath\ReportsBackup\ReportServer.bak';
			SET @path2 = '$TodayDbDestFolderPath\ReportsBackup\ReportServerTempDB.bak';
			
			USE ReportServer;
			BACKUP DATABASE REPORTSERVER TO DISK = @path1;
			BACKUP DATABASE REPORTSERVERTEMPDB TO DISK = @path2;
			DBCC SHRINKFILE(ReportServer_log);
			USE ReportServerTempDb;
			DBCC SHRINKFILE(ReportServerTempDB_log);" -Path $ReportingServicesDbBackupSqlFilePath
		}
		
		function Convert-ToLocalFilePath($UncFilePath) {
			$Split = $UncFilePath.Split('\')
			$FileDrive = $Split[3].TrimEnd('$')
			$Filename = $Split[-1]
			$FolderPath = $Split[4..($Split.Length - 2)]
			if ($Split.count -eq 5) {
				"$FileDrive`:\$Filename"
			} else {
				"$FileDrive`:\$FolderPath\$Filename"
			}
		}
		
		Function Get-LocalTime($UTCTime) {
			$strCurrentTimeZone = (Get-WmiObject win32_timezone).StandardName
			$TZ = [System.TimeZoneInfo]::FindSystemTimeZoneById($strCurrentTimeZone)
			$LocalTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($UTCTime, $TZ)
			$LocalTime
		}
		
		if (!(Test-Path $LogFilesFolderPath)) {
			New-Item -Path $LogFilesFolderPath -Type Directory | Out-Null
		}
		$script:MyDate = Get-Date -Format 'MM-dd-yyyy'
		$script:LogFilePath = "$LogFilesFolderPath\$MyDate.log"
		
		## Simple logging function to create a log file in $LogFilesFolderPath named today's
		## date then write a timestamp and the message on each line and outputs the log file
		## path it wrote to
		function Write-Log($Message) {
			$MyDateTime = Get-Date -Format 'MM-dd-yyyy H:mm:ss'
			Add-Content -Path $script:LogFilePath -Value "$MyDateTime - $Message"
		}
		
		$DefaultBackupFolderPath = "$DestDbBackupFolderPath\$SiteCode" + 'Backup'
		if (!(Test-Path $DefaultBackupFolderPath)) {
			throw "Default backup folder path $DefaultBackupFolderPath does not exist"
		}
		
		if ($CheckBackup.IsPresent) {
			## Ensure the backup was successful before doing post-backup tasks
			
			## $DefaultBackupFolderPath is the path where the builtin Site Backup SQL maintenance task places the
			## backup. Ensure it has today's write time before going further because if not then the backup
			## didn't run successfully
			$BackupFolderLastWriteDate = (Get-ItemProperty $DefaultBackupFolderPath).Lastwritetime.Date
			
			$SuccessMessageId = 5035
			$OneHourAgo = (Get-Date).AddHours(-1)
			Write-Log "One hour ago detected as $OneHourAgo"
			
			$WmiParams = @{
				'ComputerName' = $SiteDbServer;
				'Namespace' = "root\sms\site_$SiteCode";
				'Class' = 'SMS_StatusMessage';
				'Filter' = "Component = 'SMS_SITE_BACKUP' AND MessageId = '$SuccessMessageId'"
			}
			$LastSuccessfulBackup = (Get-WmiObject @WmiParams | sort time -Descending | select -first 1 @{ n = 'DateTime'; e = { $_.ConvertToDateTime($_.Time) } }).DateTime
			$LastSuccessfulBackup = Get-LocalTime $LastSuccessfulBackup
			Write-Log "Last successful backup detected on $LastSuccessfulBackup"
			$IsBackupSuccessful = $LastSuccessfulBackup -gt $OneHourAgo
			
			if (($BackupFolderLastWriteDate -ne (get-date).date) -or !$IsBackupSuccessful) {
				throw 'The backup was not successful. Post-backup procedures not necessary'
			}
		}
		
		$CommonCopyFolderParams = @{
			'Recurse' = $true;
			'Force' = $true;
		}
		
	} catch {
		Write-Log "ERROR: $($_.Exception.Message)"
		exit (10)
	}
}

process {
	try {
		## If today's folder exists in the root of the backup folder path
		## remove it else create a new one
		$Today = (Get-Date).DayOfWeek
		$TodayDbDestFolderPath = "$DestDbBackupFolderPath\$Today"
		if ((Test-Path $TodayDbDestFolderPath -PathType 'Container')) {
			Remove-Item $TodayDbDestFolderPath -Force -Recurse
			Write-Log "Removed $TodayDbDestFolderPath..."
		}
		
		## Rename the default backup folder to today's day of the week
		Rename-Item $DefaultBackupFolderPath $Today
		## Create the folder to put the reporting services database backups in
		New-Item -Path "$TodayDbDestFolderPath\ReportsBackup" -ItemType Directory | Out-Null
		
		## if the SQL file that gets invoked to backup the SSRS databases isn't in the root of
		## C on the site server, build it.  The root of C isn't necessary.  It just needs to be
		## somewhere on the local server
		if (Test-Path $ReportingServicesDbBackupSqlFilePath) {
			Remove-Item $ReportingServicesDbBackupSqlFilePath -Force
		}
		New-ReportingServicesBackupSqlFile $TodayDbDestFolderPath
		Write-Log "Created new SQL file in $TodayDbDestFolderPath..."
		
		## Convert the UNC path specified for the SQL file into a local path to feed to
		## sqlcmd on the site server which backs up the SSRS databases.  Confirm success
		## afterwards.
		Write-Log "Backing up SSRS Databases..."
		$LocalPath = Convert-ToLocalFilePath $ReportingServicesDbBackupSqlFilePath
		$result = Invoke-Command -ComputerName $SiteDbServer -ScriptBlock { sqlcmd -i $using:LocalPath }
		if ($result[-1] -match 'DBCC execution completed') {
			Write-Log 'Successfully backed up SSRS databases'
		} else {
			Write-Log 'WARNING: Failed to backup SSRS databases'
		}
		
		## Export the SSRS Encryption keys to a local file via remoting on the site server and
		## copy that file to the backup location
		Write-Log "Exporting SSRS encryption keys..."
		$ExportFilePath = "\\$SiteDbServer\c$\rsdbkey.snk"
		$LocalPath = Convert-ToLocalFilePath $ExportFilePath
		$result = Invoke-Command -ComputerName $SiteDbServer -ScriptBlock { echo y | rskeymgmt -e -f $using:LocalPath -p $using:ReportingServicesEncKeyPassword }
		if ($result[-1] -ne 'The command completed successfully') {
			Write-Log 'WARNING: SSRS keys were not exported!'
		} else {
			Copy-Item $ExportFilePath $TodayDbDestFolderPath -Force
			Write-Log 'Successfully exported and backed up encryption keys.'
		}		
		
		## Backup the Reporting Services SSRS folder
		Write-Log "Backing up $SrcReportingServicesFolderPath..."
		Copy-Item @CommonCopyFolderParams -Path $SrcReportingServicesFolderPath -Destination "$TodayDbDestFolderPath\ReportsBackup"
		Write-Log "Successfully backed up the $SrcReportingServicesFolderPath folder.."
				
		## Backup the SCCMContentLib folder
		Write-Log "Backing up $SrcContentLibraryFolderPath..."
		Copy-Item @CommonCopyFolderParams -Path $SrcContentLibraryFolderPath -Destination $TodayDbDestFolderPath
		Write-Log "Successfully backed up the $SrcContentLibraryFolderPath folder.."
		
		## Backup the client install folder from the site server to the backup folder
		Write-Log "Backing up $SrcClientInstallerFolderPath..."
		Copy-Item @CommonCopyFolderParams -Path $SrcClientInstallerFolderPath -Destination $TodayDbDestFolderPath
		Write-Log "Successfully backed up the $SrcClientInstallerFolderPath folder.."
		
		##TODO: Backup any SCUP updates
		## On the computer that runs Updates Publisher, browse the Updates Publisher 2011 database file (Scupdb.sdf)
		## in %USERPROFILE%\AppData\Local\Microsoft\System Center Updates Publisher 2011\5.00.1727.0000\. There is
		## a different database file for each user that runs Updates Publisher 2011. Copy the database file to your
		## backup destination. For example, if your backup destination is E:\ConfigMgr_Backup, you could copy the
		## Updates Publisher 2011 database file to E:\ConfigMgr_Backup\SCUP2011.
		
		## Backup the afterbackup.bat file that kicks off this script
		Write-Log "Backing up $SrcAfterBackupFilePath.."
		Copy-Item @CommonCopyFolderParams -Path $SrcAfterBackupFilePath -Destination $TodayDbDestFolderPath
		Write-Log "Successfully backed up the $SrcAfterBackupFilePath file..."
		
	} catch {
		Write-Log "ERROR: $($_.Exception.Message)"
	}
}

end {
	Write-Log 'Emailing results of backup...'
	## Email me the results of the backup and post-backup tasks
	$Params = @{
		'From' =  'ConfigMgr Backup <abertram@domain.org>';
		'To' = 'Adam Bertram <adbertram@gmail.com>';
		'Subject' = 'ConfigMgr Backup';
		'Attachment' =  $script:LogFilePath;
		'SmtpServer' = 'smtp.domain.com'
	}
	
	Send-MailMessage @Params -Body 'ConfigMgr Backup Email'
}