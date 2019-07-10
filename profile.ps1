Set-StrictMode -Version Latest

class MyConsoleColors
{
    static [string] $FGBlack = "$([char] 27)[0;30m"         # Black - Regular
    static [string] $FGRed = "$([char] 27)[0;31m"           # Red - Regular
    static [string] $FGGreen = "$([char] 27)[0;32m"         # Green - Regular
    static [string] $FGYellow = "$([char] 27)[0;33m"        # Yellow - Regular
    static [string] $FGBlue = "$([char] 27)[0;34m"          # Blue - Regular
    static [string] $FGPurple = "$([char] 27)[0;35m"        # Purple - Regular
    static [string] $FGCyan = "$([char] 27)[0;36m"          # Cyan - Regular
    static [string] $FGWhite = "$([char] 27)[0;37m"         # White - Regular
    static [string] $FGBlackBold = "$([char] 27)[1;30m"     # Black - Bold
    static [string] $FGRedBold = "$([char] 27)[1;31m"       # Red - Bold
    static [string] $FGGreenBold = "$([char] 27)[1;32m"     # Green - Bold
    static [string] $FGYellowBold = "$([char] 27)[1;33m"    # Yellow - Bold
    static [string] $FGBlueBold = "$([char] 27)[1;34m"      # Blue - Bold
    static [string] $FGPurpleBold = "$([char] 27)[1;35m"    # Purple - Bold
    static [string] $FGCyanBold = "$([char] 27)[1;36m"      # Cyan - Bold
    static [string] $FGWhiteBold = "$([char] 27)[1;37m"     # White - Bold
    static [string] $FGBlackUL = "$([char] 27)[4;30m"       # Black - Underline
    static [string] $FGRedUL = "$([char] 27)[4;31m"         # Red - Underline
    static [string] $FGGreenUL = "$([char] 27)[4;32m"       # Green - Underline
    static [string] $FGYellowUL = "$([char] 27)[4;33m"      # Yellow - Underline
    static [string] $FGBlueUL = "$([char] 27)[4;34m"        # Blue - Underline
    static [string] $FGPurpleUL = "$([char] 27)[4;35m"      # Purple - Underline
    static [string] $FGCyanUL = "$([char] 27)[4;36m"        # Cyan - Underline
    static [string] $FGWhiteUL = "$([char] 27)[4;37m"       # White - Underline
    static [string] $BGBlack = "$([char] 27)[40m"           # Black - Background
    static [string] $BGRed = "$([char] 27)[41m"             # Red - Background
    static [string] $BGGreen = "$([char] 27)[42m"           # Green - Background
    static [string] $BGYellow = "$([char] 27)[43m"          # Yellow - Background
    static [string] $BGBlue = "$([char] 27)[44m"            # Blue - Background
    static [string] $BGPurple = "$([char] 27)[45m"          # Purple - Background
    static [string] $BGCyan = "$([char] 27)[46m"            # Cyan - Background
    static [string] $BGWhite = "$([char] 27)[47m"           # White - Background
    static [string] $Reset = "$([char] 27)[0m"              # Text Reset - Useful for avoiding color bleed
}

function Prompt {
    try {
        $userName = [System.Environment]::UserName
        $computerName = [System.Environment]::MachineName
        $promptString = ('$' * ($nestedPromptLevel + 1)) + ' '
        $newLine = [System.Environment]::NewLine

        $label = if ($PSVersionTable.PSEdition -eq "Core") { "PWSH" } else { "PS" }

        return `
            $(colorize $([MyConsoleColors]::FGWhite) "$label [") + `
            $(colorize $([MyConsoleColors]::FGRedBold) $userName) + `
            $(colorize $([MyConsoleColors]::Reset) "@") + `
            $(colorize $([MyConsoleColors]::FGGreenBold) $computerName) + `
            $(colorize $([MyConsoleColors]::Reset) "] ") + `
            $(colorize $([MyConsoleColors]::FGYellowBold) $(shortenCurrentPath)) + `
            $(colorize $([MyConsoleColors]::Reset) $newLine) + `
            $(colorize $([MyConsoleColors]::FGWhite) $promptString)
    }
    catch {
        Write-Host "An error occurred:"
        Write-Host $_
    }
}

function shortenCurrentPath() {
    $path = $executionContext.SessionState.Path.CurrentLocation.Path;
    $pattern = [System.Text.RegularExpressions.Regex]::Escape($HOME)
    return [System.Text.RegularExpressions.Regex]::Replace($path, $pattern, '~', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

function colorize([string] $color, [string] $text, [string] $resetColor = [MyConsoleColors]::Reset) {
    $colorizedText = "$color$text$resetColor"
    return $colorizedText
}
