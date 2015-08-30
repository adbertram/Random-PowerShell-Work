#Requires -Version 3
#Requires -Module ConfigurationManager

<#
.SYNOPSIS
 	This creates a ConfigMgr package/program for each deployment type from the attributes of a ConfigMgr application.
.DESCRIPTION
	This reads a ConfigMgr application and gathers all needed attributes from the application itself and it's
	deployment types.  It then creates a package/program for each deployment type in the application. If more than one
	deployment type exists the resulting package(s) will be named $ApplicationName - $DeploymentTypeName" with each 
	program being named $DeploymentTypeName.
.NOTES
	Created on: 07/03/2014
	Created by: Adam Bertram
	Filename:   Convert-CMApplicationToPackage.ps1
	Credits: 	http://www.david-obrien.net/2014/01/24/convert-configmgr-applications-packages-powershell/
	Todos:		If the app has a product code, use this for installation program management in the program
				Create an option to distribute the package to DPs after creation
.DESCRIPTION
 	This gets all common attributes of a ConfigMgr application that a ConfigMgr package/program has and uses
	these attributes to create a new packages with a program inside for each application deployment type.
.EXAMPLE
    .\Convert-CMApplicationToPackage.ps1 -ApplicationName 'Application 1'
	This example converts the application "Application 1" into a package called "Application 1" and a program
	called "Install Application 1" if it has a single deployment type.
.EXAMPLE
     .\Convert-CMApplicationToPackage.ps1 -ApplicationName 'Application 1' -SkipRequirements
	This example converts the application "Application 1" into a package called "Application 1" and a program
	called Install "Application 1" excluding disk space and OS requirements if it has a single deployment type.
.PARAMETER ApplicationName
 	This is the name of the application you'd like to convert.
.PARAMETER PackageName
	This is the name of the package you'd like to create.  If this param isn't used and only 1 deployment type
	exists in the application, it will default to the name of the application else if the application has multiple
	deployment types it will default to the application name and the name of the deployment type.
.PARAMETER SkipRequirement
	Use this switch parameter if you don't want to bring over any disk or OS requirements from the application.
.PARAMETER DistributeContent
	Use this swtich to find all DPs/DP Groups the application is distributed to and distribute the package to them after
	the package has been created.
.PARAMETER OsdFriendlyPowershellSyntax
	Use this switch parameter to convert any program that's simply a reference to a PS1 file that normally works
	in a non-OSD environment to a full powershell syntax using powershell.exe.
.PARAMETER AdditionalOptions
	An array of hashtables of any additional options that will be applied to the resulting package.  Use the form
	@(@{'Package' = @{ 'Property' = 'Value' } }) or @(@{'Program' = @{ 'Property' = 'Value' } })
.PARAMETER SiteServerName
	The ConfigMgr site server name
.PARAMETER SiteCode
	The ConfigMgr site code.
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory,
			   ValueFromPipeline,
			   ValueFromPipelineByPropertyName)]
	[string]$ApplicationName,
	[string]$PackageName,
	[switch]$SkipRequirements,
	[switch]$DistributeContent,
	[switch]$OsdFriendlyPowershellSyntax,
	[array]$AdditionalOptions = @(@{'Package' = @{ 'PkgFlags' = '128' } }),
	[string]$SiteServer = 'CONFIGMANAGER',
	[string]$SiteCode = 'UHP'
)

begin {
	try {
		## This helper function gets all of the supported platform objects that's supported for creating OS requirements for a package,
		## looks for a match between each CI_UniqueID and the OS string and if there's a match, creates a new lazy property instance
		## populates the necessary values and returns an array of objects that can be used to populated the SupportOperatingSystemPlatforms
		## lazy WMI property on the SMS_Program object.
		function New-SupportedOsObject([Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Rule]$OsRequirement) {
			$SupportedPlatforms = Get-WmiObject -ComputerName $SiteServer -Class SMS_SupportedPlatforms -Namespace "root\sms\site_$SiteCode"
			$SupportedOs = @()
			## Define the array of OS strings to convert to objects
			if ($OsRequirement.Expression.Operator.OperatorName -eq 'OneOf') {
				$AppOsList = $OsRequirement.Expression.Operands.RuleId
			} elseif ($OsRequirement.Expression.Operator.OperatorName -eq 'NoneOf') {
				## TODO: Query the site server for all possible operating system values and remove all OSes in
				## $OsRequirement.DeploymentTypes[0].Requirements[0].Expression.Operands.RuleId
				return $false
			}
			foreach ($AppOs in $AppOsList) {
				foreach ($OsDetail in $SupportedPlatforms) {
					if ($AppOs -eq $OsDetail.CI_UniqueId) {
						$instance = ([wmiclass]("\\$SiteServer\root\sms\site_$SiteCode`:SMS_OS_Details")).CreateInstance()
						if ($instance -is [System.Management.ManagementBaseObject]) {
							$instance.MaxVersion = $OsDetail.OSMaxVersion
							$instance.MinVersion = $OsDetail.OSMinVersion
							$instance.Name = $OsDetail.OSName
							$instance.Platform = $OsDetail.OSPlatform
							$SupportedOs += $instance
						}
					}
				}
			}
			$SupportedOs
		}
		
		function Convert-NalPathToName ($NalPath) {
			$NalPath.Split('\\')[2].Split('.')[0]
		}
		
		function Get-DpsinDpGroup ($GroupId) {
			$Dps = Get-WmiObject @SiteServerWmiProps -Class SMS_DPGroupMembers -Filter "GroupID = '$GroupId'"
			if ($Dps) {
				$Dps.DPNALPath | foreach { Convert-NalPathToName $_ }
			} else {
				$false
			}
		}
		
		if (!(Test-Path "$(Split-Path $env:SMS_ADMIN_UI_PATH -Parent)\ConfigurationManager.psd1")) {
			throw 'Configuration Manager module not found.  Is the admin console intalled?'
		} elseif (!(Get-Module 'ConfigurationManager')) {
			Import-Module "$(Split-Path $env:SMS_ADMIN_UI_PATH -Parent)\ConfigurationManager.psd1"
		}
		$Location = (Get-Location).Path
		Set-Location "$($SiteCode):"
		
		$Application = Get-CMApplication -Name $ApplicationName
		if (!$Application) {
			throw "$ApplicationName not found"
		}
		$ApplicationXML = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::DeserializeFromString($Application.SDMPackageXML)
		
		$SetProgramProps = @{ }
		
		$SiteServerWmiProps = @{
			'Computername' = $SiteServer;
			'Namespace' = "root\sms\site_$SiteCode"
		}
		
	} catch {
		Write-Error $_.Exception.Message
		exit
	}
}
process {
	try {
		$DeploymentTypes = $ApplicationXML.DeploymentTypes
		
		for ($i = 0; $i -lt $DeploymentTypes.Count; $i++) {
			if ($DeploymentTypes.Count -gt 1) {
				$PackageName = "$ApplicationName - $($ApplicationXML.DeploymentTypes[$i].Title)"
			} elseif (!$PackageName) {
				$PackageName = $ApplicationName
			}
			$ProgramName = $ApplicationXML.DeploymentTypes[$i].Title
			
			if (Get-CMPackage -Name $PackageName) {
				throw "$PackageName already exists"
			}
			
			$PackageProps = @{
				'Name' = $PackageName;
				'Version' = $ApplicationXML.SoftwareVersion;
				'Manufacturer' = $ApplicationXML.Publisher;
				'Path' = $ApplicationXML.DeploymentTypes[$i].Installer.Contents.Location;
			}
			
			## 07/03/2014 - Even though the New-CMProgram documentation leads you to believe you can use a string for the RunType
			## param, it won't work.  You must use the [Microsoft.ConfigurationManagement.Cmdlets.AppModel.Commands.RunType] object.
			$NewProgramProps = @{
				'StandardProgramName' = $ProgramName;
				'PackageName' = $PackageName;
				'RunType' = [Microsoft.ConfigurationManagement.Cmdlets.AppModel.Commands.RunType]::($ApplicationXML.DeploymentTypes[$i].Installer.UserInteractionMode)
			}
			
			$AppCmdLine = $ApplicationXML.DeploymentTypes[$i].Installer.InstallCommandLine
			## If the command line is simply a reference to a single PS1 file
			if ($OsdFriendlyPowershellSyntax.IsPresent -and ($AppCmdLine -match '.ps1$')) {
				$NewProgramProps.CommandLine = "powershell.exe -ExecutionPolicy bypass -NoProfile -NoLogo -NonInteractive -File $AppCmdLine"
			} else {
				$NewProgramProps.CommandLine = $ApplicationXML.DeploymentTypes[$i].Installer.InstallCommandLine
			}
			
			$SetProgramProps = @{
				'EnableTaskSequence' = $true;
				'StandardProgramName' = $ProgramName;
				'Name' = $PackageName;
			}
			
			## 07/03/2014 - Due to a bug in the New-CMprogram cmdlet, even though 15 min or 720 min is allowed via the GUI
			## for the max run time, it doesn't work via the New-CMProgram cmdlet.  To compensate, I'm adding or removing
			## 1 minute and this works.
			$Duration = $ApplicationXML.DeploymentTypes[$i].Installer.MaxExecuteTime
			if ($Duration -eq 15) {
				$Duration = $Duration + 1
			} elseif ($Duration -eq 720) {
				$Duration = $Duration - 1
			}
			$NewProgramProps.Duration = $Duration
			
			if (!$SkipRequirements.IsPresent) {
				$Requirements = $ApplicationXML.DeploymentTypes[$i].Requirements
				$RequirementExpressions = $Requirements.Expression
				$FreeSpaceRequirement = $RequirementExpressions | where { ($_.Operands.LogicalName -contains 'FreeDiskSpace') -and ($_.Operator.OperatorName -eq 'GreaterEquals') }
				if ($FreeSpaceRequirement) {
					$NewProgramProps.DiskSpaceRequirement = $FreeSpaceRequirement.Operands.value / 1MB
					$NewProgramProps.DiskSpaceUnit = 'MB'
				}
			}
			
			switch ($ApplicationXML.DeploymentTypes[$i].Installer.RequiresLogon) {
				$false {
					$NewProgramProps.ProgramRunType = 'OnlyWhenNoUserIsLoggedOn'
				}
				$true {
					$NewProgramProps.ProgramRunType = 'OnlyWhenUserIsLoggedOn'
				}
				default {
					$NewProgramProps.ProgramRunType = 'WhetherOrNotUserIsLoggedOn'
				}
			}
			
			if ($ApplicationXML.DeploymentTypes[$i].Installer.UserInteractionMode -eq 'Hidden') {
				$SetProgramProps['SuppressProgramNotifications'] = $true
			}
			
			if ($ApplicationXML.DeploymentTypes[$i].Installer.SourceUpdateCode) {
				##TODO: Look into setting installation source management on the package
			}
			
			$PostIntallBehavior = $ApplicationXML.DeploymentTypes[$i].Installer.PostInstallBehavior
			if (($PostIntallBehavior -eq 'BasedOnExitCode') -or ($PostIntallBehavior -eq 'NoAction')) {
				$SetProgramProps.AfterRunningType = 'NoActionRequired'
			} elseif ($PostIntallBehavior -eq 'ProgramReboot') {
				$SetProgramProps.AfterRunningType = 'ProgramControlsRestart'
			} elseif ($PostIntallBehavior -eq 'ForceReboot') {
				$SetProgramProps.AfterRunningType = 'ConfigurationManagerRestartsComputer'
			}
			
			$NewPackage = New-CMPackage @PackageProps
			Write-Verbose "Successfully created package name $($NewPackage.Name) ($($NewPackage.PackageID))"
			$NewProgram = New-CMProgram @NewProgramProps
			Set-CMProgram @SetProgramProps
			
			if (!$SkipRequirements.IsPresent) {
				$OsRequirement = $Requirements | where { $_.Expression -is [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.OperatingSystemExpression] }
				if ($OsRequirement) {
					$SupportedOs = New-SupportedOsObject $OsRequirement
					$NewProgram.SupportedOperatingSystems = $SupportedOs
					$NewProgram.Put()
				}
			}
			
			if ($AdditionalOptions) {
				$AdditionalOptions | foreach {
					$_.GetEnumerator() | foreach {
						if ($_.Key -eq 'Package') {
							$_.Value.GetEnumerator() | foreach {
								$NewPackage.($_.Key) = $_.Value
								$NewPackage.Put()
							}
						} elseif ($_.Key -eq 'Program') {
							$_.Value.GetEnumerator() | foreach {
								$NewProgram.($_.Key) = $_.Value
								$NewProgram.Put()
							}
						}
					}
				}
			}
			
			if ($DistributeContent.IsPresent) {
				## Distribute the converted package to all DP groups the application is a part of
				$AllDpGroupPackages = Get-WmiObject @SiteServerWmiProps -Class SMS_DPGroupPackages
				$AllDpGroups = Get-WmiObject @SiteServerWmiProps -Class SMS_DistributionPointGroup
				
				## TODO: This currently doesn't support applications in multiple groups
				$AppDpGroupId = ($AllDpGroupPackages | where { $_.PkgID -eq $Application.PackageID } | Group-Object GroupId).Name
				$AppDpGroup = $AllDpGroups | where { $_.GroupID -eq $AppDpGroupId}
				if ($AppDpGroup) {
					Write-Verbose "Application is in a DP group"
					Start-CMContentDistribution -DistributionPointGroupName $AppDpGroup.Name -PackageName $PackageName
					$DpsInAppDpGroup = Get-DpsinDpGroup $AppDpGroupId
					$SingleDps = Get-WmiObject @SiteServerWmiProps -Class SMS_DistributionPoint -Filter "SecureObjectID = '$($Application.ModelName)'" | where { $DpsInAppDpGroup -notcontains (Convert-NalPathToName $_.ServerNALPath) }
				} else {
					$SingleDps = Get-WmiObject @SiteServerWmiProps -Class SMS_DistributionPoint -Filter "SecureObjectID = '$($Application.ModelName)'"
				}

				if ($SingleDps) {
					Write-Verbose "Application is in $($SingleDps.Count) single DPs"
					foreach ($Dp in $SingleDps) {
						$DpName = Convert-DpNalPathToName $Dp.ServerNALPath
						Write-Verbose "Adding package '$PackageName' to DP '$DpName'"
						Start-CMContentDistribution -DistributionPoint $DpName -PackageName $PackageName
					}
				}
			}
			Unlock-CMObject $NewPackage
		}
		
	} catch {
		Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
	}
}

end {
	Set-Location $Location
}