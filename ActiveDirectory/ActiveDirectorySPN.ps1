Set-StrictMode -Version Latest

#region function ConvertFrom-StringSpn
function ConvertFrom-StringSpn
{
	[CmdletBinding()]
	[OutputType([System.Management.Automation.PSCustomObject])]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$SpnString
	)
	
	try
	{
		foreach ($spn in $SpnString)
		{
			$output = @{
				ServiceClass = $null
				HostName = $null
				Port = $null
				ServiceName = $null
			}
			$dashSplit = $spn.Split('/')
			$output.ServiceClass = $dashSplit[0]
			
			## The SPN has a port
			if ($spn -match ':')
			{
				$output.Port = $spn.Split(':')[1].Split('/')[0]
			}
			
			## The SPN has a service name
			if ($spn -like '*/*/*')
			{
				$output.ServiceName = $dashSplit[$dashSplit.Length - 1]
			}
			$output.HostName = $spn.Split(':')[0].Split('/')[1]
			[pscustomobject]$output
		}
	}
	catch
	{
		Write-Error $_.Exception.Message
	}
}
#endregion function ConvertFrom-StringSpn

#region function New-SpnString
function New-SpnString
{
	[CmdletBinding()]
	[OutputType([string])]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ServiceClass,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$HostName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Port,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ServiceName
	)
	try
	{
		$spnString = "$ServiceClass/$HostName"
		if ($PSBoundParameters.ContainsKey('Port'))
		{
			$spnString += "`:$Port"
		}
		if ($PSBoundParameters.ContainsKey('ServiceName'))
		{
			$spnString += "/$ServiceName"
		}
		$spnString
	}
	catch
	{
		Write-Error $_.Exception.Message
	}
}
#endregion function New-SpnString

#region function Get-ADSpn
function Get-ADSpn
{
	[CmdletBinding()]
	[OutputType([System.Management.Automation.PSCustomObject])]
	param
	(
		[Parameter(Mandatory)]
		[ValidateSet('Computer', 'User')]
		[ValidateNotNullOrEmpty()]
		[string]$ObjectType,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ObjectValue,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$DomainName,
		
		[Parameter()]
		[pscredential]$Credential
	)

	$getFunction = 'Get-AD{0}' -f $ObjectType
	if (($ObjectType -eq 'Computer') -and (-not ($ObjectValue.EndsWith('$'))))
	{
		$ObjectValue = $ObjectValue + '$'
	}
	
	$getParams = @{
		Properties = @('CanonicalName', 'ServicePrincipalNames')
	}
	if ($PSBoundParameters.ContainsKey('ObjectValue'))
	{
		$getParams.Filter = "SamAccountName -eq '$ObjectValue'"
	}
	else
	{
		$getParams.Filter = "ServicePrincipalNames -like '*'"
	}
	if ($PSBoundParameters.ContainsKey('DomainName'))
	{
		$getParams.Server = $DomainName
	}
	if ($PSBoundParameters.ContainsKey('Credential'))
	{
		$getParams.Credential = $Credential
	}
	
	&$getFunction @getParams | Where-Object ServicePrincipalNames | ForEach-Object {
		
		$spnObjects = ConvertFrom-StringSpn $_.ServicePrincipalNames
		foreach ($spnObject in $spnObjects)
		{
			$addMemberParams = @{
				MemberType = 'NoteProperty'
			}
			$DomainName = $_.CanonicalName.Split('/')[0]
			$spnObject | Add-Member @addMemberParams -Name SamAccountName -Value $_.samAccountName
			$spnObject | Add-Member @addMemberParams -Name DomainName -Value $DomainName
			$spnObject
		}
		
	}
}
#endregion function Get-ADSpn

#region function New-ADSpn
function New-ADSpn
{
	[CmdletBinding()]
	[OutputType()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateSet('Computer', 'User')]
		[ValidateNotNullOrEmpty()]
		[string]$ObjectType,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$ObjectValue,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$ServiceClass,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$HostName,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$Port,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$ServiceName,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$DomainName,
		
		[Parameter()]
		[pscredential]$Credential
	)

	process
	{
		$getFunction = 'Get-AD{0}' -f $ObjectType
		$setFunction = 'Set-AD{0}' -f $ObjectType
		$testSpnParams = @{
			ServiceClass = $ServiceClass
			HostName = $HostName
		}
		if ($PSBoundParameters.ContainsKey('Port'))
		{
			$testSpnParams.Port = $Port
		}
		if ($PSBoundParameters.ContainsKey('ServiceName'))
		{
			$testSpnParams.ServiceName = $ServiceName
		}
		if ($PSBoundParameters.ContainsKey('DomainName'))
		{
			$testSpnParams.DomainName = $DomainName
		}
		if ($PSBoundParameters.ContainsKey('Credential'))
		{
			$testSpnParams.Credential = $Credential
		}
		$spnParams = @{ }
		$testSpnParams.GetEnumerator() | Where-Object Key -notin @('Credential', 'DomainName', 'ObjectType', 'ObjectValue') | ForEach-Object {
			$spnParams[$_.Key] = $_.Value
		}
		$spnString = New-SpnString @spnParams
		if (Test-ADSpn @testSpnParams)
		{
			throw "An existing SPN with string [$spnString] already exists"
		}
		
		$getParams = @{
			Identity = $ObjectValue
		}
		if ($PSBoundParameters.ContainsKey('DomainName'))
		{
			$getParams.Server = $DomainName
		}
		$account = &$getFunction @getParams
		if (-not $account)
		{
			throw "The [$ObjectType] account [$ObjectValue] was not found in Active Directory"
		}
		else
		{
			Write-Verbose -Message "Adding the SPN string of [$spnString] to [$ObjectType] account [$ObjectValue]"
			$setParams = @{
				Identity = $account
				ServicePrincipalNames = @{
					Add = $spnString
				}
			}
			if ($PSBoundParameters.ContainsKey('Credential'))
			{
				$setParams.Credential = $Credential
			}
			if ($PSBoundParameters.ContainsKey('DomainName'))
			{
				$setParams.Server = $DomainName
			}
			&$setFunction @setParams
		}
		
		if (-not (Test-ADSpn @testSpnParams))
		{
			throw "Failed to create SPN string [$spnString]"
		}
		else
		{
			Write-Verbose -Message "Successfully created SPN string [$spnString]"
		}
	}
}
#endregion function New-ADSpn

#region function Remove-ADSpn
function Remove-ADSpn
{
	[CmdletBinding()]
	[OutputType()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateSet('Computer', 'User')]
		[ValidateNotNullOrEmpty()]
		[string]$ObjectType,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ObjectValue,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ServiceClass,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$HostName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Port,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ServiceName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$DomainName,
		
		[Parameter()]
		[pscredential]$Credential
	)
	$getFunction = 'Get-AD{0}' -f $ObjectType
	$setFunction = 'Set-AD{0}' -f $ObjectType
	$testSpnParams = @{
		ServiceClass = $ServiceClass
		HostName = $HostName
	}
	if ($PSBoundParameters.ContainsKey('Port'))
	{
		$testSpnParams.Port = $Port
	}
	if ($PSBoundParameters.ContainsKey('ServiceName'))
	{
		$testSpnParams.ServiceName = $ServiceName
	}
	if ($PSBoundParameters.ContainsKey('DomainName'))
	{
		$testSpnParams.DomainName = $DomainName
	}
	if ($PSBoundParameters.ContainsKey('Credential'))
	{
		$testSpnParams.Credential = $Credential
	}
	if (Test-ADSpn @testSpnParams)
	{
		$spnString = "$ServiceClass/$HostName"
		if ($Port)
		{
			$spnString += "`:$Port"
		}
		if ($ServiceName)
		{
			$spnString += "/$ServiceName"
		}
		
		Write-Verbose -Message "Found an existing SPN string for $ObjectType account [$ObjectValue] matching SPN string [$spnString]"
		if (($ObjectType -eq 'Computer') -and (-not $ObjectValue.EndsWith('$')))
		{
			$samAccountName = "$ObjectValue{0}" -f '$'
		}
		else
		{
			$samAccountName = $ObjectValue
		}
		
		$getParams = @{
			Identity = $samAccountName
			Properties = 'ServicePrincipalNames'
		}
		if ($PSBoundParameters.ContainsKey('DomainName'))
		{
			$getParams.Server = $DomainName
		}
		if ($PSBoundParameters.ContainsKey('Credential'))
		{
			$getParams.Credential = $Credential
		}
		$account = &$getFunction @getParams
		
		$setParams = @{
			Identity = $samAccountName
			ServicePrincipalNames = @{
				Remove = $spnString
			}
		}
		if ($PSBoundParameters.ContainsKey('DomainName'))
		{
			$setParams.Server = $DomainName
		}
		if ($PSBoundParameters.ContainsKey('Credential'))
		{
			$setParams.Credential = $Credential
		}
		&$setFunction @setParams
		if (Test-ADSpn @testSpnParams)
		{
			throw "The SPN string [$spnString] was NOT successfully removed from [$ObjectType] account [$ObjectValue]"
		}
		else
		{
			Write-Verbose -Message "Successfully removed SPN [$spnString] from [$ObjectType] account [$ObjectValue]"
		}
	}
	else
	{
		Write-Verbose "The SPN string [$spnString] already does not exist for the [$ObjectType] account [$ObjectValue]"
	}
}
#endregion function Remove-ADSpn

#region function Test-ADSpn
function Test-ADSpn
{
	[CmdletBinding()]
	[OutputType([bool])]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ServiceClass,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$HostName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Port,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ServiceName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$DomainName,
		
		[Parameter()]
		[pscredential]$Credential
	)
	$spnParams = @{ }
	$PSBoundParameters.GetEnumerator() | Where-Object Key -notin @('Credential', 'DomainName') | ForEach-Object {
		$spnParams[$_.Key] = $_.Value
	}
	$spnString = New-SpnString @spnParams
	$adObjParams = @{
		LDAPFilter = 'servicePrincipalName=*'
		Properties = 'servicePrincipalName'
	}
	if ($PSBoundParameters.ContainsKey('DomainName'))
	{
		$adObjParams.Server = $DomainName
	}
	if ($PSBoundParameters.ContainsKey('Credential'))
	{
		$adObjParams.Credential = $Credential
	}
	if ((Get-ADObject @adObjParams).servicePrincipalName | Where-Object { $_ -eq $spnString })
	{
		$true
	}
	else
	{
		$false
	}
}
#endregion function Test-ADSpn

#region function Get-ADComputerSpn
function Get-ADComputerSpn
{
	[CmdletBinding()]
	[OutputType([System.Management.Automation.PSCustomObject])]
	param
	(
		[Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$DomainName,
		
		[Parameter()]
		[pscredential]$Credential
	)
	process
	{
		try
		{
			$params = @{
				ObjectType = 'Computer'
			}
			if ($PSBoundParameters.ContainsKey('ComputerName'))
			{
				$params.ObjectValue = $ComputerName
			}
			if ($PSBoundParameters.ContainsKey('DomainName'))
			{
				$params.DomainName = $DomainName
			}
			if ($PSBoundParameters.ContainsKey('Credential'))
			{
				$params.Credential = $Credential
			}
			Get-ADSpn @params | Select-Object *, @{ n = 'ComputerName'; e = { $_.SamAccountName.TrimEnd('$') } } -ExcludeProperty SamAccountName
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}
#endregion function Get-ADComputerSpn

#region function New-ADComputerSpn
function New-ADComputerSpn
{
	[CmdletBinding(SupportsShouldProcess)]
	[OutputType()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$ServiceClass,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$HostName,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$Port,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$ServiceName,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$DomainName,
		
		[Parameter()]
		[pscredential]$Credential
	)
	process
	{
		try
		{
			$params = @{
				ObjectType = 'Computer'
				ObjectValue = $ComputerName
				ServiceClass = $ServiceClass
				HostName = $HostName
			}
			if ($PSBoundParameters.ContainsKey('Port'))
			{
				$params.Port = $Port
			}
			if ($PSBoundParameters.ContainsKey('ServiceName'))
			{
				$params.ServiceName = $ServiceName
			}
			if ($PSBoundParameters.ContainsKey('DomainName'))
			{
				$params.DomainName = $DomainName
			}
			if ($PSBoundParameters.ContainsKey('Credential'))
			{
				$params.Credential = $Credential
			}
			if ($PSCmdlet.ShouldProcess($ComputerName, 'Create new SPN'))
			{
				New-ADSpn @params
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}
#endregion function New-ADComputerSpn

#region function Remove-ADComputerSpn
function Remove-ADComputerSpn
{
	[CmdletBinding()]
	[OutputType()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$ServiceClass,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$HostName,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$Port,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$ServiceName,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$DomainName,
		
		[Parameter()]
		[pscredential]$Credential
	)
	process
	{
		try
		{
			$removeSpnParams = @{
				ObjectType = 'Computer'
				ObjectValue = $ComputerName
				ServiceClass = $ServiceClass
				HostName = $HostName
			}
			if ($Port)
			{
				$removeSpnParams.Port = $Port
			}
			if ($ServiceName)
			{
				$removeSpnParams.ServiceName = $ServiceName
			}
			if ($DomainName)
			{
				$removeSpnParams.DomainName = $DomainName
			}
			if ($Credential)
			{
				$removeSpnParams.Credential = $Credential
			}
			if ($PSCmdlet.ShouldProcess($ComputerName, 'Remove SPN'))
			{
				Remove-ADSpn @removeSpnParams
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}
#endregion function Remove-ADComputerSpn

#region function Get-ADUserSpn
function Get-ADUserSpn
{
	[CmdletBinding()]
	[OutputType([System.Management.Automation.PSCustomObject])]
	param
	(
		[Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$UserName,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$DomainName,
		
		[Parameter()]
		[pscredential]$Credential
	)
	process
	{
		try
		{
			$params = @{
				ObjectType = 'User'
			}
			if ($PSBoundParameters.ContainsKey('UserName'))
			{
				$params.ObjectValue = $UserName
			}
			if ($PSBoundParameters.ContainsKey('DomainName'))
			{
				$params.DomainName = $DomainName
			}
			if ($PSBoundParameters.ContainsKey('Credential'))
			{
				$params.ObjectValue = $Credential
			}
			Get-ADSpn @params | Select-Object *, @{ n = 'UserName'; e = { $_.SamAccountName } } -ExcludeProperty samAccountName
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}
#endregion function Get-ADUserSpn

#region function New-ADUserSpn
function New-ADUserSpn
{
	[CmdletBinding(SupportsShouldProcess)]
	[OutputType()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$UserName,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$ServiceClass,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$HostName,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$Port,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$ServiceName,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$DomainName,
		
		[Parameter()]
		[pscredential]$Credential
	)
	process
	{
		try
		{
			$params = @{
				ObjectType = 'User'
				ObjectValue = $UserName
				ServiceClass = $ServiceClass
				HostName = $HostName
			}
			if ($PSBoundParameters.ContainsKey('Port'))
			{
				$params.Port = $Port
			}
			if ($PSBoundParameters.ContainsKey('ServiceName'))
			{
				$params.ServiceName = $ServiceName
			}
			if ($PSBoundParameters.ContainsKey('DomainName'))
			{
				$params.DomainName = $DomainName
			}
			if ($PSBoundParameters.ContainsKey('Credential'))
			{
				$params.Credential = $Credential
			}
			if ($PSCmdlet.ShouldProcess($UserName, 'Create new SPN'))
			{
				New-ADSpn @params
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}
#endregion function New-ADUserSpn

#region function Remove-ADUserSpn
function Remove-ADUserSpn
{
	[CmdletBinding()]
	[OutputType()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$UserName,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$ServiceClass,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$HostName,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[string]$Port,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[string]$ServiceName,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$DomainName,
		
		[Parameter()]
		[pscredential]$Credential
	)
	process
	{
		try
		{
			$removeSpnParams = @{
				ObjectType = 'User'
				ObjectValue = $UserName
				ServiceClass = $ServiceClass
				HostName = $HostName
			}
			if ($Port)
			{
				$removeSpnParams.Port = $Port
			}
			if ($ServiceName)
			{
				$removeSpnParams.ServiceName = $ServiceName
			}
			if ($DomainName)
			{
				$removeSpnParams.DomainName = $DomainName
			}
			if ($Credential)
			{
				$removeSpnParams.Credential = $Credential
			}
			if ($PSCmdlet.ShouldProcess($UserName, 'Remove SPN'))
			{
				Remove-ADSpn @removeSpnParams
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}
#endregion function Remove-ADUserSpn

Export-ModuleMember -Function '*ADComputerSpn'
Export-ModuleMember -Function '*ADUserSpn'
