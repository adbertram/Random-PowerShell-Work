param (
	[string]$DirectoryName,
	[int]$MaxFileCount
)

$API = New-Object -ComObject 'MOM.ScriptAPI'
$PropertyBag = $API.CreatePropertyBag()

try {
	$FileCount = (Get-ChildItem -Path $DirectoryName | Where-Object { !$_.PsIsContainer }).Count
	if ($FileCount -ge $MaxFileCount) {
		$PropertyBag.AddValue('State', 'Critical')
		$PropertyBag.Addvalue('Description', "There are $($FileCount - $MaxFileCount) more files than what should be in the directory $DirectoryName")
	} else {
		$PropertyBag.AddValue('State', 'Healthy')
		$PropertyBag.AddValue('Description', "There are less than $MaxFileCount files accumulated in the directory $DirectoryName")
	}
	$PropertyBag
} catch {
	$PropertyBag.AddValue('State', 'Warning')
	$PropertyBag.Addvalue('Description', $_.Exception.Message)
	$PropertyBag
}
