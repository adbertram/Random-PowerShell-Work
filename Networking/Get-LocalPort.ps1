#Requires -Version 3
<#
.SYNOPSIS
	This parses the native netstat.exe's output using the command line "netstat -anb" to find
    all of the network ports in use on a local machine and all associated processes and services
.NOTES
	Created on: 	2/15/2015
	Created by: 	Adam Bertram
	Filename:		Get-LocalPort.ps1
.EXAMPLE
    PS> Get-LocalPort.ps1

    This example will find all network ports in uses on the local computer with associated
    processes and services

.EXAMPLE
    PS> Get-LocalPort.ps1 | Where-Object {$_.ProcessOwner -eq 'svchost.exe'}

    This example will find all network ports in use on the local computer that were opened
    by the svchost.exe process.

.EXAMPLE
    PS> Get-LocalPort.ps1 | Where-Object {$_.IPVersion -eq 'IPv4'}

    This example will find all network ports in use on the local computer using IPv4 only.
#>
[CmdletBinding()]
param ()

begin {
	Set-StrictMode -Version Latest
	$ErrorActionPreference = 'Stop'
}

process {
	try {
        ## Capture the output of the native netstat.exe utility
        ## Remove the top row from the result and trim off any leading or trailing spaces from each line
        ## Replace all instances of more than 1 space with a pipe symbol.  This allows easier parsing of
        ## the fields
	    $Netstat = (netstat -anb | where {$_ -and ($_ -ne 'Active Connections')}).Trim() | Select-Object -Skip 1 | foreach {$_ -replace '\s{2,}','|'}

        $i = 0
        foreach ($Line in $Netstat) { 
            ## Create the hashtable to conver to object later
            $Out = @{
                'Protocol' = ''
                'State' = ''
                'IPVersion' = ''
                'LocalAddress' = ''
                'LocalPort' = ''
                'RemoteAddress' = ''
                'RemotePort' = ''
                'ProcessOwner' = ''
                'Service' = ''
            }
            ## If the line is a port
            if ($Line -cmatch '^[A-Z]{3}\|') {
                $Cols = $Line.Split('|')
                $Out.Protocol = $Cols[0]
                ## Some ports don't have a state.  If they do, there's always 4 fields in the line
                if ($Cols.Count -eq 4) {
                    $Out.State = $Cols[3]
                }
                ## All port lines that start with a [ are IPv6
                if ($Cols[1].StartsWith('[')) {
                    $Out.IPVersion = 'IPv6'
                    $Out.LocalAddress = $Cols[1].Split(']')[0].TrimStart('[')
                    $Out.LocalPort = $Cols[1].Split(']')[1].TrimStart(':')
                    if ($Cols[2] -eq '*:*') {
                       $Out.RemoteAddress = '*'
                       $Out.RemotePort = '*'
                    } else {
                       $Out.RemoteAddress = $Cols[2].Split(']')[0].TrimStart('[')
                       $Out.RemotePort = $Cols[2].Split(']')[1].TrimStart(':')
                    }
                } else {
                    $Out.IPVersion = 'IPv4'
                    $Out.LocalAddress = $Cols[1].Split(':')[0]
                    $Out.LocalPort = $Cols[1].Split(':')[1]
                    $Out.RemoteAddress = $Cols[2].Split(':')[0]
                    $Out.RemotePort = $Cols[2].Split(':')[1]
                }
                ## Because the process owner and service are on separate lines than the port line and the number of lines between them is variable
                ## this craziness was necessary.  This line starts parsing the netstat output at the current port line and searches for all
                ## lines after that that are NOT a port line and finds the first one.  This is how many lines there are until the next port
                ## is defined.
                $LinesUntilNextPortNum = ($Netstat | Select-Object -Skip $i | Select-String -Pattern '^[A-Z]{3}\|' -NotMatch | Select-Object -First 1).LineNumber
                ## Add the current line to the number of lines until the next port definition to find the associated process owner and service name
                $NextPortLineNum = $i + $LinesUntilNextPortNum
                ## This would contain the process owner and service name
                $PortAttribs = $Netstat[($i+1)..$NextPortLineNum]
                ## The process owner is always enclosed in brackets of, if it can't find the owner, starts with 'Can'
                $Out.ProcessOwner = $PortAttribs -match '^\[.*\.exe\]|Can'
                if ($Out.ProcessOwner) {
                    ## Get rid of the brackets and pick the first index because this is an array
                    $Out.ProcessOwner = ($Out.ProcessOwner -replace '\[|\]','')[0]
                }
                ## A service is always a combination of multiple word characters at the start of the line
                if ($PortAttribs -match '^\w+$') {
                    $Out.Service = ($PortAttribs -match '^\w+$')[0]
                }
                [pscustomobject]$Out
            }
            ## Keep the counter
            $i++
        }    	
	} catch {
		Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
	}
}