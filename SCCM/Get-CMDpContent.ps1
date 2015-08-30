<#
.Synopsis
   Gets the Objects you specify distributed to a Distribution Point
.DESCRIPTION
   The Function queries the SMS_DistributionPoint to get a specific type of Objects being stored on a DistributionPoint.
   Then it processes each Object to get the Name of the Application, package etc being stored on the DP.
   Note for the Application Objects we use ModelName to filter instead of the PackageID as for SMS_Application WMI Class the property PackageID is lazy property
.EXAMPLE
  get-DPContent -DPname dexsccm  -ObjectType Application

    DP                                                     ObjectType                                             Application                                           
    --                                                     ----------                                             -----------                                           
    dexsccm                                                Application                                            7-Zip                                                 
    dexsccm                                                Application                                            PowerShell Community Extensions                       
    dexsccm                                                Application                                            {Quest Active Roles Managment Shell for AD, QuestAD}  
    dexsccm                                                Application                                            PowerShell Set PageFile                               
    dexsccm                                                Application                                            {NotePad++, NotePad++, NotePad++, NotePad++...}       

    Invoke the Function and ask only about the Applications distributed to the DP
.EXAMPLE
   Get-DPContent -DPname dexsccm

    DP                                        ObjectType                               Package                                  PackageID                               
    --                                        ----------                               -------                                  ---------                               
    dexsccm                                   Package                                  User State Migration Tool for Windows 8  DEX00001                                
    dexsccm                                   Package                                  Configuration Manager Client Package     DEX00002                                

    Invoke the Funtion and only ask for the Packages distributed to the DP
.LINK
    http://dexterposh.blogspot.com/2014/07/powershell-sccm-2012-get-dpcontent.html
.NOTES
    Author - DexterPOSH
    Inspired by - Adam Bertram's tweet ;)
#>
function Get-DPContent {
	[CmdletBinding()]
	[OutputType([PSObject[]])]
	Param
	(
		# Specify the Distribution Point Name
		[Parameter(Mandatory = $true,
				   ValueFromPipeline,
				   ValueFromPipelineByPropertyName)]
		[string[]]$DPname,
		
		#specfiy the ObjectType to get. Default is "Package"
		[Parameter()]
		[ValidateSet("Package", "Application", "ImagePackage", "BootImagePackage", "DriverPackage", "SoftwareUpdatePackage")]
		[string]$ObjectType = "Package",
		
		#specify the SCCMServer having SMS Namespace provider installed for the site. Default is the local machine.
		[Parameter(Mandatory = $false)]
		[Alias("SMSProvider")]
		[String]$SCCMServer = "dexsccm"
	)
	
	begin {
		Write-Verbose -Message "[BEGIN] Starting Function"
		#region open a CIM session
		$CIMSessionParams = @{
			ComputerName = $SCCMServer
			ErrorAction = 'Stop'
		}
		try {
			if ((Test-WSMan -ComputerName $SCCMServer -ErrorAction SilentlyContinue).ProductVersion -match 'Stack: 3.0') {
				Write-Verbose -Message "[BEGIN] WSMAN is responsive"
				$CimSession = New-CimSession @CIMSessionParams
				$CimProtocol = $CimSession.protocol
				Write-Verbose -Message "[BEGIN] [$CimProtocol] CIM SESSION - Opened"
			} else {
				Write-Verbose -Message "[PROCESS] Attempting to connect with protocol: DCOM"
				$CIMSessionParams.SessionOption = New-CimSessionOption -Protocol Dcom
				$CimSession = New-CimSession @CIMSessionParams
				$CimProtocol = $CimSession.protocol
				
				Write-Verbose -Message "[BEGIN] [$CimProtocol] CIM SESSION - Opened"
			}
			
			#endregion open a CIM session
			
			$sccmProvider = Get-CimInstance -query "select * from SMS_ProviderLocation where ProviderForLocalSite = true" -Namespace "root\sms" -CimSession $CimSession -ErrorAction Stop
			# Split up the namespace path
			$Splits = $sccmProvider.NamespacePath -split "\\", 4
			Write-Verbose "[BEGIN] Provider is located on $($sccmProvider.Machine) in namespace $($splits[3])"
			
			# Create a new hash to be passed on later
			$hash = @{ "CimSession" = $CimSession; "NameSpace" = $Splits[3]; "ErrorAction" = "Stop" }
			
			switch -exact ($ObjectType) {
				'Package' { $ObjectTypeID = 2; $ObjectClass = "SMS_Package"; break }
				'Application' { $ObjectTypeID = 31; $ObjectClass = "SMS_Application"; break }
				'ImagePackage' { $ObjectTypeID = 18; $ObjectClass = "SMS_ImagePackage"; break }
				'BootImagePackage' { $ObjectTypeID = 19; $ObjectClass = "SMS_BootImagePackage"; break }
				'DriverPackage' { $ObjectTypeID = 23; $ObjectClass = "SMS_DriverPackage"; break }
				'SoftwareUpdatePackage' { $ObjectTypeID = 24; $ObjectClass = "SMS_SoftwareUpdatesPackage"; break }
			}
		} catch {
			Write-Warning "[BEGIN] $SCCMServer needs to have SMS Namespace Installed"
			throw $Error[0].Exception
		}
	}
	
	process {
		foreach ($DP in $DPname) {
			Write-Verbose -Message "[PROCESS] Working with Distribution Point $DP"
			try {
				if ($ObjectType -eq "Application") {
					#for the SMS_Application Objects the PackagedID is a Lazy property so have to filter on the ModelName property
					$SecureObjectIDs = Get-CimInstance -query "Select SecureObjectID from SMS_DistributionPoint Where (ServerNALPath LIKE '%$DP%') AND (ObjectTypeID='$ObjectTypeID')" @hash | select -ExpandProperty SecureObjectId
					
					$SecureObjectIDs | foreach {
						if ($App = Get-CimInstance -query "Select LocalizedDisplayName,LocalizedDescription from $ObjectClass WHERE ModelName='$_'" @hash | select -Unique) {
							[pscustomobject]@{
								DP = $DP
								ObjectType = $ObjectType
								Application = $App.LocalizedDisplayName
								Description = $app.LocalizedDescription
							}
						}
					}
				} else {
					$PackageIDs = Get-CimInstance -query "Select SecureObjectID from SMS_DistributionPoint Where (ServerNALPath LIKE '%$DP%') AND (ObjectTypeID='$ObjectTypeID')" @hash | select -ExpandProperty SecureObjectID
					
					$PackageIDs | foreach {
						if ($Package = Get-CimInstance -query "Select Name from $ObjectClass WHERE PackageID='$_'" @hash) {
							[pscustomobject]@{
								DP = $DP
								ObjectType = $ObjectType
								Package = $Package.Name
								PackageID = $_
							}
						}
					}
				}
			} catch {
				Write-Warning "[PROCESS] Something went wrong while querying $SCCMServer for the DP or Object info"
				throw $_.Exception
			}
		}
	}
	end {
		Write-Verbose -Message "[END] Ending Function"
		Remove-CimSession -CimSession $CimSession
	}
}