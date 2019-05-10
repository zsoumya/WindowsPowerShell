Resolve-Path $PSScriptRoot\*.ps1 | ForEach-Object -Process {
	. $_.ProviderPath
}

Export-ModuleMember -Cmdlet * -Function * -Variable * -Alias *

