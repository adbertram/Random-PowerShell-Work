function Show-Menu
{
	param (
		[string]$Title = 'My Menu'
	)
	cls
	Write-Host "================ $Title ================"
	
	Write-Host "1: Press '1' to begin scanning books."
	Write-Host "2: Press '2' to change locator code."
	Write-Host "3: Press '3' to change condition"
	Write-Host "Q: Press 'Q' to quit."
}

do
{
	$input = Read-Host "Please make a selection"
	switch ($input)
	{
		'1' {
			cls
			'You chose option #1'
		} '2' {
			cls
			'You chose option #2'
		} '3' {
			cls
			'You chose option #3'
		} 'q' {
			return
		}
	}
	pause
}
until ($input -eq 'q')