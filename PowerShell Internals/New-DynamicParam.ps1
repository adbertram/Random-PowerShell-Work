function Set-Example {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[ValidateScript({ Test-Path -Path $_ })]
		[string]$Path,
		[Parameter(Mandatory)]
		[string]$Identity
	)
	DynamicParam {
		$ParamOptions = @(
		@{
			'Name' = 'Right';
			'Mandatory' = $true;
			'ValidateSetOptions' = ([System.Security.AccessControl.FileSystemRights]).DeclaredMembers | where { $_.IsStatic } | select -ExpandProperty name
		},
		@{
			'Name' = 'InheritanceFlags';
			'Mandatory' = $true;
			'ValidateSetOptions' = ([System.Security.AccessControl.InheritanceFlags]).DeclaredMembers | where { $_.IsStatic } | select -ExpandProperty name
		},
		@{
			'Name' = 'PropagationFlags';
			'Mandatory' = $true;
			'ValidateSetOptions' = ([System.Security.AccessControl.PropagationFlags]).DeclaredMembers | where { $_.IsStatic } | select -ExpandProperty name
		},
		@{
			'Name' = 'Type';
			'Mandatory' = $true;
			'ValidateSetOptions' = ([System.Security.AccessControl.AccessControlType]).DeclaredMembers | where { $_.IsStatic } | select -ExpandProperty name
		}
		)
		$RuntimeParamDic = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
		foreach ($Param in $ParamOptions) {
			$RuntimeParam = New-DynamicParameter @Param
			$RuntimeParamDic.Add($Param.Name, $RuntimeParam)
		}
		
		return $RuntimeParamDic
	}
	
	begin {
		$PsBoundParameters.GetEnumerator() | foreach { New-Variable -Name $_.Key -Value $_.Value -ea 'SilentlyContinue' }
	}
	
	process {
		try {
			$Acl = Get-Acl $Path
			#$Ar = New-Object System.Security.AccessControl.FileSystemAccessRule('Everyone', 'FullControl', 'ContainerInherit,ObjectInherit', 'NoPropagateInherit', 'Allow')
			$Ar = New-Object System.Security.AccessControl.FileSystemAccessRule($Identity, $Right, $InheritanceFlags, $PropagationFlags, $Type)
			$Acl.SetAccessRule($Ar)
			Set-Acl $Path $Acl
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function New-DynamicParameter
{
	[CmdletBinding()]
	[OutputType('System.Management.Automation.RuntimeDefinedParameter')]
	param (
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[type]$Type = [string],
		
		[ValidateNotNullOrEmpty()]
		[Parameter()]
		[array]$ValidateSetOptions,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$ValidateNotNullOrEmpty,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateCount(2, 2)]
		[int[]]$ValidateRange,
		
		[Parameter()]
		[switch]$Mandatory = $false,
		
		[Parameter()]
		[string]$ParameterSetName = '__AllParameterSets',
		
		[Parameter()]
		[switch]$ValueFromPipeline = $false,
		
		[Parameter()]
		[switch]$ValueFromPipelineByPropertyName = $false
	)
	
	$AttribColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
	$ParamAttrib = New-Object System.Management.Automation.ParameterAttribute
	$ParamAttrib.Mandatory = $Mandatory.IsPresent
	$ParamAttrib.ParameterSetName = $ParameterSetName
	$ParamAttrib.ValueFromPipeline = $ValueFromPipeline.IsPresent
	$ParamAttrib.ValueFromPipelineByPropertyName = $ValueFromPipelineByPropertyName.IsPresent
	$AttribColl.Add($ParamAttrib)
	if ($PSBoundParameters.ContainsKey('ValidateSetOptions'))
	{
		$AttribColl.Add((New-Object System.Management.Automation.ValidateSetAttribute($ValidateSetOptions)))
	}
	if ($PSBoundParameters.ContainsKey('ValidateRange'))
	{
		$AttribColl.Add((New-Object System.Management.Automation.ValidateRangeAttribute($ValidateRange)))
	}
	if ($ValidateNotNullOrEmpty.IsPresent)
	{
		$AttribColl.Add((New-Object System.Management.Automation.ValidateNotNullOrEmptyAttribute))
	}
	
	$RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter($Name, $Type, $AttribColl)
	$RuntimeParam
	
}