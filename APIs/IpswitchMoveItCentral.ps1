# Create a new instance of the MOVEit Central API
$obj = new-object -comObject MICentralAPICOM.MICentralAPI
# Display the members of the API object
# $obj | get-member
# Connect to localhost (assumes this script is running on the same box as Central and API
$obj.SetHost("localhost")
# Connect to a remote MOVEit Central using the locally installed CentralAPI
# $obj.SetHost("tperri-demo")
# $obj.SetUser("miadmin")
# $obj.SetPassword("miadmin")
$success = $obj.Connect()
if (!$success)
{
	Write-Host  $obj.GetErrorDescription()
	break
}

# OK, now let's do something trivial
Write-Host 'MOVEit Central API Version:' $obj.GetAPIVersion()
Write-Host 'MOVEit Central Version:' $obj.GetCentralVersion()

#OK, now let's do something less trivial
$taskXML = $obj.GetItemXML("Task", "Tamper Check", $TRUE)
Write-Host $taskXML