$toolkitVersion = "1.2.08"
Write-Host "ps1-scripts-win Version: $toolkitVersion"

# ================================
# ps1-scripts-win Installer
# ================================

$ErrorActionPreference = "Stop"

Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║            ps1-scripts-win           ║" -ForegroundColor Green
Write-Host "║            Setup Starting            ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Green

# -------------------------------
# CONFIG
# -------------------------------
$repoUser = "therajatshahare"
$repoName = "ps1-scripts-win"
$branch   = "main"

$baseRaw = "https://raw.githubusercontent.com/$repoUser/$repoName/$branch"

# Default admin install location
$targetDir = "C:\Windows\ps1-scripts-win"

# If not admin, install in user folder
$admin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $admin) {
    Write-Host "⚠ Not running as Administrator. Switching to user directory..." -ForegroundColor Yellow
    $targetDir = Join-Path $HOME "ps1-scripts-win"
}

# -------------------------------
# PowerShell Profile Paths
# -------------------------------

# Resolve the real Documents folder via the Known Folder API rather than
# assuming "$HOME\Documents". If the user has moved/redirected Documents
# to another drive (D:, E:, etc.), $HOME\Documents still points at the
# default C:\ location and silently writes the profile to the wrong
# (unused) file, while $PROFILE resolves to the real, redirected one.
$documentsPath = [Environment]::GetFolderPath("MyDocuments")

$profilePaths = @(
    (Join-Path $documentsPath "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"),
    (Join-Path $documentsPath "PowerShell\Microsoft.PowerShell_profile.ps1")
)

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
    "insta_fallback.py",
    "encrypt.ps1",
    "lyrics.py",
    "toolkit-help.ps1"
)

# -------------------------------
# CREATE TARGET DIRECTORY
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
    $out = Join-Path $targetDir $script

    try {
        Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
        Write-Host "✔ $script"
    } catch {
        Write-Host "✖ Failed: $script" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

# -------------------------------
# ADD TO USER PATH
# -------------------------------
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

if ([string]::IsNullOrWhiteSpace($currentPath)) {
    $currentPath = ""
}

$pathParts = $currentPath -split ';' | Where-Object { $_ -ne "" }

if ($pathParts -notcontains $targetDir) {
    $newPath = ($pathParts + $targetDir) -join ';'
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "`nAdded to PATH (User)"
} else {
    Write-Host "`nPATH already configured"
}

# Update PATH for current session also
if (($env:PATH -split ';') -notcontains $targetDir) {
    $env:PATH = "$env:PATH;$targetDir"
}

# -------------------------------
# PROFILE SETUP
# -------------------------------
Write-Host "`nConfiguring PowerShell profile..." -ForegroundColor Cyan

$profileBlock = @"
# ===== ps1-scripts-win Setup =====
`$scriptDir = "$targetDir"
`$toolkitVersion = "$toolkitVersion"
`$baseRaw = "$baseRaw"

# -------------------------------
# PowerShell Enhancements
# -------------------------------

Import-Module PSReadLine

Set-PSReadLineOption -MaximumHistoryCount 10000
Set-PSReadLineOption -BellStyle None
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

if (`$PSVersionTable.PSVersion.Major -ge 7) {
    Import-Module CompletionPredictor -ErrorAction SilentlyContinue

    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView
}

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

function aria    { & "`$scriptDir\aria.ps1" @args }
function exifpic { & "`$scriptDir\exifpic.ps1" @args }
function folders { & "`$scriptDir\folders.ps1" @args }
function insta   { & "`$scriptDir\insta.ps1" @args }
function encrypt { & "`$scriptDir\encrypt.ps1" @args }

function toolkit-version {
    Write-Host "ps1-scripts-win Version: `$toolkitVersion"
}

function update-scripts {
    irm `$baseRaw/install.ps1 | iex
}

function toolkit-help {
    & "`$scriptDir\toolkit-help.ps1" @args
}

# -------------------------------
# Fastfetch on shell start
# -------------------------------
if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
    fastfetch
}
# ===== End ps1-scripts-win Script Setup =====
"@

foreach ($profilePath in $profilePaths) {

    $profileDir = Split-Path -Parent $profilePath

    # Ensure directory exists
    if (!(Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    # Ensure profile exists
    if (!(Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }

    # Read profile
    try {
        $content = [System.IO.File]::ReadAllText($profilePath)
    }
    catch {
        $content = ""
    }

    # Remove previous toolkit block
    $content = $content -replace '(?s)# ===== ps1-scripts-win Setup =====.*?# ===== End ps1-scripts-win Script Setup =====', ''
    $content = $content -replace '(?s)# ===== ps1-scripts-win Setup =====.*?# ===== End ps1-scripts-win =====', ''

    # Append new toolkit block
    if ([string]::IsNullOrWhiteSpace($content)) {
        $newContent = $profileBlock
    }
    else {
        $newContent = $content.Trim() + "`r`n`r`n" + $profileBlock
    }

    [System.IO.File]::WriteAllText(
        $profilePath,
        $newContent,
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host "✔ Updated profile: $profilePath" -ForegroundColor Green
}

# Reload only the current PowerShell session
try {
    . $PROFILE
}
catch {
    Write-Host "Profile updated. Restart PowerShell after setup completes." -ForegroundColor Yellow
}

# -------------------------------
# CMD.EXE AUTORUN (fastfetch)
# -------------------------------
Write-Host "`nConfiguring cmd.exe startup..." -ForegroundColor Cyan

$cmdAutorunScript = Join-Path $targetDir "autorun.cmd"

$autorunContent = @"
@echo off
where fastfetch >nul 2>nul
if %errorlevel% equ 0 (
    fastfetch
)
"@

try {
    Set-Content -Path $cmdAutorunScript -Value $autorunContent -Encoding ASCII

    $autorunKeyPath = "HKCU:\Software\Microsoft\Command Processor"
    if (!(Test-Path $autorunKeyPath)) {
        New-Item -Path $autorunKeyPath -Force | Out-Null
    }

    $existingAutoRun = (Get-ItemProperty -Path $autorunKeyPath -Name AutoRun -ErrorAction SilentlyContinue).AutoRun
    $callCmd = "call `"$cmdAutorunScript`""

    if ([string]::IsNullOrWhiteSpace($existingAutoRun)) {
        # No existing AutoRun - just point it at our script
        $newAutoRun = $callCmd
    } elseif ($existingAutoRun -like "*$cmdAutorunScript*") {
        # Already configured from a previous run of this installer
        $newAutoRun = $existingAutoRun
    } else {
        # Preserve whatever the user already had AutoRun doing
        $newAutoRun = "$existingAutoRun & $callCmd"
    }

    Set-ItemProperty -Path $autorunKeyPath -Name AutoRun -Value $newAutoRun
    Write-Host "✔ cmd.exe will run fastfetch on startup" -ForegroundColor Green
} catch {
    Write-Host "✖ Failed to configure cmd.exe AutoRun" -ForegroundColor Yellow
    Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkGray
}

# -------------------------------
# EXECUTION POLICY
# -------------------------------
try {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "`nExecution policy set: RemoteSigned"
} catch {
    Write-Host "`nCould not set execution policy." -ForegroundColor Yellow
}

# -------------------------------
# DEPENDENCIES
# -------------------------------
Write-Host "`nInstalling dependencies..." -ForegroundColor Cyan

function Test-RealCommand {
    param([string]$CmdName)
    $c = Get-Command $CmdName -ErrorAction SilentlyContinue
    if (-not $c) { return $false }

    if ($c.Source -and $c.Source -like "*\WindowsApps\*") {
        # WindowsApps can hold either a real Store-installed interpreter
        # (works fine) or an empty "app execution alias" stub that just
        # opens the Microsoft Store when run. Path alone can't tell them
        # apart, so actually try running it and check for real output.
        try {
            $out = & $CmdName --version 2>&1
            if ($LASTEXITCODE -eq 0 -and $out -match '\d+\.\d+(\.\d+)?') {
                return $true
            }
        } catch {}
        return $false
    }

    return $true
}

function Add-ToUserPath {
    param([string]$Dir)

    if (-not $Dir) { return }

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $pathParts = $currentPath -split ';' | Where-Object { $_ -ne "" }

    if ($pathParts -notcontains $Dir) {
        $newPath = ($pathParts + $Dir) -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Host "✔ Added to PATH: $Dir" -ForegroundColor Green
    }

    if (($env:PATH -split ';') -notcontains $Dir) {
        $env:PATH = "$env:PATH;$Dir"
    }
}

function Repair-WinGetPackagePath {
    # Some winget packages are portable ZIP extracts rather than proper
    # installers (aria2 is one) - winget shows them as "installed" and
    # unpacks them under its own Packages folder, but never registers
    # that folder in PATH. If Test-RealCommand still can't find the exe
    # after a successful winget install, search for it under winget's
    # package cache and add its folder to PATH directly. The subfolder
    # name includes the version, so this is done by search, not by a
    # hardcoded path, and keeps working across version upgrades.
    param(
        [string]$Cmd,
        [string]$WingetName
    )

    $packagesRoot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
    if (-not (Test-Path $packagesRoot)) { return $false }

    $exeName = "$Cmd.exe"
    $match = Get-ChildItem "$packagesRoot\$WingetName*" -Recurse -Filter $exeName -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($match) {
        Add-ToUserPath $match.DirectoryName
        return (Test-RealCommand $Cmd)
    }

    return $false
}

function Install-IfMissing {
    param(
        [string]$cmd,
        [string]$wingetName
    )

    # Windows ships a fake python.exe / python3.exe under WindowsApps (the "App
    # execution alias") that Get-Command always finds even when real Python is
    # not installed - it just opens the Microsoft Store if run. Treat that as
    # "missing" so we don't skip a real install.
    if (!(Test-RealCommand $cmd)) {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "Installing $cmd..."
            winget install --id $wingetName -e --silent --accept-package-agreements --accept-source-agreements
            $exitCode = $LASTEXITCODE

            # -1978335189 (0x8A15002B) is winget's "no applicable update found",
            # which winget returns when the package is already installed and
            # up to date - not a real failure. Anything else genuinely failed.
            if ($exitCode -ne 0 -and $exitCode -ne -1978335189) {
                Write-Host "✖ Failed to install $cmd using winget (exit code $exitCode)" -ForegroundColor Yellow
                return
            }

            if (!(Test-RealCommand $cmd)) {
                # Installed (or already present) but not on PATH - likely a
                # portable/ZIP-style winget package. Try to locate and fix it.
                if (Repair-WinGetPackagePath -Cmd $cmd -WingetName $wingetName) {
                    Write-Host "✔ $cmd found and added to PATH" -ForegroundColor Green
                } else {
                    Write-Host "⚠ $cmd installed but not found on PATH. You may need to restart PowerShell or add it to PATH manually." -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "winget not found. Please install $cmd manually." -ForegroundColor Yellow
        }
    } else {
        Write-Host "$cmd already installed"
    }
}

function Update-SessionPath {
    # Installers (winget or the .exe fallback below) update the registry's
    # Machine/User PATH, but the *current* PowerShell session keeps its own
    # cached copy of $env:PATH from when it started. Without this, a freshly
    # installed tool won't be found until you close and reopen PowerShell.
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath    = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:PATH = @($machinePath, $userPath) -join ';'
}

function Install-Python {
    if (Test-RealCommand "python") {
        Write-Host "python already installed"
        return
    }

    $installed = $false

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "Installing python..."

        # "No package found matching input criteria" for a package ID that
        # definitely exists (Python.Python.3) almost always means winget's
        # local source index is stale, not that the package is missing.
        # Refreshing it first fixes this in most cases.
        try { winget source update | Out-Null } catch {}

        winget install --id Python.Python.3 -e --source winget --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            $installed = $true
            Write-Host "✔ python installed via winget" -ForegroundColor Green
        } else {
            Write-Host "✖ winget install of python failed (exit code $LASTEXITCODE)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "winget not found." -ForegroundColor Yellow
    }

    if (-not $installed) {
        # Fallback so setup doesn't depend on winget's index being healthy:
        # grab the official installer straight from python.org and run it
        # silently. This also covers machines without winget at all.
        Write-Host "Falling back to a direct download from python.org..." -ForegroundColor Cyan
        try {
            $installerUrl  = "https://www.python.org/ftp/python/3.13.5/python-3.13.5-amd64.exe"
            $installerPath = Join-Path $env:TEMP "python-installer.exe"

            Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
            Start-Process -FilePath $installerPath `
                -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_launcher=0" `
                -Wait
            Remove-Item $installerPath -ErrorAction SilentlyContinue

            $installed = $true
            Write-Host "✔ python installed via direct download" -ForegroundColor Green
        } catch {
            Write-Host "✖ Failed to install python via direct download" -ForegroundColor Red
            Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkGray
            Write-Host "  Please install it manually from https://www.python.org/downloads/" -ForegroundColor Yellow
        }
    }

    if ($installed) {
        Update-SessionPath
    }
}

function Install-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "scoop already installed"
        return
    }

    if ($admin) {
        # Scoop's official installer refuses to run under an elevated session
        # by design - it's meant to be a per-user tool with no admin
        # dependency, so it silently bails rather than install as admin.
        Write-Host "✖ Skipping scoop - it cannot be installed from an Administrator session." -ForegroundColor Yellow
        Write-Host "  This is intentional on Scoop's part, not a bug here." -ForegroundColor DarkGray
        Write-Host "  Re-run this installer from a normal (non-Administrator) PowerShell window to get scoop." -ForegroundColor DarkGray
        return
    }

    # Scoop is not reliably published on winget (its manifest submission was
    # never accepted into winget-pkgs), so it must be installed via its own
    # official bootstrap script instead of "winget install".
    Write-Host "Installing scoop..."
    try {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    } catch {
        Write-Host "✖ Failed to install scoop" -ForegroundColor Yellow
        Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

function Install-Aria2 {
    # aria2's winget package (aria2.aria2) is a portable ZIP extract, not a
    # real installer - winget marks it "installed" but never registers its
    # folder in PATH, and that folder's name changes on every version bump.
    # Scoop, on the other hand, is built exactly for portable apps: it adds
    # one shims folder to PATH once and repoints a "current" symlink per app
    # on every update, so aria2c keeps working across upgrades with no
    # extra repair step. Prefer scoop when it's available; fall back to
    # winget (with PATH repair) only when scoop isn't usable, e.g. an
    # Administrator session, where Install-Scoop above intentionally skips.
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        if (Get-Command aria2c -ErrorAction SilentlyContinue) {
            Write-Host "aria2c already installed"
        } else {
            Write-Host "Installing aria2c via scoop..."
            try {
                scoop install aria2
            } catch {
                Write-Host "✖ Failed to install aria2c via scoop" -ForegroundColor Yellow
                Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Host "Scoop not available, falling back to winget for aria2c..." -ForegroundColor DarkGray
        Install-IfMissing "aria2c" "aria2.aria2"
    }
}

Install-IfMissing "git" "Git.Git"
Install-Scoop
Install-IfMissing "yt-dlp" "yt-dlp.yt-dlp"
Install-IfMissing "ffmpeg" "Gyan.FFmpeg"
Install-Aria2
Install-IfMissing "fastfetch" "Fastfetch-cli.Fastfetch"
Install-IfMissing "exiftool" "OliverBetz.ExifTool"
Install-Python

# -------------------------------
# POWERSHELL 7
# -------------------------------
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {

    Write-Host "PowerShell 7 not found. Installing..." -ForegroundColor Cyan

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            winget install --id Microsoft.PowerShell -e --silent --accept-package-agreements --accept-source-agreements
            Write-Host "✔ PowerShell 7 installed." -ForegroundColor Green
            Write-Host "Restart PowerShell after setup to use the new features." -ForegroundColor Yellow
        }
        catch {
            Write-Host "✖ Failed to install PowerShell 7." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "winget not found. Please install PowerShell 7 manually." -ForegroundColor Yellow
    }

}
else {
    Write-Host "PowerShell 7 already installed"
}

# -------------------------------
# POWERSHELL MODULES
# -------------------------------
Write-Host "`nInstalling PowerShell modules..." -ForegroundColor Cyan

function Install-PSModuleIfMissing {
    param(
        [string]$ModuleName
    )

    $module = Get-Module -ListAvailable -Name $ModuleName

    if (-not $module) {
        Write-Host "Installing $ModuleName..."

        try {
            Install-Module $ModuleName `
                -Scope CurrentUser `
                -Repository PSGallery `
                -Force `
                -AllowClobber

            Write-Host "✔ Installed $ModuleName" -ForegroundColor Green
        }
        catch {
            Write-Host "✖ Failed to install $ModuleName" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "$ModuleName already installed"
    }
}

Install-PSModuleIfMissing "PSReadLine"
Install-PSModuleIfMissing "CompletionPredictor"

# -------------------------------
# SCOOP EXTRAS BUCKET
# -------------------------------
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "`nConfiguring Scoop buckets..." -ForegroundColor Cyan

    try {
        $buckets = scoop bucket list | Out-String

        if ($buckets -match '(?m)^\s*extras\b') {
            Write-Host "WARN  The 'extras' bucket already exists. To add this bucket again, first remove it by running 'scoop bucket rm extras'." -ForegroundColor Yellow
            Write-Host "✔ Skipping Scoop extras bucket." -ForegroundColor Yellow
        }
        else {
            scoop bucket add extras
            Write-Host "✔ Added Scoop extras bucket." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "✖ Failed to configure Scoop extras bucket." -ForegroundColor Red
    }
}

# -------------------------------
# PYTHON PACKAGES
# -------------------------------
Update-SessionPath

if (Test-RealCommand "python") {
    try {
        python -m pip install --upgrade pip
    } catch {
        Write-Host "Could not upgrade pip." -ForegroundColor Yellow
    }

    try {
        python -m pip install lyricsgenius
    } catch {
        Write-Host "Could not install lyricsgenius." -ForegroundColor Yellow
    }

    try {
        python -m pip install instaloader
    } catch {
        Write-Host "Could not install instaloader." -ForegroundColor Yellow
    }
} else {
    Write-Host "Python still not detected. Restart PowerShell and run 'update-scripts' again to retry." -ForegroundColor Yellow
}

# -------------------------------
# DONE
# -------------------------------
Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
Write-Host "Restart PowerShell to apply all changes."
