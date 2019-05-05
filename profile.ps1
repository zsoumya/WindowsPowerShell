function Prompt
{
	Write-Host "PS " -NoNewline -ForegroundColor Yellow
	Write-Host $(Get-Location) -ForegroundColor Green
	
	if (Test-Admin)
	{
		Write-Host "$" -NoNewline -ForegroundColor Cyan
	}
	else
	{
		Write-Host ">" -NoNewline -ForegroundColor Magenta
	}
	
	return " "
}

$platform = @{ $True = 'x64'; $False = 'x86' }[[System.Environment]::Is64BitProcess]
Write-Host ("Windows PowerShell $($PSVersionTable.PSVersion) $platform") -NoNewline

if (Test-Admin)
{
	Write-Host " (Admin)" -NoNewline -ForegroundColor Cyan
}

Write-Host
Write-Host
