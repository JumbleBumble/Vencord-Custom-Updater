#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$repositoryRoot = $PSScriptRoot
$discordRoot = Join-Path $env:LOCALAPPDATA 'Discord'
$discordProcessPathPrefix = $discordRoot.TrimEnd('\') + '\'
$discordUpdater = Join-Path $discordRoot 'Update.exe'
$locationPushed = $false
$mutex = $null
$ownsMutex = $false

function Invoke-CheckedCommand {
    param([string]$CommandPath, [string[]]$Arguments)
    Write-Host "> $CommandPath $($Arguments -join ' ')"
    & $CommandPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed (exit $LASTEXITCODE): $CommandPath $($Arguments -join ' ')"
    }
}

function Get-StableDiscordProcesses {
    @(
        Get-CimInstance Win32_Process -Filter "Name = 'Discord.exe'" -ErrorAction Stop |
            Where-Object {
                $_.ExecutablePath -and $_.ExecutablePath.StartsWith(
                    $discordProcessPathPrefix,
                    [StringComparison]::OrdinalIgnoreCase
                )
            }
    )
}

function Close-DiscordStable {
    $running = @(Get-StableDiscordProcesses)
    if ($running.Count -eq 0) { return }

    Write-Host 'Closing Discord Stable...'
    foreach ($info in $running) {
        $process = Get-Process -Id $info.ProcessId -ErrorAction SilentlyContinue
        if ($process -and $process.MainWindowHandle -ne [IntPtr]::Zero) {
            $process.CloseMainWindow() | Out-Null
        }
    }

    $deadline = (Get-Date).AddSeconds(8)
    do {
        Start-Sleep -Seconds 1
        $running = @(Get-StableDiscordProcesses)
    } while ($running.Count -gt 0 -and (Get-Date) -lt $deadline)

    if ($running.Count -gt 0) {
        Write-Host 'Discord is still running in the background. Stopping remaining Stable processes...'
        foreach ($info in $running) {
            $pidToStop = [int]$info.ProcessId
            $current = Get-CimInstance Win32_Process -Filter "ProcessId = $pidToStop" -ErrorAction SilentlyContinue
            if ($current -and $current.ExecutablePath -and $current.ExecutablePath.StartsWith(
                $discordProcessPathPrefix,
                [StringComparison]::OrdinalIgnoreCase
            )) {
                Stop-Process -Id $pidToStop -Force -ErrorAction Stop
            }
        }
        $deadline = (Get-Date).AddSeconds(10)
        do {
            Start-Sleep -Seconds 1
            $running = @(Get-StableDiscordProcesses)
        } while ($running.Count -gt 0 -and (Get-Date) -lt $deadline)
        if ($running.Count -gt 0) {
            throw "Could not stop Discord Stable processes: $(($running | ForEach-Object { $_.ProcessId }) -join ', ')"
        }
    }
}


function Install-DevelopmentBuild {
    Write-Host 'Installing your development build into Discord Stable...'
    $installerScript = Join-Path $repositoryRoot 'scripts\runInstaller.mjs'
    $outputLines = [System.Collections.Generic.List[string]]::new()
    & node $installerScript -- --install --branch stable | ForEach-Object {
        $line = $_.ToString()
        Write-Host $line
        $outputLines.Add($line)
    }
    $exitCode = $LASTEXITCODE
    $outputText = $outputLines -join "`n"
    if ($exitCode -ne 0 -or $outputText.Contains('Something went wrong')) {
        throw "Vencord injection failed (exit code $exitCode). Review the output above."
    }
}


try {
    $packagePath = Join-Path $repositoryRoot 'package.json'
    if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
        throw 'Put these scripts in the Vencord source folder (next to package.json).'
    }
    $package = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json
    if (-not $package.name -or $package.name -notmatch 'vencord') {
        throw 'This folder does not appear to contain Vencord source code.'
    }
    if (-not (Test-Path -LiteralPath $discordUpdater -PathType Leaf)) {
        throw "Discord Stable was not found at $discordRoot. This script supports Stable only."
    }
    $pnpmCommand = Get-Command pnpm.cmd -ErrorAction SilentlyContinue
    if (-not $pnpmCommand) { $pnpmCommand = Get-Command pnpm -ErrorAction Stop }
    $pnpmPath = $pnpmCommand.Source
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot 'node_modules') -PathType Container)) {
        throw 'Dependencies are missing. Open a terminal in the Vencord folder and run: pnpm install --frozen-lockfile'
    }

    $rootResolved = (Resolve-Path -LiteralPath $repositoryRoot).Path.TrimEnd('\', '/')
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($rootResolved.ToLowerInvariant())
        $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').Substring(0, 16)
    } finally { $sha.Dispose() }
    $mutex = New-Object System.Threading.Mutex($false, "Local\VencordSourceUpdater_$hash")
    try { $ownsMutex = $mutex.WaitOne(0) }
    catch [System.Threading.AbandonedMutexException] { $ownsMutex = $true }
    if (-not $ownsMutex) { throw 'The Vencord updater or rebuilder is already running for this folder.' }

    Push-Location -LiteralPath $repositoryRoot
    $locationPushed = $true
    Write-Host "Vencord source: $repositoryRoot"
    Write-Host 'This rebuilds your current source and plugins; it does NOT download updates.'
    Close-DiscordStable
    Invoke-CheckedCommand $pnpmPath @('build', '--dev')
    Install-DevelopmentBuild

    Write-Host 'Opening Discord Stable...'
    Start-Process -FilePath $discordUpdater -ArgumentList @('--processStart', 'Discord.exe') -WorkingDirectory $discordRoot
    $deadline = (Get-Date).AddSeconds(30)
    do {
        Start-Sleep -Seconds 1
        $running = @(Get-StableDiscordProcesses)
    } while ($running.Count -eq 0 -and (Get-Date) -lt $deadline)
    if ($running.Count -eq 0) { throw 'Discord was launched, but its process did not appear within 30 seconds.' }
    Write-Host 'Build, installation and Discord restart completed.' -ForegroundColor Green
} catch {
    Write-Host ''
    Write-Host "Build/install failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    if ($locationPushed) { Pop-Location }
    if ($ownsMutex -and $mutex) { $mutex.ReleaseMutex() }
    if ($mutex) { $mutex.Dispose() }
}
