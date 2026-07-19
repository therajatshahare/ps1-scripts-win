<#
.SYNOPSIS
    Uninstaller for ps1-scripts-win

.DESCRIPTION
    Reverses everything install.ps1 does:
      - Removes the install directory (C:\Windows\ps1-scripts-win or $HOME\ps1-scripts-win)
      - Removes that directory from the User PATH
      - Strips the toolkit block out of both PowerShell profile files
      - Optionally removes the PSGallery modules the installer added
      - Optionally uninstalls the winget dependencies the installer added
        (git, scoop, yt-dlp, ffmpeg, aria2, python, PowerShell 7)
        -- OFF by default, since other software may depend on these.

.USAGE
    irm https://raw.githubusercontent.com/therajatshahare/ps1-scripts-win/main/uninstall.ps1 | iex

    You'll be prompted interactively for which dependencies (if any) to
    also remove (git, python, ffmpeg, yt-dlp, aria2, scoop, PowerShell 7).

    To skip the prompt entirely (non-interactive/CI use):
    $script:RemoveDeps = $false   # keep all dependencies
    $script:RemoveDeps = $true    # remove all dependencies
    irm https://raw.githubusercontent.com/therajatshahare/ps1-scripts-win/main/uninstall.ps1 | iex
#>

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Red
Write-Host "           ps1-scripts-win          " -ForegroundColor Red
Write-Host "          Uninstall Starting          " -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red

# -------------------------------
# CONFIG
# -------------------------------
$adminDir = "C:\Windows\ps1-scripts-win"
$userDir  = Join-Path $HOME "ps1-scripts-win"

$profilePaths = @(
    "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
    "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
)

# Dependency list: command to check for, winget package id, display name
$depTable = @(
    @{ Cmd = "git";    Winget = "Git.Git";           Name = "Git" }
    @{ Cmd = "python"; Winget = "Python.Python.3";   Name = "Python" }
    @{ Cmd = "ffmpeg"; Winget = "Gyan.FFmpeg";       Name = "FFmpeg" }
    @{ Cmd = "yt-dlp"; Winget = "yt-dlp.yt-dlp";     Name = "yt-dlp" }
    @{ Cmd = "aria2c"; Winget = "aria2.aria2";       Name = "aria2" }
    @{ Cmd = "scoop";  Winget = "ScoopInstaller.Scoop"; Name = "Scoop" }
    @{ Cmd = "pwsh";   Winget = "Microsoft.PowerShell";  Name = "PowerShell 7" }
)

# $script:RemoveDeps can be pre-set to $true/$false to skip the prompt
# (useful for automation). Otherwise we ask interactively below.
$skipPrompt = Test-Path variable:script:RemoveDeps
$selectedDeps = @()

# -------------------------------
# 1. REMOVE INSTALL DIRECTORY
# -------------------------------
Write-Host "`nRemoving installed scripts..." -ForegroundColor Cyan

foreach ($dir in @($adminDir, $userDir)) {
    if (Test-Path $dir) {
        try {
            Remove-Item -Path $dir -Recurse -Force
            Write-Host "[OK] Removed: $dir" -ForegroundColor Green
        } catch {
            Write-Host "[FAIL] Failed to remove $dir (try running as Administrator)" -ForegroundColor Red
            Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkGray
        }
    }
}

# -------------------------------
# 2. REMOVE FROM USER PATH
# -------------------------------
Write-Host "`nCleaning PATH..." -ForegroundColor Cyan

$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not [string]::IsNullOrWhiteSpace($currentPath)) {
    $pathParts = $currentPath -split ';' | Where-Object {
        $_ -ne "" -and $_ -ne $adminDir -and $_ -ne $userDir
    }
    $newPath = $pathParts -join ';'

    if ($newPath -ne $currentPath) {
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Host "[OK] Removed toolkit dir(s) from User PATH" -ForegroundColor Green
    } else {
        Write-Host "PATH did not contain toolkit dir(s)"
    }
}

# Update PATH for current session too
$env:PATH = (($env:PATH -split ';') | Where-Object {
    $_ -ne "" -and $_ -ne $adminDir -and $_ -ne $userDir
}) -join ';'

# -------------------------------
# 3. CLEAN POWERSHELL PROFILES
# -------------------------------
Write-Host "`nCleaning PowerShell profiles..." -ForegroundColor Cyan

foreach ($profilePath in $profilePaths) {
    if (-not (Test-Path $profilePath)) {
        continue
    }

    try {
        $content = [System.IO.File]::ReadAllText($profilePath)
    } catch {
        continue
    }

    $original = $content

    # Remove both historical block-terminator variants used by install.ps1
    $content = $content -replace '(?s)\s*# ===== ps1-scripts-win Setup =====.*?# ===== End ps1-scripts-win Script Setup =====\s*', "`r`n"
    $content = $content -replace '(?s)\s*# ===== ps1-scripts-win Setup =====.*?# ===== End ps1-scripts-win =====\s*', "`r`n"

    if ($content -ne $original) {
        [System.IO.File]::WriteAllText(
            $profilePath,
            $content.Trim(),
            [System.Text.UTF8Encoding]::new($false)
        )
        Write-Host "[OK] Cleaned profile: $profilePath" -ForegroundColor Green
    } else {
        Write-Host "No toolkit block found in: $profilePath"
    }
}

# -------------------------------
# 4. POWERSHELL MODULES (PSGallery)
# -------------------------------
Write-Host "`nRemoving PowerShell modules added by the toolkit..." -ForegroundColor Cyan

function Uninstall-PSModuleIfPresent {
    param([string]$ModuleName)

    $module = Get-Module -ListAvailable -Name $ModuleName
    if ($module) {
        try {
            Uninstall-Module $ModuleName -AllVersions -Force -ErrorAction Stop
            Write-Host "[OK] Removed module: $ModuleName" -ForegroundColor Green
        } catch {
            Write-Host "[FAIL] Could not remove module $ModuleName (may be a built-in/system copy)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "$ModuleName not installed"
    }
}

Uninstall-PSModuleIfPresent "CompletionPredictor"
# PSReadLine ships with PowerShell itself -- removing it can break the shell,
# so it's intentionally left alone.
Write-Host "Leaving PSReadLine in place (it's a built-in PowerShell component)"

# -------------------------------
# 5. OPTIONAL: WINGET DEPENDENCIES
# -------------------------------
Write-Host "`nDependencies" -ForegroundColor Cyan
Write-Host "The installer also set these up if they were missing on your system." -ForegroundColor DarkGray
Write-Host "Other software on your PC may rely on them, so choose carefully." -ForegroundColor DarkGray

if ($skipPrompt) {
    # Non-interactive: $script:RemoveDeps was pre-set by the caller
    if ($script:RemoveDeps) {
        $selectedDeps = $depTable
        Write-Host "RemoveDeps=`$true - removing all listed dependencies without prompting." -ForegroundColor Yellow
    } else {
        Write-Host "RemoveDeps=`$false - keeping all dependencies." -ForegroundColor DarkGray
    }
} else {
    Write-Host ""
    for ($i = 0; $i -lt $depTable.Count; $i++) {
        $installed = if (Get-Command $depTable[$i].Cmd -ErrorAction SilentlyContinue) { "installed" } else { "not installed" }
        Write-Host ("  [{0}] {1} ({2})" -f ($i + 1), $depTable[$i].Name, $installed)
    }
    Write-Host ""
    Write-Host "Enter numbers to remove (e.g. 1,3,5), 'all', or press Enter to keep everything:" -ForegroundColor Cyan
    $answer = Read-Host ">"

    if ($answer -match '^\s*all\s*$') {
        $selectedDeps = $depTable
    } elseif (-not [string]::IsNullOrWhiteSpace($answer)) {
        $indexes = $answer -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ - 1 }
        $selectedDeps = $indexes | Where-Object { $_ -ge 0 -and $_ -lt $depTable.Count } | ForEach-Object { $depTable[$_] }
    }
}

if ($selectedDeps.Count -gt 0) {
    Write-Host "`nRemoving selected dependencies..." -ForegroundColor Cyan

    $wingetAvailable = [bool](Get-Command winget -ErrorAction SilentlyContinue)
    $removedPython = $false

    foreach ($dep in $selectedDeps) {
        if (Get-Command $dep.Cmd -ErrorAction SilentlyContinue) {

            if ($dep.Cmd -eq "scoop") {
                # Scoop manages itself entirely (its own folder + PATH entries).
                # winget's "ScoopInstaller.Scoop" package has no real uninstall
                # action wired up, so it must be removed via Scoop's own command.
                try {
                    "y" | scoop uninstall scoop -p
                    Write-Host "[OK] Uninstalled Scoop" -ForegroundColor Green
                } catch {
                    Write-Host "[FAIL] 'scoop uninstall scoop -p' failed. Remove manually:" -ForegroundColor Yellow
                    Write-Host "  Remove-Item -Recurse -Force `"`$env:USERPROFILE\scoop`"" -ForegroundColor DarkGray
                }
                continue
            }

            if ($wingetAvailable) {
                try {
                    winget uninstall --id $dep.Winget -e --silent
                    Write-Host "[OK] Uninstalled $($dep.Name)" -ForegroundColor Green
                    if ($dep.Cmd -eq "python") { $removedPython = $true }
                } catch {
                    Write-Host "[FAIL] Failed to uninstall $($dep.Name)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "winget not found. Please remove $($dep.Name) manually." -ForegroundColor Yellow
            }
        } else {
            Write-Host "$($dep.Name) not installed"
        }
    }

    # lyricsgenius pip package (only relevant if python is still around)
    if (-not $removedPython -and (Get-Command python -ErrorAction SilentlyContinue)) {
        try {
            python -m pip uninstall -y lyricsgenius
            Write-Host "[OK] Removed lyricsgenius (pip)" -ForegroundColor Green
        } catch {
            Write-Host "Could not remove lyricsgenius via pip." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "`nKeeping all dependencies installed." -ForegroundColor DarkGray
}

# -------------------------------
# DONE
# -------------------------------
Write-Host "`n=== Uninstall Complete ===" -ForegroundColor Green
Write-Host "Restart PowerShell to apply all changes."
