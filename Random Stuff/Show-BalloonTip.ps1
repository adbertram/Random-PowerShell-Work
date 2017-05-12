function Show-BalloonTip
{
	[OutputType([void])]
	[CmdletBinding(DefaultParameterSetName = 'IconFilePath')]
	param
	(
		[Parameter(Mandatory,ParameterSetName = 'IconFilePath')]
		[ValidateNotNullOrEmpty()]
		[string]$IconFilePath,

		[Parameter(Mandatory,ParameterSetName = 'Icon')]
		[ValidateNotNullOrEmpty()]
		[System.Drawing.Icon]$Icon,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Text,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Error','Info','None','Warning')]
		[string]$IconType = 'None',

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Title
	)

	try {

		$balloon = New-Object System.Windows.Forms.NotifyIcon
		
		if ($IconFilePath) {
			$icon = $IconFilePath
		}
		$balloon.Icon            = $icon
		$balloon.BalloonTipIcon  = $IconType
		$balloon.BalloonTipText  = $Text
		$balloon.BalloonTipTitle = $Title
		$balloon.Visible         = $true

		$balloon.ShowBalloonTip(1)
	} catch {
		Write-Error -Message $_.Exception.Message
	} finally {
		# $balloon.Dispose()
		# Remove–Variable –Name balloon
	}
}