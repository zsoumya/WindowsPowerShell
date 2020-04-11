Import-Module posh-git -RequiredVersion 1.0.0

$promptChar = 'ᐅ'
$newLine = [System.Environment]::NewLine
$bit = @{ $True = 'x64'; $False = 'x86' }[[System.Environment]::Is64BitProcess]
$label = if ($PSVersionTable.PSEdition -eq "Core") { "PWSH" } else { "PS" }
$promptString = ($promptChar * ($nestedPromptLevel + 1)) + ' '

$Global:GitPromptSettings.DefaultPromptPath.ForegroundColor = 'magenta'
$Global:GitPromptSettings.DefaultPromptSuffix.Text = "$newLine$promptString"
$Global:GitPromptSettings.DefaultPromptSuffix.ForegroundColor = 'green'
$Global:GitPromptSettings.DefaultPromptPrefix.Text = "$label$bit "
$Global:GitPromptSettings.DefaultPromptPrefix.ForegroundColor = 'yellow'
$Global:GitPromptSettings.DefaultPromptWriteStatusFirst = $false
