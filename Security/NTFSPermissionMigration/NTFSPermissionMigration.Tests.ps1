#region import modules
$ThisModule = "$($MyInvocation.MyCommand.Path -replace "\.Tests\.ps1$", '').psm1"
$ThisModuleName = (($ThisModule | Split-Path -Leaf) -replace ".psm1")
Get-Module -Name $ThisModuleName -All | Remove-Module -Force

Import-Module -Name $ThisModule -Force -ErrorAction Stop

## If a module is in $Env:PSModulePath and $ThisModule is not, you will have two modules loaded when importing and 
## InModuleScope does not like that. 0.0 will always be the one imported directly from PSM1.
@(Get-Module -Name $ThisModuleName).where({ $_.version -ne "0.0" }) | Remove-Module -Force
#endregion

InModuleScope $ThisModuleName {
	describe 'Restore-Acl' {
		
	}
 	describe 'Save-Acl' {
		
	}

}
