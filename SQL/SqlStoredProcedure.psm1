#requires -Module SQLPS

function Get-SqlStoredProcedure
{
	[OutputType([Microsoft.SqlServer.Management.Smo.StoredProcedure])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ServerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Database,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential		
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

			$connectionString = New-SqlConnectionString -ServerName $ServerName -Database $Database -Credential $Credential
			$sqlConnection = New-SqlConnection -ConnectionString $connectionString

			$serverInstance = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $sqlConnection
			$serverInstance.Databases[$Database].StoredProcedures
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function New-SqlConnectionString
{
	[OutputType([string])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ServerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Database,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			#region Build the connection string. Doing this allows for easy addition or removal of attributes
			$connectionStringElements = [ordered]@{
				Server = "tcp:$ServerName,1433"
				'Initial Catalog' = $Database
				'Persist Security Info' = 'False'
			}
			if ($PSBoundParameters.ContainsKey('Credential'))
			{
				$connectionStringElements.'User ID' = $Credential.UserName
				$connectionStringElements.'Password' = $Credential.GetNetworkCredential().Password 
			}
			$connectionStringElements += @{
				'MultipleActiveResultSets' = 'False'
				'Encrypt' = 'True'
				'TrustServerCertificate' = 'False'
				'Connection Timeout' = '30'
			}

			$connectionString = ''
			@($connectionStringElements.GetEnumerator()).foreach({
				$connectionString += "$($_.Key)=$($_.Value);"
			})
			$connectionString
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function New-SqlConnection
{
	[OutputType([System.Data.SqlClient.SqlConnection])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ConnectionString	
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
			$SqlConnection.ConnectionString = $connectionString
			$SqlConnection
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function Invoke-SqlStoredProcedure
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ServerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Database,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$connectionString = New-SqlConnectionString -ServerName $ServerName -Database $Database -Credential $Credential
			$SqlConnection = New-SqlConnection -ConnectionString $connectionString

			$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
			$SqlCmd.CommandType=[System.Data.CommandType]’StoredProcedure’
			$SqlCmd.CommandText = $Name
			$SqlCmd.Connection = $SqlConnection
			$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
			$SqlAdapter.SelectCommand = $SqlCmd
			$DataSet = New-Object System.Data.DataSet
			$SqlAdapter.Fill($DataSet)
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}