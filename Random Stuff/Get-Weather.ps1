#requires -Version 4

function Get-WeatherForecast
{
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\d{5}$')]
        [int]$ZipCode,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int]$DaysOut = 7
    )
    begin
    {
        $ErrorActionPreference = 'Stop'
    }
    process
    {
        try
        {
            $uri = 'http://www.weather.gov/forecasts/xml/DWMLgen/wsdl/ndfdXML.wsdl'
            $proxy = New-WebServiceProxy -uri $uri -namespace WebServiceProxy
            $latlon = $proxy.LatLonListZipCode($ZipCode)
            @($latlon).foreach({
                $l = $_
                $a = $l.dwml.latlonlist -split ','
                $lat = $a[0]
                $lon = $a[1]
                $now = get-date -UFormat %Y-%m-%d
                $format = 'Item24hourly'
                $weather = $Proxy.NDFDgenByDay($lat,$lon,$now,$DaysOut,$format)
                for ($i = 0 ; $i -le $DaysOut - 1; $i++) {
                    [pscustomobject]@{
                        “Date” = ((Get-Date).addDays($i)).tostring(“MM/dd/yyyy”) ;
                        “maxTemp” = $weather.dwml.data.parameters.temperature[0].value[$i] ;
                        “minTemp” = $weather.dwml.data.parameters.temperature[1].value[$i] ;
                        “Summary” = $weather.dwml.data.parameters.weather.”weather-conditions”[$i].”Weather-summary”
                    }
                }
            })
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}