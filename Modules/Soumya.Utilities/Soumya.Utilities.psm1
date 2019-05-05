Resolve-Path $PSScriptRoot\*.ps1 | ForEach-Object -Process {
	. $_.ProviderPath
}

function Test-Admin
{
	([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}

Export-ModuleMember -Cmdlet * -Function * -Variable * -Alias *

