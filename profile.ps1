Set-StrictMode -Version Latest

Import-Module -Name Soumya.Utilities

. (Join-Path $PSScriptRoot ColorUtils.ps1)

function Prompt {
    try {
        $userName = [System.Environment]::UserName
        $computerName = [System.Environment]::MachineName
        $promptString = '$ '
        $newLine = [System.Environment]::NewLine
        $bit = @{ $True = 'x64'; $False = 'x86' }[[System.Environment]::Is64BitProcess]
        $label = if ($PSVersionTable.PSEdition -eq "Core") { "PWSH" } else { "PS" }

        return `
            $(colorize $([MyConsoleColors]::FGWhite) "$label") + `
            $(colorize $([MyConsoleColors]::FGCyanBold) "$bit") + `
            $(colorize $([MyConsoleColors]::Reset) " [") + `
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
