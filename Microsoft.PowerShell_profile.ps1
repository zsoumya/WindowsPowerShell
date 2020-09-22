Import-Module posh-git -RequiredVersion 1.0.0

$promptChar = '⚡'
$separatorChar = '➤'
$promptPathForeColor = 'magenta'
$promptPrefixForeColor = 'yellow'
$promptStringForeColor = 'darkred'

$newLine = [System.Environment]::NewLine
$bit = @{ $True = 'x64'; $False = 'x86' }[[System.Environment]::Is64BitProcess]
$label = if ($PSVersionTable.PSEdition -eq "Core") { "PWSH" } else { "PS" }
$promptString = ($promptChar * ($nestedPromptLevel + 1)) + ' '

$Global:GitPromptSettings.DefaultPromptPath.ForegroundColor = $promptPathForeColor
$Global:GitPromptSettings.DefaultPromptPath.Text = '$(if ((Get-PromptPath) -eq $HOME) { "$(Get-PromptPath)(~)" } else { Get-PromptPath })'

$Global:GitPromptSettings.DefaultPromptSuffix.ForegroundColor = $promptStringForeColor
$Global:GitPromptSettings.DefaultPromptSuffix.Text = "$newLine$promptString"

$Global:GitPromptSettings.DefaultPromptPrefix.ForegroundColor = $promptPrefixForeColor
$Global:GitPromptSettings.DefaultPromptPrefix.Text = "$label$bit $separatorChar "

$Global:GitPromptSettings.DefaultPromptWriteStatusFirst = $false

$Global:GitPromptSettings.PathStatusSeparator.ForegroundColor = $promptPrefixForeColor
$Global:GitPromptSettings.PathStatusSeparator.Text = " $separatorChar "

