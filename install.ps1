$toolkitVersion = "1.2.05"
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

# PowerShell profile path for current PowerShell version
# Windows PowerShell 5.1 = Documents\WindowsPowerShell
# PowerShell 7+ = Documents\PowerShell
$profilePath = $PROFILE
$profileDir  = Split-Path -Parent $profilePath

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
# ENSURE PROFILE DIRECTORY / FILE
# -------------------------------
if (!(Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

if (!(Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
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

try {
    Import-Module PSReadLine -ErrorAction Stop

    # Optional: Load smarter command predictions
    Import-Module CompletionPredictor -ErrorAction SilentlyContinue

    Set-PSReadLineOption -MaximumHistoryCount 10000
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -BellStyle None

    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

}

catch {
    Write-Host "PSReadLine could not be loaded." -ForegroundColor Yellow
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
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
# ===== End ps1-scripts-win Script Setup =====
"@

# Read profile safely as one string
try {
    $content = [System.IO.File]::ReadAllText($profilePath)
} catch {
    $content = ""
}

# Remove old/broken ps1-scripts-win blocks
$content = $content -replace '(?s)# ===== ps1-scripts-win Setup =====.*?# ===== End ps1-scripts-win Script Setup =====', ''
$content = $content -replace '(?s)# ===== ps1-scripts-win Setup =====.*?# ===== End ps1-scripts-win =====', ''

# Write clean profile
if ([string]::IsNullOrWhiteSpace($content)) {
    $newContent = $profileBlock
} else {
    $newContent = $content.Trim() + "`r`n`r`n" + $profileBlock
}

[System.IO.File]::WriteAllText(
    $profilePath,
    $newContent,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Profile updated successfully" -ForegroundColor Green
Write-Host "Profile path: $profilePath" -ForegroundColor DarkGray

# Reload profile safely
try {
    . $profilePath
} catch {
    Write-Host "Profile updated, but could not be reloaded in this session." -ForegroundColor Yellow
    Write-Host "Restart PowerShell after setup completes." -ForegroundColor Yellow
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

function Install-IfMissing {
    param(
        [string]$cmd,
        [string]$wingetName
    )

    if (!(Get-Command $cmd -ErrorAction SilentlyContinue)) {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "Installing $cmd..."
            try {
                winget install --id $wingetName -e --silent --accept-package-agreements --accept-source-agreements
            } catch {
                Write-Host "✖ Failed to install $cmd using winget" -ForegroundColor Yellow
            }
        } else {
            Write-Host "winget not found. Please install $cmd manually." -ForegroundColor Yellow
        }
    } else {
        Write-Host "$cmd already installed"
    }
}

Install-IfMissing "git" "Git.Git"
Install-IfMissing "scoop" "ScoopInstaller.Scoop"
Install-IfMissing "yt-dlp" "yt-dlp.yt-dlp"
Install-IfMissing "ffmpeg" "Gyan.FFmpeg"
Install-IfMissing "aria2c" "aria2.aria2"
Install-IfMissing "python" "Python.Python.3"

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
if (Get-Command python -ErrorAction SilentlyContinue) {
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
} else {
    Write-Host "Python not found in current session. Restart PowerShell and check again." -ForegroundColor Yellow
}

# -------------------------------
# DONE
# -------------------------------
Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
Write-Host "Restart PowerShell to apply all changes."
