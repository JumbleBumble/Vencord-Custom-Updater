#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

try {
    $root = (Resolve-Path -LiteralPath $PSScriptRoot).Path
    $updater = Join-Path $root 'Update-Vencord.ps1'
    $packagePath = Join-Path $root 'package.json'

    if (-not (Test-Path -LiteralPath $updater -PathType Leaf)) {
        throw 'Update-Vencord.ps1 is missing. Extract all files into the same Vencord source folder.'
    }
    if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
        throw 'Place these files in your Vencord source folder (the folder containing package.json).'
    }
    $package = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json
    if (-not $package.name -or $package.name -notmatch 'vencord') {
        throw 'This does not look like a Vencord source folder.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $root '.git'))) {
        throw 'Vencord must be a Git checkout. A ZIP download of the Vencord source is not sufficient.'
    }

    $powershellExe = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powershellExe -PathType Leaf)) {
        throw 'Windows PowerShell 5.1 was not found.'
    }

    $desktop = [Environment]::GetFolderPath('DesktopDirectory')
    if ([string]::IsNullOrWhiteSpace($desktop) -or -not (Test-Path -LiteralPath $desktop)) {
        throw 'Windows could not locate the Desktop folder.'
    }

    $shortcutPath = Join-Path $desktop 'Update Vencord.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $powershellExe
    $shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $updater
    $shortcut.WorkingDirectory = $root
    $shortcut.Description = 'Update and rebuild Vencord from source while keeping user plugins'
    $shortcut.IconLocation = "$powershellExe,0"
    $shortcut.Save()

    Write-Host ''
    Write-Host 'Setup complete!' -ForegroundColor Green
    Write-Host "Desktop shortcut: $shortcutPath"
    Write-Host "Vencord source:   $root"
    Write-Host ''
    Write-Host 'Double-click "Update Vencord" on your Desktop to check for updates.'
    Write-Host 'The first run may build and inject Vencord even if Git is already up to date.'

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Warning 'Git was not found on PATH. Install Git before using the shortcut.'
    }
    if (-not (Get-Command pnpm.cmd -ErrorAction SilentlyContinue) -and
        -not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
        Write-Warning 'pnpm was not found on PATH. Install pnpm before using the shortcut.'
    }
    exit 0
} catch {
    Write-Host ''
    Write-Host "Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
