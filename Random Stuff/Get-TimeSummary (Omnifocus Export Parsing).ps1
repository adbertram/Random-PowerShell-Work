param (
	$OmnifocusTaskFile = 'C:\Users\Adam Bertram\Dropbox\OmniFocus.csv'
)

#region Confguration values
$script:DefaultWeekdayTimeAvail = @{
	'Monday' = 10
	'Tuesday' = 10
	'Wednesday' = 10
	'Thursday' = 10
	'Friday' = 9
	'Saturday' = 6
	'Sunday' = 3
}

$TotalReportWeeksOut = 8

$script:Today = Get-Date
#endregion

#region Functions
function Get-WeeklyWorkTime([switch]$ThisWeek)
{
	if ($ThisWeek.IsPresent)
	{
		$ThisSunday = @(@(0..7) | % { $((Get-Date).Date).AddDays($_) } | ? { $_.DayOfWeek -ieq 'Monday' })[0]
		(1..(New-TimeSpan -Start $Today -End $ThisSunday).Days | % { $DefaultWeekdayTimeAvail[$Today.AddDays($_).DayofWeek.ToString()] } | Measure-Object -Sum).Sum
	}
	else
	{
		($DefaultWeekdayTimeAvail.Values | Measure-Object -Sum).Sum
	}
}

function Get-TimeFrame ([datetime]$Date)
{
	$ThisSunday = @(@(0..7) | % { $((Get-Date).Date).AddDays($_) } | ? { $_.DayOfWeek -ieq 'Monday' })[0]
	if ($Date -lt $ThisSunday)
	{
		'This Week'
	}
	elseif ($Date -lt ($ThisSunday.AddDays(7)))
	{
		'1 Week'
	}
	elseif ($Date -lt ($ThisSunday.AddDays(14)))
	{
		'2 Weeks'
	}
	elseif ($Date -lt ($ThisSunday.AddDays(21)))
	{
		'3 Weeks'
	}
	elseif ($Date -lt ($ThisSunday.AddDays(30)))
	{
		'1 Month'
	}
	elseif ($Date -lt ($ThisSunday.AddDays(60)))
	{
		'2 Months'
	}
	elseif ($Date -lt ($ThisSunday.AddDays(90)))
	{
		'3 Months'
	}
	else
	{
		'A ways off'
	}
}
#endregion

$AllTasks = Import-Csv -Path $OmnifocusTaskFile

#region Omnifocus task exclusions

## Projects with a single task in a waiting state
$InactiveProjectIds = ($Alltasks | group project | ? { $_.Group.Count -eq 1 -and ($_.Group.Context -like 'WF*' -or $_.Group.Context -eq 'Waiting') } | % { $projectname = $_.Name; $AllTasks | ? { $_.Name -eq $projectname } }).'task id'

## Projects marked inactive
$InactiveProjectIds += ($Alltasks | ? { $_.Type -eq 'Project' -and $_.Status -eq 'inactive' }).'Task id'

## Get projects to get their due date if a task doesn't have one
$Projects = $AllTasks | ? { !$_.Project }

$ExcludeBlock = {
	$_.Context -notlike 'WF*' -and
	$_.Context -ne 'Waiting' -and
	$_.Context -ne 'Low Priority' -and
	$_.Context -ne 'Idea' -and
	$_.Project -notlike '*Ideas*' -and
	$_.Project -and
	$_.'Start Date' -lt $Today -and
	$_.'Task ID' -notin $InactiveProjectIds -and
	$_.Duration
}
#endregion

$AllTasks | ? $ExcludeBlock | % {
	if (-not $_.'Due Date')
	{
		## Find the due date of the task's project
		$ProjectId = $_.'Task Id'.Split('.')[0]
		$_.'Due Date' = ($Projects | ? { $_.'Task Id' -eq $ProjectId }).'Due Date'
	}
	$_
} | select name,
		@{ n = 'TimeEstimate'; e = { $_.Duration.TrimEnd('m') / 60 } },
		@{ n = 'DateTimeFrame'; e = { Get-TimeFrame -Date $_.'Due Date' } }, @{
	n = 'AvailableHours'; e = {
		$timeframe = Get-TimeFrame -Date $_.'Due Date';
		if ($timeframe -eq 'This Week')
		{
			Get-WeeklyWorkTime -ThisWeek
		}
		elseif ($timeframe -like '*Week*')
		{
			Get-WeeklyWorkTime
		}
		elseif ($timeframe -eq '1 month')
		{
			(Get-WeeklyWorkTime) * 4
		}
		elseif ($timeframe -eq '2 months')
		{
			(Get-WeeklyWorkTime) * 8
		}
		elseif ($timeframe -eq '3 months')
		{
			(Get-WeeklyWorkTime) * 12
		}
		else
		{
			'NA'
		}
	}
} | group DateTimeFrame | select name, @{ n = 'CommittedTime';e={($_.Group.TimeEstimate | Measure-Object -Sum).Sum} } | sort name





