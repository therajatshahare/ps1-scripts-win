$toolkitVersion = "1.0.0"
Write-Host "Cmd-Scripts Version: $toolkitVersion"
# ================================
# Personal Cmd-Scripts Installer
# ================================

$ErrorActionPreference = "Stop"

Write-Host "=== Cmd-Scripts Setup Starting ===" -ForegroundColor Cyan

# -------------------------------
# CONFIG
# -------------------------------
$repoUser = "therajatshahare"
$repoName = "cmd-scripts"
$branch   = "main"

$baseRaw = "https://raw.githubusercontent.com/$repoUser/$repoName/$branch"

# Target paths
$targetDir = "C:\Windows\cmd-scripts"
$profileDir = "$HOME\Documents\PowerShell"
$profilePath = $PROFILE

# Script list
$scripts = @(
    "ytvideo.ps1",
    "vytvideo.ps1",
    "ytaudio.ps1",
    "showmeta.ps1",
    "showlyrics.ps1",
    "showformat.ps1",
    "hide.ps1",
    "unhide.ps1",
    "update.ps1",
    "upgrade.ps1",
    "aria.ps1",
    "exifpic.ps1",
    "folders.ps1",
    "insta.ps1",
    "lyrics.py",
    "toolkit-help.ps1"
)

# -------------------------------
# ADMIN CHECK
# -------------------------------
$admin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $admin) {
    Write-Host "⚠ Not running as Administrator. Switching to user directory..." -ForegroundColor Yellow
    $targetDir = "$HOME\cmd-scripts"
}

# -------------------------------
# CREATE DIRECTORY
# -------------------------------
if (!(Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Write-Host "Created: $targetDir"
} else {
    Write-Host "Directory exists: $targetDir"
}

# -------------------------------
# DOWNLOAD SCRIPTS
# -------------------------------
Write-Host "`nDownloading scripts..." -ForegroundColor Cyan

foreach ($script in $scripts) {
    $url = "$baseRaw/scripts/$script"
    $out = "$targetDir\$script"

    try {
        Invoke-WebRequest $url -OutFile $out -UseBasicParsing
        Write-Host "✔ $script"
    } catch {
        Write-Host "✖ Failed: $script" -ForegroundColor Red
    }
}

# -------------------------------
# ADD TO PATH
# -------------------------------
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")

if ($currentPath -notlike "*$targetDir*") {
    [Environment]::SetEnvironmentVariable(
        "PATH",
        "$currentPath;$targetDir",
        "User"
    )
    Write-Host "`nAdded to PATH (User)"
} else {
    Write-Host "`nPATH already configured"
}

# -------------------------------
# ENSURE PROFILE DIRECTORY
# -------------------------------
if (!(Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# -------------------------------
# PROFILE SETUP (SMART)
# -------------------------------
Write-Host "`nConfiguring PowerShell profile..." -ForegroundColor Cyan

$profileBlock = @"
# ===== Cmd-Scripts Setup =====
`$scriptDir = "$targetDir"

if (!(Test-Path `$scriptDir)) {
    Write-Host "Warning: Script directory not found: `$scriptDir" -ForegroundColor Red
}

function ytvideo   { & "`$scriptDir\ytvideo.ps1" @args }
function vytvideo  { & "`$scriptDir\vytvideo.ps1" @args }
function ytaudio   { & "`$scriptDir\ytaudio.ps1" @args }

function showmeta   { & "`$scriptDir\showmeta.ps1" @args }
function showlyrics { & "`$scriptDir\showlyrics.ps1" @args }
function showformat { & "`$scriptDir\showformat.ps1" @args }

function hide   { & "`$scriptDir\hide.ps1" @args }
function unhide { & "`$scriptDir\unhide.ps1" @args }

function update-tools  { & "`$scriptDir\update.ps1" @args }
function upgrade-tools { & "`$scriptDir\upgrade.ps1" @args }

function aria     { & "`$scriptDir\aria.ps1" @args }
function exifpic  { & "`$scriptDir\exifpic.ps1" @args }
function folders  { & "`$scriptDir\folders.ps1" @args }
function insta    { & "`$scriptDir\insta.ps1" @args }

function toolkit-version {
    Write-Host "Cmd-Scripts Version: $($toolkitVersion)"
}

function update-scripts {
    irm $baseRaw/install.ps1 | iex
}

function toolkit-help {
    & "$scriptDir\toolkit-help.ps1" @args
}

# ===== End Cmd-Scripts =====
"@

# Ensure profile file exists
if (!(Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

# Read safely
$content = ""
try {
    $content = Get-Content $profilePath -Raw
} catch {}

# Remove old block if exists
$content = $content -replace '(?s)# ===== Cmd-Scripts Setup =====.*?# ===== End Cmd-Scripts =====', ''

# Write everything cleanly (CRITICAL FIX)
$newContent = $content.Trim() + "`n`n" + $profileBlock

Set-Content -Path $profilePath -Value $newContent -Encoding UTF8

Write-Host "Profile updated successfully" -ForegroundColor Green

# Reload profile
. $PROFILE

# -------------------------------
# EXECUTION POLICY
# -------------------------------
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Write-Host "`nExecution policy set (RemoteSigned)"

# -------------------------------
# DEPENDENCIES
# -------------------------------
Write-Host "`nInstalling dependencies..." -ForegroundColor Cyan

function Install-IfMissing {
    param($cmd, $wingetName)

    if (!(Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "Installing $cmd..."
        winget install --id $wingetName -e --silent
    } else {
        Write-Host "$cmd already installed"
    }
}

Install-IfMissing "yt-dlp" "yt-dlp.yt-dlp"
Install-IfMissing "ffmpeg" "Gyan.FFmpeg"
Install-IfMissing "aria2c" "aria2.aria2"
Install-IfMissing "python" "Python.Python.3"

# Python packages
try { python -m pip install --upgrade pip } catch {}
try { python -m pip install lyricsgenius } catch {}

# -------------------------------
# DONE
# -------------------------------
Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
Write-Host "Restart PowerShell to apply changes."
