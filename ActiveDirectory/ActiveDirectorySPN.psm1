Set-StrictMode -Version Latest

#region function ConvertFrom-StringSpn
function ConvertFrom-StringSpn
{
	<#
	.SYNOPSIS
		ConvertFrom-StringSpn takes a typical SPN string in the form serviceclass/host:port/servicename
		and parses out the service class, host, port and service name to create a single object
		with each SPN attribute as object properties.

	.DESCRIPTION
		A detailed description of the ConvertFrom-StringSpn function.

	.PARAMETER SpnString
		The SPN string that needs to be split into an object

	.EXAMPLE
		PS> ConvertFrom-StringSpn -SpnString 'serviceclass/host:389/servicename'

		This example parses out the string 'serviceclass/host:389/servicename' to create a single object
		with the properties 'serviceclass','host','port' and 'servicename'.

	.OUTPUTS
		System.Management.Automation.PSCustomObject. Convert-SpnStringToObject returns a PSCustomobject
		with a property representing each piece of that makes up the SPN string.

	.NOTES
		Created on:6/7/15
		Created by:Adam Bertram

	.INPUTS
		None. You cannot pipe objects to ConvertFrom-StringSpn.
	#>
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
	<#
	.SYNOPSIS
	New-SpnString is used to build SPN strings from object properties. SPN strings have been separated into
	their respective properties in this module to ease administration.  This functions converts object
	properties and concatenates them all into a single string.
	
	.DESCRIPTION
	A detailed description of the New-SpnString function.
	
	.PARAMETER ServiceClass
	The service class attribute that's contained inside the SPN string. This is a mandatory field
		because a SPN must have a service class attribute.

	.PARAMETER HostName
		The host name attribute that's contained inside the SPN string. This is a mandatory field
	because a SPN must have a host name attribute.
	
	.PARAMETER Port
	If a non-standard port is in the SPN string, specify that here. This is not usually specified in
	a SPN but is available if you need to match a SPN with a non-standard port.
	
	.PARAMETER ServiceName
	If a non-standard service name is in the SPN string to remove, specify that here. This is not usually
	specified in a SPN but is available if you need to match a SPN with a non-standard service name
	
	.EXAMPLE
	PS> New-SpnString -ServiceClass 'someserviceclass' -HostName 'somehost'
	
	This example concatenates the service class 'someserviceclass' and host name 'somehost' together to
	output 'someserviceclass/somehost'
	
	.OUTPUTS
	System.String. New-SpnString outputs a single SPN string.
	
	.NOTES
	Created on:6/7/15
	Created by:Adam Bertram
	
	.INPUTS
	None. You cannot pipe objects to New-SpnString.
	#>
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
	<#
	.SYNOPSIS
		The Get-ADSpn function will query the current Active Directory domain for all SPNs associated with
		a particular  object.

	.DESCRIPTION
		A detailed description of the Get-ADSpn function.

	.PARAMETER DomainName
		Specifies a fully qualified domain name (FQDN) for an Active Directory domain.

		Example format: -Domain "Domain01.Corp.Contoso.com"

	.PARAMETER ObjectType
		The kind of AD object that the SPN will be created under.  This can either be computer or user.

	.PARAMETER ObjectValue
		The value of the object type.

	.PARAMETER Credential
		A PSCredential object that will be used to perform the AD query. This is the credential that will be used
		for the Get-User cmdlet.

	.EXAMPLE
		PS> Get-ADSpn -ObjectType 'User' -UserName MYUser

		This example will query Active Directory for all SPNs attached to the user object with the SamAccountName
		'MYUser'.  When found, it will output one or more PS custom objects representing all the SPNs the user
		account possesses.

	.OUTPUTS
		System.Management.Automation.PSCustomObject. Get-ADSpn can return nothing, one or multiple objects depending
		on if it finds any.

	.NOTES
		Created on:6/7/15
		Created by:Adam Bertram

	.INPUTS
		None. Get-ADSpn does not accept pipeline input.
#>
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
	<#
	.SYNOPSIS
		The New-ADSpn function is designed to create new SPNs in Active Directory. New-ADSpn will
		first perform a test to see if the SPN is already in the domain. If not, it will then find the object in
		Active Directory. If found, it will then attempt to create the SPN.  After creation, New-ADSpn
		performs a test to ensure the SPN was successfully added.

		The New-ADSpn function is the function that both the New-ADUserSPn and New-ADComputerSpn function calls.

	.DESCRIPTION
		A detailed description of the New-ADSpn function.

	.PARAMETER ObjectType
		The type of AD object that the SPN will apply to.  This can either be 'Computer' or 'User'

	.PARAMETER ObjectValue
		The value of the object type.

	.PARAMETER ServiceClass
		The service class attribute that's contained inside the SPN string. This is a mandatory field
		because a SPN must have a service class attribute.

	.PARAMETER HostName
		The host name attribute that's contained inside the SPN string. This is a mandatory field
		because a SPN must have a host name attribute.

	.PARAMETER Port
		If a non-standard port is in the SPN string, specify that here. This is not usually specified in
		a SPN but is available if you need to match a SPN with a non-standard port.

	.PARAMETER ServiceName
		If a non-standard service name is in the SPN string to remove, specify that here. This is not usually
		specified in a SPN but is available if you need to match a SPN with a non-standard service name

	.PARAMETER DomainName
		Specifies a fully qualified domain name (FQDN) for an Active Directory domain.

		Example format: -Domain "Domain01.Corp.Contoso.com"

	.PARAMETER Credential
		A PSCredential object that will be used to perform the AD query. This is the credential that will be used
		for the Set-AdUser cmdlet.

	.EXAMPLE
		PS> New-ADSpn -ObjectType User -ObjectValue MyUsername -ServiceClass ldap -HostName 'SomeHost'

		This example will attempt to add a SPN to the 'MyUsername' user account with a service class
		attribute of 'ldap' and a hostname attribute of 'SomeHost'.

	.OUTPUTS
		Null. This function does not return any output if successful.

	.NOTES
		Created on:6/7/15
		Created by:Adam Bertram

	.INPUTS
		Any kind of objects can be piped to this function.  The function will match the UserName, ServiceClass,
		HostName, Port and ServiceName properties on the incoming object.
#>
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
		if ($PSBoundParameters.ContainsKey('Credential'))
		{
			$getParams.Credential = $Credential	
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
	<#
	.SYNOPSIS
		The Remove-ADSpn function is designed to remove SPNs from Active Directory objects. Remove-ADSpn will
		first find the object in Active Directory. If found, it will then find all SPNs associated with the object.
		If the specified SPN is found on the object it will attempt to remove the SPN.  After removal, Remove-ADSpn
		performs a test to ensure the SPN was removed.

	.DESCRIPTION
		A detailed description of the Remove-ADSpn function.

	.PARAMETER ObjectType
		The kind of AD object that the SPN will be created under.  This can either be computer or user.

	.PARAMETER ObjectValue
		The value of the object type.

	.PARAMETER ServiceClass
		The service class attribute that's contained inside the SPN string. This is a mandatory field
		because a SPN must have a service class attribute.

	.PARAMETER HostName
		The host name attribute that's contained inside the SPN string. This is a mandatory field
		because a SPN must have a host name attribute.

	.PARAMETER Port
		If a non-standard port is in the SPN string, specify that here. This is not usually specified in
		a SPN but is available if you need to match a SPN with a non-standard port.

	.PARAMETER ServiceName
		If a non-standard service name is in the SPN string to remove, specify that here. This is not usually
		specified in a SPN but is available if you need to match a SPN with a non-standard service name.

	.PARAMETER DomainName
		Specifies a fully qualified domain name (FQDN) for an Active Directory domain.

		Example format: -Domain "Domain01.Corp.Contoso.com"

	.PARAMETER Credential
		A PSCredential object that will be used to perform the AD query. This is the credential that will be used
		for the Set-AdUser cmdlet.

	.EXAMPLE
		PS> Remove-ADSpn -ObjectType User -ObjectValue MyUsername -ServiceClass ldap -HostName 'SomeHost'

		This example will attempt to remove all SPNs associated with the 'MyUsername' user account that have a service class
		attribute of 'ldap' and a hostname attribute of 'SomeHost'. If no SPN is found, the function will simply write
		verbose output letting the user know this and will exit.

	.OUTPUTS
		Null. This function does not return any output if successful.

	.NOTES
		Created on:6/7/15
		Created by:Adam Bertram

	.INPUTS
		Any kind of objects can be piped to this function.  The function will match the UserName, ServiceClass,
		HostName, Port and ServiceName properties on the incoming object.
#>
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
	<#
	.SYNOPSIS
		Test-ADSpn queries Active Directory and attempts to find existing SPN strings. If found, the function
		will return $true.  If not SPN string is found, it will return $false.

	.DESCRIPTION
		A detailed description of the Test-ADSpn function.

	.PARAMETER ServiceClass
		The service class attribute that's contained inside the SPN string. This is a mandatory field
		because a SPN must have a service class attribute.

	.PARAMETER HostName
		The host name attribute that's contained inside the SPN string. This is a mandatory field
		because a SPN must have a host name attribute.

	.PARAMETER Port
		If a non-standard port is in the SPN string, specify that here. This is not usually specified in
		a SPN but is available if you need to match a SPN with a non-standard port.

	.PARAMETER ServiceName
		If a non-standard service name is in the SPN string to remove, specify that here. This is not usually
		specified in a SPN but is available if you need to match a SPN with a non-standard service name

	.PARAMETER DomainName
		Specifies a fully qualified domain name (FQDN) for an Active Directory domain.

		Example format: -Domain "Domain01.Corp.Contoso.com"

	.PARAMETER Credential
		A description of the Credential parameter.

	.EXAMPLE
		PS> Test-ADSpn -ServiceClass 'someserviceclass' -HostName 'somehostname'

		This example queries Active Directory for SPN strings that contain a ServiceClass of 'someserviceclass' and
		a host name of 'somehostname'.  The SPN string that it will actually query is 'someserviceclass/somehostname'

	.OUTPUTS
		bool. Test-AdSpn outputs either boolean $true or $false

	.NOTES
		Created on:6/7/15
		Created by:Adam Bertram

	.INPUTS
		None. You cannot pipe objects to Test-AdSpn.
#>
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
	<#
	.SYNOPSIS
		The Get-ADComputerSpn function will query the current Active Directory domain for all SPNs associated with
		a particular computer object.

	.DESCRIPTION
		A detailed description of the Get-ADComputerSpn function.

	.PARAMETER ComputerName
		The samAccountName for the computer name that you'd like to query. If no ComputerName value is specified,
		the function will output all SPNs associated with all computer accounts in the domain.

	.PARAMETER Credential
		A PSCredential object that will be used to perform the AD query. This is the credential that will be used
		for the Get-Computer cmdlet.

	.PARAMETER DomainName
		Specifies a fully qualified domain name (FQDN) for an Active Directory domain.

		Example format: -Domain "Domain01.Corp.Contoso.com"

	.EXAMPLE
		PS> Get-ADComputerSpn -ComputerName MYPC

		This example will query Active Directory for all SPNs attached to the computer object with the SamAccountName
		'MYPC'.  When found, it will output one or more PS custom objects representing all the SPNs the computer
		account possesses.

	.OUTPUTS
		System.Management.Automation.PSCustomObject. Get-ADComputerSpn can return nothing, one or multiple objects depending
		on if it finds any.

	.NOTES
		Created on:6/7/15
		Created by:Adam Bertram

	.INPUTS
		Strings are meant to be piped to this function. Simple strings representing the ComputerName parameter
		can be piped to the function or objects with the ComputerName parameter.
#>
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
	<#
	.SYNOPSIS
		The New-ADComputerSpn function is designed to create new SPNs in Active Directory computer objects. New-ADComputerSpn will
		first perform a test to see if the SPN is already in the domain. If not, it will then find the computer object in
		Active Directory. If found, it will then attempt to create the SPN.  After creation, New-ADComputerSpn
		performs a test to ensure the SPN was successfully added.

	.DESCRIPTION
		A detailed description of the New-ADComputerSpn function.

	.PARAMETER ComputerName
		The Active Directory computer name in which a SPN will be attempted to be created against.

	.PARAMETER ServiceClass
		The service class attribute that's contained inside the SPN string. This is a mandatory field
		because a SPN must have a service class attribute.

	.PARAMETER HostName
		The host name attribute that's contained inside the SPN string. This is a mandatory field
		because a SPN must have a host name attribute.

	.PARAMETER Port
		If a non-standard port is in the SPN string, specify that here. This is not usually specified in
		a SPN but is available if you need to match a SPN with a non-standard port.

	.PARAMETER ServiceName
		If a non-standard service name is in the SPN string to remove, specify that here. This is not usually
		specified in a SPN but is available if you need to match a SPN with a non-standard service name.

	.PARAMETER DomainName
		Specifies a fully qualified domain name (FQDN) for an Active Directory domain.

		Example format: -Domain "Domain01.Corp.Contoso.com"

	.PARAMETER Credential
		A PSCredential object that will be used to perform the AD query. This is the credential that will be used
		for the Set-AdUser cmdlet.

	.EXAMPLE
		PS> New-ADComputerSpn -ComputerName Mycomputername -ServiceClass ldap -HostName 'SomeHost'

		This example will attempt to add a SPN to the 'Mycomputername' computer account with a service class
		attribute of 'ldap' and a hostname attribute of 'SomeHost'.

	.OUTPUTS
		Null. This function does not return any output if successful.

	.NOTES
		Created on:6/7/15
		Created by:Adam Bertram

	.INPUTS
		Any kind of objects can be piped to this function.  The function will match the ComputerName, ServiceClass,
		HostName, Port and ServiceName properties on the incoming object.
#>
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
	<#
	.SYNOPSIS
		The Remove-ADComputerSpn function is designed to remove SPNs from Active Directory computer objects. Remove-ADComputerSpn will
		first find the computer object in Active Directory. If found, it will then find all SPNs associated with the computer object.
		If the specified SPN is found on the computer object it will attempt to remove the SPN.  After removal, Remove-ADComputerSpn
		performs a test to ensure the SPN was removed.

	.DESCRIPTION
		A detailed description of the Remove-ADComputerSpn function.

	.PARAMETER ComputerName
		The Active Directory computer name in which a SPN will be attempted to be removed from.

	.PARAMETER ServiceClass
		The service class attribute that's contained inside the SPN string. This is a mandatory field
		because a SPN must have a service class attribute.

	.PARAMETER HostName
		The host name attribute that's contained inside the SPN string. This is a mandatory field
		because a SPN must have a host name attribute.

	.PARAMETER Port
		If a non-standard port is in the SPN string, specify that here. This is not usually specified in
		a SPN but is available if you need to match a SPN with a non-standard port.

	.PARAMETER ServiceName
		If a non-standard service name is in the SPN string to remove, specify that here. This is not usually
		specified in a SPN but is available if you need to match a SPN with a non-standard service name.

	.PARAMETER DomainName
		Specifies a fully qualified domain name (FQDN) for an Active Directory domain.

		Example format: -Domain "Domain01.Corp.Contoso.com"

	.PARAMETER Credential
		A PSCredential object that will be used to perform the AD query. This is the credential that will be used
		for the Set-AdUser cmdlet.

	.EXAMPLE
		PS> Remove-ADComputerSpn -ComputerName Mycomputername -ServiceClass ldap -HostName 'SomeHost'

		This example will attempt to remove all SPNs associated with the 'Mycomputername' computer account that have a service class
		attribute of 'ldap' and a hostname attribute of 'SomeHost'. If no SPN is found, the function will simply write
		verbose output letting the computer know this and will exit.

	.OUTPUTS
		Null. This function does not return any output if successful.

	.NOTES
		Created on:6/7/15
		Created by:Adam Bertram

	.INPUTS
		Any kind of objects can be piped to this function.  The function will match the ComputerName, ServiceClass,
		HostName, Port and ServiceName properties on the incoming object.
#>	
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
	<#
	.SYNOPSIS
		The Get-ADUserSpn function will query the current Active Directory domain for all SPNs associated with
		a particular user object.

	.DESCRIPTION
		A detailed description of the Get-ADUserSpn function.

	.PARAMETER Credential
		A PSCredential object that will be used to perform the AD query. This is the credential that will be used
		for the Get-User cmdlet.

	.PARAMETER DomainName
		Specifies a fully qualified domain name (FQDN) for an Active Directory domain.

		Example format: -Domain "Domain01.Corp.Contoso.com"

	.PARAMETER UserName
		The samAccountName for the username that you'd like to query. If no UserName value is specified,
		the function will output all SPNs associated with all user accounts in the domain.

	.EXAMPLE
		PS> Get-ADUserSpn -UserName MYUser

		This example will query Active Directory for all SPNs attached to the user object with the SamAccountName
		'MYUser'.  When found, it will output one or more PS custom objects representing all the SPNs the user
		account possesses.

	.OUTPUTS
		System.Management.Automation.PSCustomObject. Get-ADUserSpn can return nothing, one or multiple objects depending
		on if it finds any.

	.NOTES
		Created on:6/7/15
		Created by:Adam Bertram

	.INPUTS
		Strings are meant to be piped to this function. Simple strings representing the ComputerName parameter
		can be piped to the function or objects with the UserName parameter.
#>
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
				$params.Credential = $Credential
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
	<#
	.SYNOPSIS
		The New-ADUserSpn function is designed to create new SPNs in Active Directory user objects. New-ADUserSpn will
		first perform a test to see if the SPN is already in the domain. If not, it will then find the user object in
		Active Directory. If found, it will then attempt to create the SPN.  After creation, New-ADUserSpn
		performs a test to ensure the SPN was successfully added.

	.DESCRIPTION
		A detailed description of the New-ADUserSpn function.

	.PARAMETER UserName
		The Active Directory username in which a SPN will be attempted to be created against.

	.PARAMETER ServiceClass
		The service class attribute that's contained inside the SPN string. This is a mandatory field
		because a SPN must have a service class attribute.

	.PARAMETER HostName
		The host name attribute that's contained inside the SPN string. This is a mandatory field
		because a SPN must have a host name attribute.

	.PARAMETER Port
		If a non-standard port is in the SPN string, specify that here. This is not usually specified in
		a SPN but is available if you need to match a SPN with a non-standard port.

	.PARAMETER ServiceName
		If a non-standard service name is in the SPN string to remove, specify that here. This is not usually
		specified in a SPN but is available if you need to match a SPN with a non-standard service name

	.PARAMETER DomainName
		Specifies a fully qualified domain name (FQDN) for an Active Directory domain.

		Example format: -Domain "Domain01.Corp.Contoso.com"

	.PARAMETER Credential
		A PSCredential object that will be used to perform the AD query. This is the credential that will be used
		for the Set-AdUser cmdlet.

	.EXAMPLE
		PS> New-ADUserSpn -UserName MyUsername -ServiceClass ldap -HostName 'SomeHost'

		This example will attempt to add a SPN to the 'MyUsername' user account with a service class
		attribute of 'ldap' and a hostname attribute of 'SomeHost'.

	.OUTPUTS
		Null. This function does not return any output if successful.

	.NOTES
		Created on:6/7/15
		Created by:Adam Bertram

	.INPUTS
		Any kind of objects can be piped to this function.  The function will match the UserName, ServiceClass,
		HostName, Port and ServiceName properties on the incoming object.
#>
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
	<#
	.SYNOPSIS
		The Remove-ADUserSpn function is designed to remove SPNs from Active Directory user objects. Remove-ADUserSpn will
		first find the user object in Active Directory. If found, it will then find all SPNs associated with the user object.
		If the specified SPN is found on the user object it will attempt to remove the SPN.  After removal, Remove-ADUserSpn
		performs a test to ensure the SPN was removed.

	.DESCRIPTION
		A detailed description of the Remove-ADUserSpn function.

	.PARAMETER UserName
		The Active Directory username in which a SPN will be attempted to be removed from.

	.PARAMETER ServiceClass
		The service class attribute that's contained inside the SPN string. This is a mandatory field
		because a SPN must have a service class attribute.

	.PARAMETER HostName
		The host name attribute that's contained inside the SPN string. This is a mandatory field
		because a SPN must have a host name attribute.

	.PARAMETER Port
		If a non-standard port is in the SPN string, specify that here. This is not usually specified in
		a SPN but is available if you need to match a SPN with a non-standard port.

	.PARAMETER ServiceName
		If a non-standard service name is in the SPN string to remove, specify that here. This is not usually
		specified in a SPN but is available if you need to match a SPN with a non-standard service name.

	.PARAMETER DomainName
		Specifies a fully qualified domain name (FQDN) for an Active Directory domain.

		Example format: -Domain "Domain01.Corp.Contoso.com"

	.PARAMETER Credential
		A PSCredential object that will be used to perform the AD query. This is the credential that will be used
		for the Set-AdUser cmdlet.

	.EXAMPLE
		PS> Remove-AdUserSpn -UserName MyUsername -ServiceClass ldap -HostName 'SomeHost'

		This example will attempt to remove all SPNs associated with the 'MyUsername' user account that have a service class
		attribute of 'ldap' and a hostname attribute of 'SomeHost'. If no SPN is found, the function will simply write
		verbose output letting the user know this and will exit.

	.OUTPUTS
		Null. This function does not return any output if successful.

	.NOTES
		Created on:6/7/15
		Created by:Adam Bertram

	.INPUTS
		Any kind of objects can be piped to this function.  The function will match the UserName, ServiceClass,
		HostName, Port and ServiceName properties on the incoming object.
#>
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
