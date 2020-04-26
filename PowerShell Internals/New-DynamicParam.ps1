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
			Name = 'Right'
			ParameterAttributes = @(
			@{
				Mandatory = $true
				# ParameterSetName = 'a'
				# Position = 0
				# ValueFromPipeline = $true
				# ValueFromPipelinyByPropertyName = $true
			}
			)
			ValidateSetOptions = ([System.Security.AccessControl.FileSystemRights]).DeclaredMembers | where { $_.IsStatic } | select -ExpandProperty name
		},
		@{
			Name = 'InheritanceFlags'
			ParameterAttributes = @(
			@{
				Mandatory = $true
			}
			)
			ValidateSetOptions = ([System.Security.AccessControl.InheritanceFlags]).DeclaredMembers | where { $_.IsStatic } | select -ExpandProperty name
		},
		@{
			Name = 'PropagationFlags'
			ParameterAttributes = @(
			@{
				Mandatory = $true
			}
			)
			ValidateSetOptions = ([System.Security.AccessControl.PropagationFlags]).DeclaredMembers | where { $_.IsStatic } | select -ExpandProperty name
		},
		@{
			Name = 'Type'
			ParameterAttributes = @(
			@{
				Mandatory = $true
			}
			)
			ValidateSetOptions = ([System.Security.AccessControl.AccessControlType]).DeclaredMembers | where { $_.IsStatic } | select -ExpandProperty name
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
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[array]$ValidateSetOptions,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$ValidateNotNullOrEmpty,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateCount(2, 2)]
		[int[]]$ValidateRange,
		
		[Parameter()]
		[Array] $ParameterAttributes
	)
	
	$AttribColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
	Foreach ( $ParameterAttribute in $ParameterAttributes ) {
		$ParamAttrib = New-Object System.Management.Automation.ParameterAttribute

		$ParamAttrib.Mandatory = $ParameterAttribute.Mandatory
		If ( $ParameterAttribute.Position ) { $ParamAttrib.Position = $ParameterAttribute.Position }
		If ( $ParameterAttribute.ParameterSetName ) { $ParamAttrib.ParameterSetName = $ParameterAttribute.ParameterSetName }
		$ParamAttrib.ValueFromPipeline = $ParameterAttribute.ValueFromPipeline
		$ParamAttrib.ValueFromPipelineByPropertyName = $ParameterAttribute.ValueFromPipelineByPropertyName

		$AttribColl.Add( $ParamAttrib )
	}
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
