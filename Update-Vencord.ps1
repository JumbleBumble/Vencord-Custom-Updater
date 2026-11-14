
#Requires -Version 5.1
param(
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = $PSScriptRoot
$stateRoot = Join-Path $env:LOCALAPPDATA 'VencordSourceUpdater'
$discordRoot = Join-Path $env:LOCALAPPDATA 'Discord'
$discordProcessPathPrefix = $discordRoot.TrimEnd('\') + '\'
$mutex = $null
$ownsMutex = $false
$locationPushed = $false
$success = $false

function Invoke-External {
    param([string]$File, [string[]]$Arguments)
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed (exit $LASTEXITCODE): $File $($Arguments -join ' ')" }
}
function Get-ExternalOutput {
    param([string]$File, [string[]]$Arguments)
    $output = & $File @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed (exit $LASTEXITCODE): $File $($Arguments -join ' ')" }
    return ($output -join "`n").Trim()
}
function Save-State {
    param([string]$Path, [string]$Value)
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    $temp = "$Path.$PID.tmp"
    Set-Content -LiteralPath $temp -Value $Value -Encoding ASCII -NoNewline
    Move-Item -LiteralPath $temp -Destination $Path -Force
}
function Get-DiscordStableProcesses {
    return @(
        Get-CimInstance Win32_Process -Filter "Name = 'Discord.exe'" -ErrorAction Stop |
            Where-Object {
                $_.ExecutablePath -and
                $_.ExecutablePath.StartsWith(
                    $discordProcessPathPrefix,
                    [StringComparison]::OrdinalIgnoreCase
                )
            }
    )
}
function Stop-DiscordStable {
    $running = @(Get-DiscordStableProcesses)
    if ($running.Count -eq 0) { return }

    Write-Host 'Closing Discord Stable before injection...'
    foreach ($processInfo in $running) {
        $process = Get-Process -Id $processInfo.ProcessId -ErrorAction SilentlyContinue
        if ($process -and $process.MainWindowHandle -ne [IntPtr]::Zero) {
            $process.CloseMainWindow() | Out-Null
        }
    }

    $deadline = (Get-Date).AddSeconds(8)
    do {
        Start-Sleep -Seconds 1
        $running = @(Get-DiscordStableProcesses)
    } while ($running.Count -gt 0 -and (Get-Date) -lt $deadline)

    if ($running.Count -gt 0) {
        Write-Host 'Discord is still running in the background. Stopping remaining Stable processes...'
        foreach ($processInfo in $running) {
            $processId = [int]$processInfo.ProcessId
            $currentProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $processId" -ErrorAction SilentlyContinue
            if (
                $currentProcess -and
                $currentProcess.ExecutablePath -and
                $currentProcess.ExecutablePath.StartsWith(
                    $discordProcessPathPrefix,
                    [StringComparison]::OrdinalIgnoreCase
                )
            ) {
                Stop-Process -Id $processId -Force -ErrorAction Stop
            }
        }

        $deadline = (Get-Date).AddSeconds(10)
        do {
            Start-Sleep -Seconds 1
            $running = @(Get-DiscordStableProcesses)
        } while ($running.Count -gt 0 -and (Get-Date) -lt $deadline)

        if ($running.Count -gt 0) {
            $processIds = ($running | ForEach-Object { $_.ProcessId }) -join ', '
            throw "Discord Stable processes could not be stopped: $processIds"
        }
    }
    Write-Host 'Discord Stable closed successfully.'
}
function Start-DiscordStable {
    $updater = Join-Path $discordRoot 'Update.exe'
    if (-not (Test-Path -LiteralPath $updater -PathType Leaf)) {
        Write-Warning "Discord Stable launcher not found at $updater. Open Discord manually."
        return
    }
    Write-Host 'Opening Discord...'
    Start-Process -FilePath $updater -ArgumentList @('--processStart', 'Discord.exe') -WorkingDirectory $discordRoot
}

try {
    if (-not $repositoryRoot -or -not (Test-Path -LiteralPath (Join-Path $repositoryRoot 'package.json') -PathType Leaf)) {
        throw 'Place Update-Vencord.ps1 in the root of your Vencord source checkout (next to package.json).'
    }
    $git = (Get-Command git -ErrorAction Stop).Source
    $pnpmCommand = Get-Command pnpm.cmd -ErrorAction SilentlyContinue
    if (-not $pnpmCommand) { $pnpmCommand = Get-Command pnpm -ErrorAction Stop }
    $pnpm = $pnpmCommand.Source

    Push-Location -LiteralPath $repositoryRoot
    $locationPushed = $true
    $inside = Get-ExternalOutput $git @('rev-parse', '--show-toplevel')
    $rootResolved = (Resolve-Path -LiteralPath $repositoryRoot).Path.TrimEnd('\', '/')
    $gitResolved = (Resolve-Path -LiteralPath $inside).Path.TrimEnd('\', '/')
    if ($rootResolved -ine $gitResolved) { throw 'The script must be in the root of the Vencord Git checkout.' }
    $package = Get-Content -LiteralPath (Join-Path $repositoryRoot 'package.json') -Raw | ConvertFrom-Json
    if ($package.name -notmatch 'vencord') { throw 'This does not appear to be a Vencord source checkout.' }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($rootResolved.ToLowerInvariant())
        $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').Substring(0, 16)
    } finally { $sha.Dispose() }
    $stateDirectory = Join-Path $stateRoot $hash
    $statePath = Join-Path $stateDirectory 'installed-commit.txt'
    $pendingPath = Join-Path $stateDirectory 'pending-commit.txt'
    $mutex = New-Object System.Threading.Mutex($false, "Local\VencordSourceUpdater_$hash")
    try { $ownsMutex = $mutex.WaitOne(0) }
    catch [System.Threading.AbandonedMutexException] { $ownsMutex = $true }
    if (-not $ownsMutex) { throw 'An updater is already running for this Vencord checkout.' }

    Write-Host "Vencord source: $repositoryRoot"
    $dirty = Get-ExternalOutput $git @('status', '--porcelain=v1', '--untracked-files=no')
    if ($dirty) { throw 'Tracked files have local modifications. Commit or stash them before updating.' }

    $upstream = Get-ExternalOutput $git @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}')
    $separator = $upstream.IndexOf('/')
    if ($separator -le 0) { throw 'The current branch needs an upstream tracking branch.' }
    $remote = $upstream.Substring(0, $separator)
    Write-Host 'Checking for upstream updates...'
    Invoke-External $git @('fetch', '--prune', $remote)
    $counts = (Get-ExternalOutput $git @('rev-list', '--left-right', '--count', "HEAD...$upstream")) -split '\s+'
    $ahead = [int]$counts[0]
    $behind = [int]$counts[1]
    if ($ahead -gt 0) { throw 'Your branch has local commits and cannot be fast-forwarded safely. Nothing was reset.' }

    $beforeLock = Get-ExternalOutput $git @('rev-parse', 'HEAD:pnpm-lock.yaml')
    if ($behind -gt 0) {
        Write-Host "Found $behind upstream commit(s). Fast-forwarding..."
        $target = Get-ExternalOutput $git @('rev-parse', $upstream)
        Save-State $pendingPath $target
        Invoke-External $git @('merge', '--ff-only', $upstream)
    } else { Write-Host 'Source is already up to date.' }

    $current = Get-ExternalOutput $git @('rev-parse', 'HEAD')
    $installed = ''
    if (Test-Path -LiteralPath $statePath) { $installed = (Get-Content -LiteralPath $statePath -Raw).Trim() }
    $pending = ''
    if (Test-Path -LiteralPath $pendingPath) { $pending = (Get-Content -LiteralPath $pendingPath -Raw).Trim() }
    $needsBuild = (-not $installed) -or ($installed -ne $current) -or ($pending -eq $current)

    if (-not $needsBuild) {
        Write-Host 'This commit was already installed by the updater. No build needed.'
        $success = $true
    } else {
        $afterLock = Get-ExternalOutput $git @('rev-parse', 'HEAD:pnpm-lock.yaml')
        if ($beforeLock -ne $afterLock -or -not (Test-Path -LiteralPath (Join-Path $repositoryRoot 'node_modules') -PathType Container)) {
            Write-Host 'Installing dependencies...'
            Invoke-External $pnpm @('install', '--frozen-lockfile')
        }
        Write-Host 'Building Vencord with development plugins...'
        Invoke-External $pnpm @('build', '--dev')
        Stop-DiscordStable
        Write-Host 'Injecting Vencord into Discord Stable...'       
        $installerScript = Join-Path $repositoryRoot 'scripts\runInstaller.mjs'
        $injectLines = [System.Collections.Generic.List[string]]::new()
        & node $installerScript -- --install --branch stable | ForEach-Object {
            $line = $_.ToString()
            Write-Host $line
            $injectLines.Add($line)
        }
        $injectExit = $LASTEXITCODE
        $injectText = $injectLines -join "`n"
        if ($injectExit -ne 0 -or $injectText.Contains('Something went wrong')) {
            throw "Injection failed (exit code $injectExit). Review the installer output above."
        }
        Save-State $statePath $current
        Remove-Item -LiteralPath $pendingPath -Force -ErrorAction SilentlyContinue
        Write-Host 'Vencord successfully updated and installed.' -ForegroundColor Green
        $success = $true
    }
    if ($success) { Start-DiscordStable }
} catch {
    Write-Host ''
    Write-Host "Update failed: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($locationPushed) { Pop-Location }
    if ($ownsMutex -and $mutex) { $mutex.ReleaseMutex() }
    if ($mutex) { $mutex.Dispose() }
}
if (-not $success) {
    if (-not $NoPause) {
        [void](Read-Host 'Press Enter to close')
    }
    exit 1
}
Write-Host 'Vencord updater completed successfully. Automatically closing this window in 5 seconds..' -ForegroundColor Green
if (-not $NoPause) {
    Start-Sleep -Seconds 5
}
