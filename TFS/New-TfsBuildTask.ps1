param(
   [Parameter(Mandatory=$true)][string]$FolderPath,
   [Parameter(Mandatory=$true)][string]$TfsUrl,
   [PSCredential]$Credential = (Get-Credential),
   [switch]$Overwrite = $false
)

param(
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[ValidateScript({ 
		if (-not (Test-Path -Path $_ -PathType Container)) {
			throw "The folder '$($_)' is not available"
		}
		if (-not (Test-Path -Path "$_\task.json" -PathType Leaf)) {
			throw "The file task.json was not found inside of folder '$_'"
		}
		$true
	
	})]
	[string]$FolderPath
)

function ZipFile {
	param($FolderPath)
	
}

# Load task definition from the JSON file
$taskDefinition = (Get-Content $FolderPath\task.json) -join "`n" | ConvertFrom-Json

# Zip the task content
Write-Verbose 'Zipping task content...'
$taskZipFilePath = ("{0}\..\{1}.zip" -f $FolderPath, $taskDefinition.id)
Remove-Item $taskZipFilePath -ErrorAction SilentlyContinue

Add-Type -AssemblyName "System.IO.Compression.FileSystem"
[IO.Compression.ZipFile]::CreateFromDirectory($taskFolder, $taskZipFilePath)

# Prepare to upload the task
Write-Verbose "Uploading task content"
$headers = @{ "Accept" = "application/json; api-version=2.0-preview"; "X-TFS-FedAuthRedirect" = "Suppress" }
$taskZipItem = Get-Item $taskZip
$headers.Add("Content-Range", "bytes 0-$($taskZipItem.Length - 1)/$($taskZipItem.Length)")
$url = ("{0}/_apis/distributedtask/tasks/{1}" -f $TfsUrl, $taskDefinition.id)
if ($Overwrite) {
   $url += "?overwrite=true"
}

# Actually upload it
Invoke-RestMethod -Uri $url -Credential $Credential -Headers $headers -ContentType application/octet-stream -Method Put -InFile $taskZipItem
