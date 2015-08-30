#requires -Module ActiveDirectory

<#
        .SYNOPSIS
        This script queries multiple Active Directory groups for new members in a domain.  It records group membership
        in a CSV file in the same location as the script is located. On the script's initial run it will simply record
        all members of all groups into this CSV file.  On subsequent runs it will query each group's member list and compare
        that list to what's in the CSV file.  If any differences are found (added or removed) the script will update the 
        CSV file to reflect current memberships and notify an administrator of which members were either added or removed.
        .NOTES
        Filename: Get-AdGroupMembershipChange.ps1
        .EXAMPLE
        PS> .\Get-AdGroupMembershipChange.ps1 -Group 'Enterprise Admins','Domain Admins','Schema Admins' -Email abertram@lab.local
	
        This example will query group memberships of the Enterprise Admins, Domain Admins and Schema Admins groups and email
        abertram@lab.local when a member is either added or removed from any of these groups.

        .PARAMETER Group
        One or more group names to monitor for membership changes
        .PARAMETER DomainController
        By default the Active Directory module will automatically find a domain controller to query. If this parameter is set
        the script will directly query this domain controller.
        .PARAMETER Email
        The email address of the administrator that would like to get notified of group changes.
        .PARAMETER LogFilePath
        The path to where the group membership CSV file will be placed.  This is the file that will record the most recent
        group membership and will be used to compare current to most recent.
#>
[CmdletBinding(SupportsShouldProcess)]
[OutputType('System.Management.Automation.PSCustomObject')]
param (
    [Parameter(Mandatory)]
    [string[]]$Group,
    [Parameter()]
    [ValidatePattern('\b[A-Z0-9._%+-]+@(?:[A-Z0-9-]+\.)+[A-Z]{2,4}\b')]
    [string]$Email = 'admin@lab.local',
    [Parameter()]
    [string]$LogFilePath = "$PsScriptRoot\$($MyInvocation.MyCommand.Name).csv"
)

begin {
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    Set-StrictMode -Version Latest

    function Write-Log {
        <#
                .SYNOPSIS
                This function creates or appends a line to a log file

                .DESCRIPTION
                This function writes a log line to a log file
                .PARAMETER  Message
                The message parameter is the log message you'd like to record to the log file
                .PARAMETER  LogLevel
                The logging level is the severity rating for the message you're recording. 
                You have 3 severity levels available; 1, 2 and 3 from informational messages
                for FYI to critical messages. This defaults to 1.

                .EXAMPLE
                PS C:\> Write-Log -Message 'Value1' -LogLevel 'Value2'
			
                This example shows how to call the Write-Log function with named parameters.
        #>
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [string]$Message,
            [Parameter()]
            [ValidateSet(1, 2, 3)]
            [int]$LogLevel = 1
        )
		
        try {
            $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
            ## Build the line which will be recorded to the log file
            $Line = '{2} {1}: {0}'
            $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy)
            $Line = $Line -f $LineFormat
			
            Add-Content -Value $Line -Path $LogFilePath
        } catch {
            Write-Error $_.Exception.Message
        }
    }

    function Add-GroupMemberToLogFile ($GroupName,[string[]]$Member) {
        foreach ($m in $Member) {
            [pscustomobject]@{'Group' = $GroupName; 'Member' = $m} | Export-Csv -Path $LogFilePath -Append -NoTypeInformation
        }   
    }
    
    function Get-GroupMemberFromLogFile ([string]$GroupName) {
        (Import-Csv -Path $LogFilePath | Where-Object { $_.Group -eq $GroupName }).Member
    }
    
    function Send-ChangeNotification ($GroupName,$ChangeType,$Members) {
        $EmailBody = "
            The following group has changed: $GroupName`n`r
            The following members were $ChangeType`n`r
            $($Members -join ',')
        "
        
        $Params = @{
            'From' = 'Active Directory Administrator <admin@mycompany.com>'
            'To' = $Email
            'Subject' = 'AD Group Change'
            'SmtpServer' = 'my.smptpserver.local'
            'Body' = $EmailBody
        }
        Send-MailMessage @Params
    }
}

process {
    try {
        Write-Log -Message 'Querying Active directory domain for group memberships...'
        foreach ($g in $Group) {
            Write-Log -Message "Querying the [$g] group for members..."
            $CurrentMembers = (Get-ADGroupMember -Identity $g).Name
            if (-not $CurrentMembers) {
                Write-Log -Message "No members found in the [$g] group."
            } else {
                Write-Log -Message "Found [$($CurrentMembers.Count)] members in the [$g] group"
                if (-not (Test-Path -Path $LogFilePath -PathType Leaf)) {
                    Write-Log -Message "The log file [$LogFilePath] does not exist yet. This must be the first run. Dumping all members into it..."
                    Add-GroupMemberToLogFile -GroupName $g -Member $CurrentMembers
                } else {
                    Write-Log -Message 'Existing log file found. Reading previous group members...'
                    $PreviousMembers = Get-GroupMemberFromLogFile -GroupName $g
                    $ComparedMembers = Compare-Object -ReferenceObject $PreviousMembers -DifferenceObject $CurrentMembers
                    if (-not $ComparedMembers) {
                        Write-Log "No differences found in group $g"
                    } else {
                        $RemovedMembers = ($ComparedMembers |  Where-Object { $_.SideIndicator -eq '<=' }).InputObject
                        if (-not $RemovedMembers) {
                            Write-Log -Message 'No members have been removed since last check'
                        } else {
                            Write-Log -Message "Found [$($RemovedMembers.Count)] members that have been removed since last check"
                            Send-ChangeNotification -GroupName $g -ChangeType 'Removed' -Members $RemovedMembers
                            Write-Log -Message "Emailed change notification to $Email"
                            ## Remove the members from the CSV file to keep the file current
                            (Import-Csv -Path $LogFilePath | Where-Object {$RemovedMembers -notcontains $_.Member}) | Export-Csv -Path $LogFilePath -NoTypeInformation
                        }
                         $AddedMembers = ($ComparedMembers |  Where-Object { $_.SideIndicator -eq '=>' }).InputObject
                         if (-not $AddedMembers) {
                             Write-Log -Message 'No members have been removed since last check'
                         } else {
                             Write-Log -Message "Found [$($AddedMembers.Count)] members that have been added since last check"
                             Send-ChangeNotification -GroupName $g -ChangeType 'Added' -Members $AddedMembers
                             Write-Log -Message "Emailed change notification to $Email"
                             ## Add the members from the CSV file to keep the file current
                            $AddedMembers | foreach {[pscustomobject]@{'Group' = $g; 'Member' = $_}} | Export-Csv -Path $LogFilePath -Append -NoTypeInformation
                         }
                        
                    }
                }
            }

        }

    } catch {
        Write-Error "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
    }
}