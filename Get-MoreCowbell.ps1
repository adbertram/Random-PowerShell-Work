function Get-MoreCowbell
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$Introduction,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$Repeat = 10,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$CowbellUrl = 'http://emmanuelprot.free.fr/Drums%20kit%20Manu/Cowbell.wav',
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$IntroUrl = 'http://www.innervation.com/crap/cowbell.wav'
		
		
	)
	begin {
		$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	}
	process {
		try
		{
			$sound = new-Object System.Media.SoundPlayer
			$CowBellLoc = "$($env:TEMP)\Cowbell.wav"
			if (-not (Test-Path -Path $CowBellLoc -PathType Leaf))
			{
				Invoke-WebRequest -Uri $CowbellUrl -OutFile $CowBellLoc
			}
			if ($Introduction.IsPresent)
			{
				$IntroLoc = "$($env:TEMP)\CowbellIntro.wav"
				if (-not (Test-Path -Path $IntroLoc -PathType Leaf))
				{
					Invoke-WebRequest -Uri $IntroUrl -OutFile $IntroLoc
				}
				$sound.SoundLocation = $IntroLoc
				$sound.Play()
				sleep 2
			}
			$sound.SoundLocation = $CowBellLoc
			for ($i=0; $i -lt $Repeat; $i++) {
				$sound.Play();
				Start-Sleep -Milliseconds 500
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}