Import-Module posh-git -RequiredVersion 1.0.0

$newLine = [System.Environment]::NewLine
$bit = @{ $True = 'x64'; $False = 'x86' }[[System.Environment]::Is64BitProcess]
$label = if ($PSVersionTable.PSEdition -eq "Core") { "PWSH" } else { "PS" }
$promptString = ('$' * ($nestedPromptLevel + 1)) + ' '

$global:GitPromptSettings.DefaultPromptPath.ForegroundColor = 'magenta'
$global:GitPromptSettings.DefaultPromptSuffix = "$newLine$promptString"
$global:GitPromptSettings.DefaultPromptSuffix.ForegroundColor = 'green'
$global:GitPromptSettings.BeforeStatus.ForegroundColor = 'darkyellow'
$global:GitPromptSettings.AfterStatus.ForegroundColor = 'darkyellow'
$global:GitPromptSettings.DefaultPromptPrefix = "$label$bit "
