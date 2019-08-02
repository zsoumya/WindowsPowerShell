Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot ColorUtils.ps1)

function Prompt {
    try {
        $userName = [System.Environment]::UserName
        $computerName = [System.Environment]::MachineName
        $promptString = ('$' * ($nestedPromptLevel + 1)) + ' '
        $newLine = [System.Environment]::NewLine

        $label = if ($PSVersionTable.PSVersion.Major -ge 6) { "PWSH" } else { "PS" }

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