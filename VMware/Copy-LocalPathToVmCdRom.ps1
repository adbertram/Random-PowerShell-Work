<#
.SYNOPSIS
	This creates an ISO file based on a specified path, uploads this ISO file to a VMware
	datastore and mounts the ISO file on a VM.
.NOTES
	Created on: 	7/14/2014
	Created by: 	Adam Bertram
	Filename:		Copy-LocalPathToVmCdRom.ps1
.EXAMPLE
	.\Copy-LocalPathToVmRdRom.ps1 -Folderpath c:\folder -Vm 'VM1' -DatatoreFolder 'VM1 Folder'

	This creates an ISO file from the contents of C:\folder, copies this ISO file to the
	'VM1 folder' datastore folder and mounts it to the VM 'VM1'
.PARAMETER FolderPath
	The folder path containing the files you'd like transfer to the VM
.PARAMETER Vm
	The name of the VMware virtual machine
.PARAMETER Datacenter
	The name of the Vcenter datacenter the VM is located on
.PARAMETER Datastore
	The name of the datastore the VM is located on
.PARAMETER DatastoreFolder
	The name of the datastore folder you'd like to put the ISO file into
.PARAMETER Force
	To remove any existing ISO on the datastore with the same name as the folder you're copying.
	Without this parameter, if an existing ISO is found, the action will fail.

#>
[CmdletBinding()]
param (
	[Parameter(Mandatory,
		ValueFromPipeline,
		ValueFromPipelineByPropertyName)]
	[ValidateScript({Test-Path $_ -PathType 'Container'})]
	[string]$FolderPath,
	[Parameter(Mandatory,
			   ValueFromPipeline,
			   ValueFromPipelineByPropertyName)]
	[string]$Vm,
	[Parameter(ValueFromPipelineByPropertyName)]
	[string]$Datacenter = 'Development',
	[Parameter(ValueFromPipelineByPropertyName)]
	[string]$Datastore = 'ruby02-localdatastore01',
	[Parameter(Mandatory,
			   ValueFromPipelineByPropertyName)]
	[string]$DatastoreFolder,
	[switch]$Force
)

begin {
	Set-StrictMode -Version Latest
	try {
		if (!(Get-PSSnapin 'VMware.VimAutomation.Core')) {
			throw 'PowerCLI snapin is not available'
		}
		$VmObject = Get-VM $Vm -ErrorAction SilentlyContinue
		if (!$VmObject) {
			throw "VM $Vm does not exist on connected VI server"
		}
		
		if ($VmObject.PowerState -ne 'PoweredOn') {
			throw "VM $Vm is not powered on. Cannot change CD-ROM IsoFilePath"
		}
		
		$ExistingCdRom = $VmObject | Get-CDDrive
		if (!$ExistingCdRom.ConnectionState.Connected) {
			throw 'No CD-ROM attached. VM is powered on so I cannot attach a new one'
		}
		
		$TempIsoName = "$($Folderpath | Split-Path -Leaf).iso"
		$DatastoreIsoFolderPath = "vmstore:\$DataCenter\$Datastore\$DatastoreFolder"
		if (Test-Path "$DatastoreIsoFolderPath\$TempIsoName") {
			if ($Force) {
				throw "-Force currently in progress.  ISO file $DatastoreIsoFolderPath\$TempIsoName already exists in datastore"
				## Remove current ISO CDROM from VM
				
				## Remove ISO from datastore folder
			} else {
				throw "ISO file $DatastoreIsoFolderPath\$TempIsoName already exists in datastore"
			}
		}
		
		## Hide the PowerCLI progres bars
		$ProgressPreference = 'SilentlyContinue'
		function New-IsoFile {
	  		<# 
		   .Synopsis 
		    Creates a new .iso file 
		   .Description 
		    The New-IsoFile cmdlet creates a new .iso file containing content from chosen folders 
		   .Example 
		    New-IsoFile "c:\tools","c:Downloads\utils" 
		    Description 
		    ----------- 
		    This command creates a .iso file in $env:temp folder (default location) that contains c:\tools and c:\downloads\utils folders. The folders themselves are added in the root of the .iso image. 
		   .Example 
		    dir c:\WinPE | New-IsoFile -Path c:\temp\WinPE.iso -BootFile etfsboot.com -Media DVDPLUSR -Title "WinPE" 
		    Description 
		    ----------- 
		    This command creates a bootable .iso file containing the content from c:\WinPE folder, but the folder itself isn't included. Boot file etfsboot.com can be found in Windows AIK. Refer to IMAPI_MEDIA_PHYSICAL_TYPE enumeration for possible media types: 
		 
		      http://msdn.microsoft.com/en-us/library/windows/desktop/aa366217(v=vs.85).aspx 
		   .Notes 
		    NAME:  New-IsoFile 
		    AUTHOR: Chris Wu 
		    LASTEDIT: 03/06/2012 14:06:16 
	 		#>
			Param (
				[parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]$Source,
				[parameter(Position = 1)][string]$Path = "$($env:temp)\" + (Get-Date).ToString("yyyyMMdd-HHmmss.ffff") + ".iso",
				[string] $BootFile = $null,
				[string] $Media = "Disk",
				[string] $Title = (Get-Date).ToString("yyyyMMdd-HHmmss.ffff"),
				[switch] $Force
			)#End Param
				
			Begin {
				($cp = new-object System.CodeDom.Compiler.CompilerParameters).CompilerOptions = "/unsafe"
				if (!("ISOFile" -as [type])) {
					Add-Type -CompilerParameters $cp -TypeDefinition @" 
						public class ISOFile 
						{ 
						    public unsafe static void Create(string Path, object Stream, int BlockSize, int TotalBlocks) 
						    { 
						        int bytes = 0; 
						        byte[] buf = new byte[BlockSize]; 
						        System.IntPtr ptr = (System.IntPtr)(&bytes); 
						        System.IO.FileStream o = System.IO.File.OpenWrite(Path); 
						        System.Runtime.InteropServices.ComTypes.IStream i = Stream as System.Runtime.InteropServices.ComTypes.IStream; 
						 
						        if (o == null) { return; } 
						        while (TotalBlocks-- > 0) { 
						            i.Read(buf, BlockSize, ptr); o.Write(buf, 0, bytes); 
						        } 
						        o.Flush(); o.Close(); 
						    } 
						} 
"@
				}#End If
					
				if ($BootFile -and (Test-Path $BootFile)) {
					($Stream = New-Object -ComObject ADODB.Stream).Open()
					$Stream.Type = 1  # adFileTypeBinary
					$Stream.LoadFromFile((Get-Item $BootFile).Fullname)
					($Boot = New-Object -ComObject IMAPI2FS.BootOptions).AssignBootImage($Stream)
				}#End If
				
				$MediaType = @{
					CDR = 2; CDRW = 3; DVDRAM = 5; DVDPLUSR = 6; DVDPLUSRW = 7; `
					DVDPLUSR_DUALLAYER = 8; DVDDASHR = 9; DVDDASHRW = 10; DVDDASHR_DUALLAYER = 11; `
					DISK = 12; DVDPLUSRW_DUALLAYER = 13; BDR = 18; BDRE = 19
				}
				
				if ($MediaType[$Media] -eq $null) { write-debug "Unsupported Media Type: $Media"; write-debug ("Choose one from: " + $MediaType.Keys); break }
				($Image = new-object -com IMAPI2FS.MsftFileSystemImage -Property @{ VolumeName = $Title }).ChooseImageDefaultsForMediaType($MediaType[$Media])
				
				if ((Test-Path $Path) -and (!$Force)) { "File Exists $Path"; break }
				New-Item -Path $Path -ItemType File -Force | Out-Null
				if (!(Test-Path $Path)) {
					"cannot create file $Path"
					break
				}
			}
			
			Process {
				switch ($Source) { { $_ -is [string] } { $Image.Root.AddTree((Get-Item $_).FullName, $true) | Out-Null; continue }
					{ $_ -is [IO.FileInfo] } { $Image.Root.AddTree($_.FullName, $true); continue }
					{ $_ -is [IO.DirectoryInfo] } { $Image.Root.AddTree($_.FullName, $true); continue }
				}#End switch
			}#End Process
			
			End {
				$Result = $Image.CreateResultImage()
				[ISOFile]::Create($Path, $Result.ImageStream, $Result.BlockSize, $Result.TotalBlocks)
			}#End End
		}#End function New-IsoFile
		
		
	} catch {
		Write-Error $_.Exception.Message
		exit
	}
}

process {
	try {
		## Create an ISO
		$IsoFilePath = "$($env:TEMP)\$TempIsoName"
		Get-ChildItem $FolderPath | New-IsoFile -Path $IsoFilePath -Title ($Folderpath | Split-Path -Leaf) -Force		
		## Upload the ISO to the datastore
		$Iso = Copy-DatastoreItem $IsoFilePath "vmstore:\$Datacenter\$Datastore\$DatastoreFolder" -PassThru
		## Attach the ISO to the VM
		$VmObject | Get-CDDrive | Set-CDDrive -IsoPath $Iso.DatastoreFullPath -Connected $true -Confirm:$false | Out-Null
		## Delete the temp ISO
		Remove-Item $IsoFilePath -Force
	} catch {
		Write-Error $_.Exception.Message	
	}
}