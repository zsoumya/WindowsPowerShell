Import-Module -Name Soumya.Utilities
Import-Module -Name posh-git

function Prompt {
	$GitPromptSettings.DefaultPromptPrefix.Text = 'PS '
    $GitPromptSettings.DefaultPromptPrefix.ForegroundColor = [ConsoleColor]::Green
	$GitPromptSettings.DefaultPromptPath.ForegroundColor = 0xFFA500

    & $GitPromptScriptBlock
}

$platform = @{ $True = 'x64'; $False = 'x86' }[[System.Environment]::Is64BitProcess]
Write-Host ("Windows PowerShell $($PSVersionTable.PSVersion) $platform") -NoNewline

if (Test-Admin)
{
	Write-Host " (Admin)" -NoNewline -ForegroundColor Cyan
}

Write-Host
Write-Host
