$toolkitVersion = "1.0.1"
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
"lyrics.py"
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
$out = "$targetDir$script"

```
try {
    Invoke-WebRequest $url -OutFile $out -UseBasicParsing
    Write-Host "✔ $script"
} catch {
    Write-Host "✖ Failed: $script" -ForegroundColor Red
}
```

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

# PROFILE SETUP (AUTO DISCOVERY)

# -------------------------------

Write-Host "`nConfiguring PowerShell profile..." -ForegroundColor Cyan

$profileBlock = @"

# ===== Cmd-Scripts Setup =====

`$scriptDir = "`$HOME\cmd-scripts"

if (!(Test-Path `$scriptDir)) {
    Write-Host "Warning: Script directory not found: `$scriptDir" -ForegroundColor Red
}

# -------------------------------

# AUTO DISCOVERY (PS1)

# -------------------------------

Get-ChildItem "`$scriptDir\*.ps1" -File | ForEach-Object {
    `$name = [System.IO.Path]::GetFileNameWithoutExtension(`$_.Name)

```
Set-Item -Path "function:`$name" -Value {
    param(`$args)
    & "`$scriptDir\`$name.ps1" @args
}
```

}

# -------------------------------

# AUTO DISCOVERY (PYTHON)

# -------------------------------

Get-ChildItem "`$scriptDir\*.py" -File | ForEach-Object {
    `$name = [System.IO.Path]::GetFileNameWithoutExtension(`$_.Name)

```
Set-Item -Path "function:`$name" -Value {
    param(`$args)
    python "`$scriptDir\`$name.py" @args
}
```

}

# -------------------------------

# CUSTOM COMMAND (KEEP)

# -------------------------------

function insta {
param(
[Parameter(Mandatory = `$true)]         [string]`$Username,

```
    [ValidateSet("full","update")]
    [string]`$Mode = "full"
)

& "`$scriptDir\insta.ps1" -Username `$Username -Mode `$Mode
```

}

# -------------------------------

# TOOLKIT COMMANDS

# -------------------------------

function toolkit-version {
Write-Host "Cmd-Scripts Version: $($toolkitVersion)"
}

function update-scripts {
irm https://raw.githubusercontent.com/$repoUser/$repoName/$branch/install.ps1 | iex
}

function toolkit-help {
Write-Host "`nAvailable Commands:`n" -ForegroundColor Cyan
Get-ChildItem "`$scriptDir\*.ps1","`$scriptDir*.py" |
Select-Object -ExpandProperty BaseName |
Sort-Object
}

# ===== End Cmd-Scripts =====

"@

# Ensure profile exists

if (!(Test-Path $profilePath)) {
New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

# Read profile

try {
$content = Get-Content $profilePath -Raw -ErrorAction Stop
} catch {
$content = ""
}

# Remove old block

$content = $content -replace '(?s)# ===== Cmd-Scripts Setup =====.*?# ===== End Cmd-Scripts =====', ''

# Write new block

$newContent = $content.Trim() + "`n`n" + $profileBlock
Set-Content -Path $profilePath -Value $newContent -Encoding UTF8

Write-Host "Profile updated successfully" -ForegroundColor Green

# Reload profile

. $PROFILE

# -------------------------------

# EXECUTION POLICY

# -------------------------------

Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# -------------------------------

# DEPENDENCIES

# -------------------------------

Write-Host "`nInstalling dependencies..." -ForegroundColor Cyan

function Install-IfMissing {
param($cmd, $wingetName)

```
if (!(Get-Command $cmd -ErrorAction SilentlyContinue)) {
    Write-Host "Installing $cmd..."
    winget install --id $wingetName -e --silent
} else {
    Write-Host "$cmd already installed"
}
```

}

Install-IfMissing "yt-dlp" "yt-dlp.yt-dlp"
Install-IfMissing "ffmpeg" "Gyan.FFmpeg"
Install-IfMissing "aria2c" "aria2.aria2"
Install-IfMissing "python" "Python.Python.3"

try { python -m pip install --upgrade pip } catch {}
try { python -m pip install lyricsgenius } catch {}

Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
