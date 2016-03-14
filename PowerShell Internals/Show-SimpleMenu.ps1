function Show-Menu
{
	param (
		[string]$Title = 'My Menu'
	)
	Clear-Host
	Write-Host "================ $Title ================"
	
	Write-Host "1: Press '1' for this option."
	Write-Host "2: Press '2' for this option."
	Write-Host "3: Press '3' for this option."
	Write-Host "Q: Press 'Q' to quit."
}

do
{
	Show-Menu
	$selection = Read-Host "Please make a selection"
	Clear-Host
	switch ($selection)
	{
		'1' {
			'You chose option #1'
		} '2' {
			'You chose option #2'
		} '3' {
			'You chose option #3'
		} 'q' {
			return
		}
	}
	pause
}
until ($selection -eq 'q')