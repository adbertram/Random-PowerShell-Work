if ([Environment]::Is64BitProcess)
{
	throw 'This module is not supported in a x64 PowerShell session. Please load this module into a x86 PowerShell session.'	
}