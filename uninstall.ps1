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

    To also remove winget dependencies:
    $script:RemoveDeps = $true
    irm https://raw.githubusercontent.com/therajatshahare/ps1-scripts-win/main/uninstall.ps1 | iex
#>

$ErrorActionPreference = "Continue"

Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║            ps1-scripts-win           ║" -ForegroundColor Red
Write-Host "║           Uninstall Starting          ║" -ForegroundColor Red
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Red

# -------------------------------
# CONFIG
# -------------------------------
$adminDir = "C:\Windows\ps1-scripts-win"
$userDir  = Join-Path $HOME "ps1-scripts-win"

$profilePaths = @(
    "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
    "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
)

# Allow the caller to opt in to removing shared dependencies:
#   $script:RemoveDeps = $true; irm ... | iex
if (-not (Test-Path variable:script:RemoveDeps)) {
    $script:RemoveDeps = $false
}

# -------------------------------
# 1. REMOVE INSTALL DIRECTORY
# -------------------------------
Write-Host "`nRemoving installed scripts..." -ForegroundColor Cyan

foreach ($dir in @($adminDir, $userDir)) {
    if (Test-Path $dir) {
        try {
            Remove-Item -Path $dir -Recurse -Force
            Write-Host "✔ Removed: $dir" -ForegroundColor Green
        } catch {
            Write-Host "✖ Failed to remove $dir (try running as Administrator)" -ForegroundColor Red
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
        Write-Host "✔ Removed toolkit dir(s) from User PATH" -ForegroundColor Green
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
        Write-Host "✔ Cleaned profile: $profilePath" -ForegroundColor Green
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
            Write-Host "✔ Removed module: $ModuleName" -ForegroundColor Green
        } catch {
            Write-Host "✖ Could not remove module $ModuleName (may be a built-in/system copy)" -ForegroundColor Yellow
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
if ($script:RemoveDeps) {
    Write-Host "`nRemoveDeps enabled - uninstalling winget dependencies..." -ForegroundColor Cyan

    function Uninstall-IfPresent {
        param([string]$cmd, [string]$wingetName)

        if (Get-Command $cmd -ErrorAction SilentlyContinue) {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                try {
                    winget uninstall --id $wingetName -e --silent
                    Write-Host "✔ Uninstalled $cmd" -ForegroundColor Green
                } catch {
                    Write-Host "✖ Failed to uninstall $cmd" -ForegroundColor Yellow
                }
            } else {
                Write-Host "winget not found. Please remove $cmd manually." -ForegroundColor Yellow
            }
        } else {
            Write-Host "$cmd not installed"
        }
    }

    Uninstall-IfPresent "yt-dlp" "yt-dlp.yt-dlp"
    Uninstall-IfPresent "ffmpeg" "Gyan.FFmpeg"
    Uninstall-IfPresent "aria2c" "aria2.aria2"
    Uninstall-IfPresent "pwsh" "Microsoft.PowerShell"
    Uninstall-IfPresent "scoop" "ScoopInstaller.Scoop"
    Uninstall-IfPresent "python" "Python.Python.3"
    Uninstall-IfPresent "git" "Git.Git"

    # lyricsgenius pip package
    if (Get-Command python -ErrorAction SilentlyContinue) {
        try {
            python -m pip uninstall -y lyricsgenius
            Write-Host "✔ Removed lyricsgenius (pip)" -ForegroundColor Green
        } catch {
            Write-Host "Could not remove lyricsgenius via pip." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "`nSkipping winget dependencies (git, python, ffmpeg, yt-dlp, aria2, scoop, pwsh)." -ForegroundColor DarkGray
    Write-Host "These are general-purpose tools other apps may rely on, so they're left installed." -ForegroundColor DarkGray
    Write-Host "To remove them too, run:" -ForegroundColor DarkGray
    Write-Host '  $script:RemoveDeps = $true; irm https://raw.githubusercontent.com/therajatshahare/ps1-scripts-win/main/uninstall.ps1 | iex' -ForegroundColor DarkGray
}

# -------------------------------
# DONE
# -------------------------------
Write-Host "`n=== Uninstall Complete ===" -ForegroundColor Green
Write-Host "Restart PowerShell to apply all changes."