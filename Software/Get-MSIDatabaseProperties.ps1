<# 
    .SYNOPSIS
        This function retrieves properties from a Windows Installer MSI database. 
    .DESCRIPTION
        This function uses the WindowInstaller COM object to pull all values from the Property table from a MSI.
    .EXAMPLE
        Get-MsiDatabaseProperties 'MSI_PATH' 
    .PARAMETER FilePath
        The path to the MSI you'd like to query
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,
    ValueFromPipeline=$True,
    ValueFromPipelineByPropertyName=$True,
    HelpMessage='What is the path of the MSI you would like to query?')]
    [IO.FileInfo[]]$FilePath
)

begin {
    $com_object = New-Object -com WindowsInstaller.Installer
}

process {
    try {
        $database = $com_object.GetType().InvokeMember(
            "OpenDatabase",
            "InvokeMethod",
            $Null,
            $com_object,
            @($FilePath.FullName, 0)
        )

        $query = "SELECT * FROM Property"
        $View = $database.GetType().InvokeMember(
            "OpenView",
            "InvokeMethod",
            $Null,
            $database,
            ($query)
        )

        $View.GetType().InvokeMember("Execute", "InvokeMethod", $Null, $View, $Null)

        $record = $View.GetType().InvokeMember(
            "Fetch",
            "InvokeMethod",
            $Null,
            $View,
            $Null
        )

        $msi_props = @{}
        while ($record -ne $null) {
            $msi_props[$record.GetType().InvokeMember("StringData", "GetProperty", $Null, $record, 1)] = $record.GetType().InvokeMember("StringData", "GetProperty", $Null, $record, 2)
            $record = $View.GetType().InvokeMember(
                "Fetch",
                "InvokeMethod",
                $Null,
                $View,
                $Null
            )
        }

        $msi_props

        } catch {
            throw "Failed to get MSI file properties the error was: {0}." -f $_
        }
}
