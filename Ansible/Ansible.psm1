#requires -Module Posh-Ssh

## Ensure the appropriate paths are placed inside of /etc/ansible/ansibie.cfg

$BaseFolderPath = '~/ansibleinventory'
$Defaults = @{
    AnsibleControlServer = '192.168.1.5'
    PlaybookFolderPath   = "$BaseFolderPath/playbooks"
    CertStorePath        = 'Cert:\LocalMachine\my'
}

function New-SelfSignedCertificateEx {
    [CmdletBinding(DefaultParameterSetName = 'Store')]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [string]$Subject,

        [Parameter(Position = 1)]
        [DateTime]$NotBefore = [DateTime]::Now.AddDays(-1),

        [Parameter(Position = 2)]
        [DateTime]$NotAfter = $NotBefore.AddDays(365),

        [string]$SerialNumber,

        [Alias('CSP')]
        [string]$ProviderName = 'Microsoft Enhanced Cryptographic Provider v1.0',

        [string]$AlgorithmName = 'RSA',

        [int]$KeyLength = 2048,

        [ValidateSet('Exchange', 'Signature')]
        [string]$KeySpec = 'Exchange',

        [Alias('EKU')]
        [Security.Cryptography.Oid[]]$EnhancedKeyUsage,

        [Alias('KU')]
        [Security.Cryptography.X509Certificates.X509KeyUsageFlags]$KeyUsage,

        [Alias('SAN')]
        [String[]]$SubjectAlternativeName,

        [bool]$IsCA,

        [int]$PathLength = -1,

        [Security.Cryptography.X509Certificates.X509ExtensionCollection]$CustomExtension,

        [ValidateSet('MD5', 'SHA1', 'SHA256', 'SHA384', 'SHA512')]
        [string]$SignatureAlgorithm = 'SHA1',

        [string]$FriendlyName,

        [Parameter(ParameterSetName = 'Store')]
        [Security.Cryptography.X509Certificates.StoreLocation]$StoreLocation = 'CurrentUser',

        [Parameter(ParameterSetName = 'Store')]
        [Security.Cryptography.X509Certificates.StoreName]$StoreName = 'My',

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [Alias('OutFile', 'OutPath', 'Out')]
        [IO.FileInfo]$Path,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [Security.SecureString]$Password,

        [switch]$AllowSMIME,
		
        [switch]$Exportable,
		
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [switch]$PassThru
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop;

    # Ensure we are running on a supported platform.
    if ([Environment]::OSVersion.Version.Major -lt 6) {
        throw (New-Object NotSupportedException -ArgumentList 'Windows XP and Windows Server 2003 are not supported!');
    }

    #region Constants

    #region Contexts
    New-Variable -Name UserContext -Value 0x1 -Option Constant;
    New-Variable -Name MachineContext -Value 0x2 -Option Constant;
    #endregion Contexts

    #region Encoding
    New-Variable -Name Base64Header -Value 0x0 -Option Constant;
    New-Variable -Name Base64 -Value 0x1 -Option Constant;
    New-Variable -Name Binary -Value 0x3 -Option Constant;
    New-Variable -Name Base64RequestHeader -Value 0x4 -Option Constant;
    #endregion Encoding

    #region SANs
    New-Variable -Name OtherName -Value 0x1 -Option Constant;
    New-Variable -Name RFC822Name -Value 0x2 -Option Constant;
    New-Variable -Name DNSName -Value 0x3 -Option Constant;
    New-Variable -Name DirectoryName -Value 0x5 -Option Constant;
    New-Variable -Name URL -Value 0x7 -Option Constant;
    New-Variable -Name IPAddress -Value 0x8 -Option Constant;
    New-Variable -Name RegisteredID -Value 0x9 -Option Constant;
    New-Variable -Name Guid -Value 0xa -Option Constant;
    New-Variable -Name UPN -Value 0xb -Option Constant;
    #endregion SANs

    #region Installation options
    New-Variable -Name AllowNone -Value 0x0 -Option Constant;
    New-Variable -Name AllowNoOutstandingRequest -Value 0x1 -Option Constant;
    New-Variable -Name AllowUntrustedCertificate -Value 0x2 -Option Constant;
    New-Variable -Name AllowUntrustedRoot -Value 0x4 -Option Constant;
    #endregion Installation options

    #region PFX export options
    New-Variable -Name PFXExportEEOnly -Value 0x0 -Option Constant;
    New-Variable -Name PFXExportChainNoRoot -Value 0x1 -Option Constant;
    New-Variable -Name PFXExportChainWithRoot -Value 0x2 -Option Constant;
    #endregion PFX export options

    #endregion Constants

    #region Subject processing
    # http://msdn.microsoft.com/en-us/library/aa377051(VS.85).aspx
    $subjectDN = New-Object -ComObject X509Enrollment.CX500DistinguishedName;
    $subjectDN.Encode($Subject, 0x0);
    #endregion Subject processing

    #region Extensions

    # Array of extensions to add to the certificate.
    $extensionsToAdd = @();

    #region Enhanced Key Usages processing
    if ($EnhancedKeyUsage) {
        $oIDs = New-Object -ComObject X509Enrollment.CObjectIDs;
        $EnhancedKeyUsage | ForEach-Object {
            $oID = New-Object -ComObject X509Enrollment.CObjectID;
            $oID.InitializeFromValue($_.Value);

            # http://msdn.microsoft.com/en-us/library/aa376785(VS.85).aspx
            $oIDs.Add($oID);
        }

        # http://msdn.microsoft.com/en-us/library/aa378132(VS.85).aspx
        $eku = New-Object -ComObject X509Enrollment.CX509ExtensionEnhancedKeyUsage;
        $eku.InitializeEncode($oIDs);
        $extensionsToAdd += 'EKU';
    }
    #endregion Enhanced Key Usages processing

    #region Key Usages processing
    if ($KeyUsage -ne $null) {
        $ku = New-Object -ComObject X509Enrollment.CX509ExtensionKeyUsage;
        $ku.InitializeEncode([int]$KeyUsage);
        $ku.Critical = $true;
        $extensionsToAdd += 'KU';
    }
    #endregion Key Usages processing

    #region Basic Constraints processing
    if ($PSBoundParameters.Keys.Contains('IsCA')) {
        # http://msdn.microsoft.com/en-us/library/aa378108(v=vs.85).aspx
        $basicConstraints = New-Object -ComObject X509Enrollment.CX509ExtensionBasicConstraints;
        if (!$IsCA) {
            $PathLength = -1;
        }
        $basicConstraints.InitializeEncode($IsCA, $PathLength);
        $basicConstraints.Critical = $IsCA;
        $extensionsToAdd += 'BasicConstraints';
    }
    #endregion Basic Constraints processing

    #region SAN processing
    if ($SubjectAlternativeName) {
        $san = New-Object -ComObject X509Enrollment.CX509ExtensionAlternativeNames;
        $names = New-Object -ComObject X509Enrollment.CAlternativeNames;
        foreach ($altName in $SubjectAlternativeName) {
            $name = New-Object -ComObject X509Enrollment.CAlternativeName;
            if ($altName.Contains('@')) {
                $name.InitializeFromString($RFC822Name, $altName);
            } else {
                try {
                    $bytes = [Net.IPAddress]::Parse($altName).GetAddressBytes();
                    $name.InitializeFromRawData($IPAddress, $Base64, [Convert]::ToBase64String($bytes));
                } catch {
                    try {
                        $bytes = [Guid]::Parse($altName).ToByteArray();
                        $name.InitializeFromRawData($Guid, $Base64, [Convert]::ToBase64String($bytes));
                    } catch {
                        try {
                            $bytes = ([Security.Cryptography.X509Certificates.X500DistinguishedName]$altName).RawData;
                            $name.InitializeFromRawData($DirectoryName, $Base64, [Convert]::ToBase64String($bytes));
                        } catch {
                            $name.InitializeFromString($DNSName, $altName);
                        }
                    }
                }
            }
            $names.Add($name);
        }
        $san.InitializeEncode($names);
        $extensionsToAdd += 'SAN';
    }
    #endregion SAN processing

    #region Custom Extensions
    if ($CustomExtension) {
        $count = 0;
        foreach ($ext in $CustomExtension) {
            # http://msdn.microsoft.com/en-us/library/aa378077(v=vs.85).aspx
            $extension = New-Object -ComObject X509Enrollment.CX509Extension;
            $extensionOID = New-Object -ComObject X509Enrollment.CObjectId;
            $extensionOID.InitializeFromValue($ext.Oid.Value);
            $extensionValue = [Convert]::ToBase64String($ext.RawData);
            $extension.Initialize($extensionOID, $Base64, $extensionValue);
            $extension.Critical = $ext.Critical;
            New-Variable -Name ('ext' + $count) -Value $extension;
            $extensionsToAdd += ('ext' + $count);
            $count++;
        }
    }
    #endregion Custom Extensions

    #endregion Extensions

    #region Private Key
    # http://msdn.microsoft.com/en-us/library/aa378921(VS.85).aspx
    $privateKey = New-Object -ComObject X509Enrollment.CX509PrivateKey;
    $privateKey.ProviderName = $ProviderName;
    $algorithmID = New-Object -ComObject X509Enrollment.CObjectId;
    $algorithmID.InitializeFromValue(([Security.Cryptography.Oid]$AlgorithmName).Value);
    $privateKey.Algorithm = $algorithmID;

    # http://msdn.microsoft.com/en-us/library/aa379409(VS.85).aspx
    $privateKey.KeySpec = switch ($KeySpec) { 'Exchange' { 1 }; 'Signature' { 2 } }
    $privateKey.Length = $KeyLength;

    # Key will be stored in current user certificate store.
    switch ($PSCmdlet.ParameterSetName) {
        'Store' {
            $privateKey.MachineContext = if ($StoreLocation -eq 'LocalMachine') { $true } else { $false }
        }
        'File' {
            $privateKey.MachineContext = $false;
        }
    }

    $privateKey.ExportPolicy = if ($Exportable) { 1 } else { 0 }
    $privateKey.Create();
    #endregion Private Key

    #region Build certificate request template

    # http://msdn.microsoft.com/en-us/library/aa377124(VS.85).aspx
    $cert = New-Object -ComObject X509Enrollment.CX509CertificateRequestCertificate;

    # Initialize private key in the proper store.
    if ($privateKey.MachineContext) {
        $cert.InitializeFromPrivateKey($MachineContext, $privateKey, '');
    } else {
        $cert.InitializeFromPrivateKey($UserContext, $privateKey, '');
    }

    $cert.Subject = $subjectDN;
    $cert.Issuer = $cert.Subject;
    $cert.NotBefore = $NotBefore;
    $cert.NotAfter = $NotAfter;

    #region Add extensions to the certificate
    foreach ($item in $extensionsToAdd) {
        $cert.X509Extensions.Add((Get-Variable -Name $item -ValueOnly));
    }
    #endregion Add extensions to the certificate

    if (![string]::IsNullOrEmpty($SerialNumber)) {
        if ($SerialNumber -match '[^0-9a-fA-F]') {
            throw 'Invalid serial number specified.';
        }

        if ($SerialNumber.Length % 2) {
            $SerialNumber = '0' + $SerialNumber;
        }

        $bytes = $SerialNumber -split '(.{2})' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) }
        $byteString = [Convert]::ToBase64String($bytes);
        $cert.SerialNumber.InvokeSet($byteString, 1);
    }

    if ($AllowSMIME) {
        $cert.SmimeCapabilities = $true;
    }

    $signatureOID = New-Object -ComObject X509Enrollment.CObjectId;
    $signatureOID.InitializeFromValue(([Security.Cryptography.Oid]$SignatureAlgorithm).Value);
    $cert.SignatureInformation.HashAlgorithm = $signatureOID;
    #endregion Build certificate request template

    # Encode the certificate.
    $cert.Encode();

    #region Create certificate request and install certificate in the proper store
    # Interface: http://msdn.microsoft.com/en-us/library/aa377809(VS.85).aspx
    $request = New-Object -ComObject X509Enrollment.CX509enrollment;
    $request.InitializeFromRequest($cert);
    $request.CertificateFriendlyName = $FriendlyName;
    $endCert = $request.CreateRequest($Base64);
    $request.InstallResponse($AllowUntrustedCertificate, $endCert, $Base64, '');
    #endregion Create certificate request and install certificate in the proper store

    #region Export to PFX if specified
    if ($PSCmdlet.ParameterSetName.Equals('File')) {
        $PFXString = $request.CreatePFX(
            [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)),
            $PFXExportEEOnly,
            $Base64
        )
        Set-Content -Path $Path -Value ([Convert]::FromBase64String($PFXString)) -Encoding Byte;
    }
    #endregion Export to PFX if specified
	
    if ($PassThru.IsPresent) {
        @(Get-ChildItem -Path "Cert:\$StoreLocation\$StoreName").where( { $_.Subject -match $Subject })
    }

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Continue;
}
#endregion function New-SelfSignedCertificateEx

function Format-SshOutput {
    [OutputType([string])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [object]$InputObject
    )
    begin {
        $ErrorActionPreference = 'Stop'
    }
    process {
        try {
            if ($InputObject.ExitStatus -eq 0 -or ($InputObject.Output -notmatch '^ERROR:')) {
                $InputObject.Output
            } else {
                throw $InputObject.Error
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Connect-AnsibleControlServer {
    [OutputType([void])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [pscredential]$Credential,
		
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName = $Defaults.AnsibleControlServer
    )
    begin {
        $ErrorActionPreference = 'Stop'
    }
    process {
        try {
            if (-not ($sshSessions = Get-SSHSession -ComputerName $Defaults.AnsibleControlServer)) {
                $global:ansibleSession = New-SshSession -ComputerName $ComputerName -Credential $Credential
            } else {
                $global:ansibleSession = $sshSessions[0]
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Get-AnsiblePlaybook {
    [OutputType()]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    begin {
        $ErrorActionPreference = 'Stop'
    }
    process {
        try {
            if ($PSBoundParameters.ContainsKey('Name')) {
                $command = "tail -n +1 -- $($Defaults.PlaybookFolderPath)/$Name"
            } else {
                $command = "tail -n +1 -- $($Defaults.PlaybookFolderPath)/*"
            }
            Invoke-SSHCommand -Command $command -SSHSession $global:ansibleSession | Format-SshOutput	
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Invoke-AnsiblePlaybook {
    [OutputType()]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name
    )
    begin {
        $ErrorActionPreference = 'Stop'
    }
    process {
        try {
            Invoke-SSHCommand -Command "ansible-playbook $($Defaults.PlaybookFolderPath)/$Name" -SSHSession $global:ansibleSession | Format-SshOutput
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Invoke-AnsibleCommand {
    [OutputType([string])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$HostGroup,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int]$ConcurrentSessions = 5
    )
    begin {
        $ErrorActionPreference = 'Stop'
    }
    process {
        try {
            $params = @{
                SSHSession = $global:ansibleSession		
            }
            @($HostGroup).foreach( {
                    $command = "ansible $_ -a `"$($ScriptBlock.ToString())`" -f $ConcurrentSessions"
                    Write-Verbose -Message  "Initiating command: [$($command)] on control server..."
                    Invoke-SshCommand @params -Command $command | Format-SshOutput
                })
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function New-WinRmSslListener {
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^([\w-]+\.){2}\w+$')]
        [string]$ComputerName,
		
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [pscredential]$Credential
    )
    begin {
        $ErrorActionPreference = 'Stop'
    }
    process {
        try {
            $icmParams = @{
                ComputerName = $ComputerName
            }
            if ($PSBoundParameters.ContainsKey('Credential')) {
                $icmParams.Credential = $Credential
            }
			
            if (-not ($clientCert = Get-AnsibleNodeCertificate -NodeName $ComputerName)) {
                throw "Could not find a certificate for computer [$($ComputerName)]"	
            }
			
            Invoke-Command @icmParams -ScriptBlock {
                $newItemParams = @{
                    Path                  = 'WSMan:\LocalHost\Listener'
                    Address               = '*'
                    CertificateThumbprint = $using:clientCert.Thumbprint
                    Force                 = $true
                }
                New-Item @newItemParams
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function New-AnsibleNodeCertificate {
    [OutputType([System.IO.FileInfo])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^([\w-]+\.){2}\w+$')]
        [string]$NodeName,
		
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [switch]$PassThru,
		
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [pscredential]$Credential
    )
    begin {
        $ErrorActionPreference = 'Stop'
    }
    process {
        try {
            $icmParams = @{
                'ComputerName' = $NodeName
            }
            $certParams = @{
                'NodeName' = $NodeName
            }
            if ($PSBoundParameters.ContainsKey('Credential')) {
                $icmParams.Credential = $Credential
                $certParams.Credential = $Credential
            }
			
            if (-not ($cert = Get-AnsibleNodeCertificate @certParams)) {
                Write-Log -Source $MyInvocation.MyCommand -Message "Creating Ansible certificate on [$($NodeName)]"
                ## Use the local New-SelfSignedCertificateEx function to build the cert on the remote machine
                ## New-SelfSignedCertificate isn't extensive enough to do this and doing it on the remote machine
                ## prevents me from having to export out the private key and transfer the cert over
                Import-Module -Name (Get-Command -Name New-SelfSignedCertificateEx).ModuleName
                $functionDef = "function New-SelfSignedCertificateEx { ${function:New-SelfSignedCertificateEx}}"
				
                $icmParams.ScriptBlock = {
                    param ($functionDef)
					
                    . ([ScriptBlock]::Create($functionDef))
					
                    $signedCertParams = @{
                        'Subject'            = "CN=$Using:NodeName"
                        'SAN'                = $Using:NodeName
                        'EnhancedKeyUsage'   = 'Server Encryption'
                        'KeyUsage'           = 'KeyEncipherment', 'DataEncipherment'
                        'FriendlyName'       = 'Ansible Certificate'
                        'StoreLocation'      = 'LocalMachine'
                        'StoreName'          = 'My'
                        'ProviderName'       = 'Microsoft Enhanced Cryptographic Provider v1.0'
                        'KeyLength'          = 2048
                        'PassThru'           = $true
                        'AlgorithmName'      = 'RSA'
                        'SignatureAlgorithm' = 'SHA256'
                    }
					
                    New-SelfSignedCertificateEx @signedCertParams
                }
				
                $icmParams.ArgumentList = $functionDef
				
                if (-not (Invoke-Command @icmParams)) {
                    throw 'Failed to create self-signed cert.'
                }
            } else {
                Write-Log -Source $MyInvocation.MyCommand -Message "Ansible certificate already exists on [$($NodeName)]"
            }
			
            if ($PassThru.IsPresent) {
                Get-AnsibleNodeCertificate @certParams
            }
        } catch {
            Write-Log -Source $MyInvocation.MyCommand -EventId 1003 -EntryType 'Error' -Message ($_ | Resolve-Error)
        }
    }
    end {
        Write-Log -Source $MyInvocation.MyCommand -Message ('{0}: Exiting' -f $MyInvocation.MyCommand)
        $ErrorActionPreference = 'Continue'
    }
}

function Get-AnsibleNodeCertificate {
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^([\w-]+\.){2}\w+$')]
        [string]$NodeName = $Env:COMPUTERNAME,
		
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [pscredential]$Credential
    )
    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        Write-Log -Source $MyInvocation.MyCommand -Message "$($MyInvocation.MyCommand) : Entering"
        $ErrorActionPreference = 'Stop'
    }
    process {
        try {
            if (Test-LocalComputer -ComputerName $NodeName) {
                @(Get-ChildItem -Path $Defaults.CertStorePath).Where( { $_.EnhancedKeyUsageList -match 'Server Authentication' })
            } else {
                $icmParams = @{
                    'ComputerName' = $NodeName
                }
                if ($PSBoundParameters.ContainsKey('Credential')) {
                    $icmParams.Credential = $Credential
                }
				
                $icmParams.ScriptBlock = {
                    @(Get-ChildItem -Path $Using:Defaults.CertStorePath).Where( { $_.EnhancedKeyUsageList -match 'Server Authentication' })
                }
				
                Invoke-Command @icmParams
            }
        } catch {
            Write-Log -Source $MyInvocation.MyCommand -EventId 1003 -EntryType 'Error' -Message ($_ | Resolve-Error)
        }
    }
    end {
        Write-Log -Source $MyInvocation.MyCommand -Message ('{0}: Exiting' -f $MyInvocation.MyCommand)
        $ErrorActionPreference = 'Continue'
    }
}