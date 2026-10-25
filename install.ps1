$toolkitVersion = "1.2.11"
Write-Host "ps1-scripts-win Version: $toolkitVersion"

# ================================
# ps1-scripts-win Installer
# ================================

$ErrorActionPreference = "Stop"

# Older Windows builds (and fresh LTSC images) can default to TLS 1.0/1.1,
# which GitHub, python.org and the PowerShell Gallery refuse. Force TLS 1.2.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

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

# Portable tools (git, ffmpeg, aria2, ...) that are unpacked instead of installed
$toolsDir = Join-Path $targetDir "tools"
$binDir   = Join-Path $toolsDir "bin"

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
    "hytvideo.ps1",
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
# HELPERS
# -------------------------------
function Get-File {
    param([string]$Url, [string]$OutFile)
    # PS 5.1 draws a very slow progress bar during downloads. Silence it for
    # this call only and restore the user's setting afterwards.
    $prev = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
    } finally {
        $ProgressPreference = $prev
    }
}

function Get-GitHubAssetUrl {
    # Returns the download URL of the latest release asset whose file name
    # matches $Pattern (regex). Returns $null if nothing matches or GitHub
    # can't be reached.
    param([string]$Repo, [string]$Pattern)
    try {
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -UserAgent "ps1-scripts-win-installer"
        $asset = $rel.assets | Where-Object { $_.name -match $Pattern } | Select-Object -First 1
        if ($asset) { return $asset.browser_download_url }
    } catch {
        Write-Host "  GitHub lookup failed for $Repo : $($_.Exception.Message)" -ForegroundColor DarkGray
    }
    return $null
}

function Expand-ToolZip {
    # Downloads a zip, unpacks it to $toolsDir\<Name>, locates <Exe> inside
    # (archives often wrap files in a versioned folder) and adds its folder
    # to the user PATH.
    param([string]$Name, [string]$Url, [string]$Exe)
    $zip  = Join-Path $env:TEMP "$Name.zip"
    $dest = Join-Path $toolsDir $Name

    Get-File -Url $Url -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $dest -Force
    Remove-Item $zip -ErrorAction SilentlyContinue

    $hit = Get-ChildItem -Path $dest -Recurse -Filter $Exe -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $hit) { throw "$Exe was not found inside the $Name archive." }

    Add-ToUserPath $hit.DirectoryName
}

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

function Add-ToUserPathFirst {
    # Like Add-ToUserPath, but puts the folder at the front, so the
    # WindowsApps "python" alias can't shadow it.
    param([string]$Dir)
    if (-not $Dir) { return }

    $user  = [Environment]::GetEnvironmentVariable("Path", "User")
    $parts = @($user -split ';' | Where-Object { $_ -and $_ -ne $Dir })
    [Environment]::SetEnvironmentVariable("Path", (@($Dir) + $parts) -join ';', "User")
    $env:PATH = "$Dir;$env:PATH"
    Write-Host "✔ Added to the front of PATH: $Dir" -ForegroundColor Green
}

function Update-SessionPath {
    # Installers update the registry PATH, but this session keeps its old copy.
    # Merge the registry Machine + User PATH into the current one, no duplicates.
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user    = [Environment]::GetEnvironmentVariable("Path", "User")

    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($p in ((@($env:PATH, $machine, $user) -join ';') -split ';')) {
        if ($p -and -not $parts.Contains($p)) { $parts.Add($p) }
    }
    $env:PATH = $parts -join ';'
}

function Repair-WinGetPackagePath {
    # Some winget packages are portable ZIP extracts. winget reports them as
    # installed, but never adds their folder to PATH. Search winget's package
    # cache for the exe and add its folder to PATH.
    param([string]$Cmd, [string]$WingetName)

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

function Install-Tool {
    # Installs one command-line tool. Order of attempts:
    #   1. already on PATH                  -> done
    #   2. winget, if this machine has it   (usually NOT on LTSC)
    #   3. direct-download function $Fallback
    param(
        [string]$Cmd,
        [string]$WingetId,
        [string]$Fallback
    )

    if (Test-RealCommand $Cmd) {
        Write-Host "$Cmd already installed"
        return
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "Installing $Cmd via winget..."
        winget install --id $WingetId -e --silent --accept-package-agreements --accept-source-agreements
        $exitCode = $LASTEXITCODE

        # -1978335189 (0x8A15002B) = already installed and up to date
        if ($exitCode -eq 0 -or $exitCode -eq -1978335189) {
            if (Test-RealCommand $Cmd) {
                Write-Host "✔ $Cmd ready (winget)" -ForegroundColor Green
                return
            }
            if (Repair-WinGetPackagePath -Cmd $Cmd -WingetName $WingetId) {
                Write-Host "✔ $Cmd ready (winget, PATH repaired)" -ForegroundColor Green
                return
            }
        }
        Write-Host "winget did not install $Cmd (exit code $exitCode). Trying direct download..." -ForegroundColor Yellow
    } else {
        Write-Host "winget not found, installing $Cmd directly..." -ForegroundColor DarkGray
    }

    if (-not $Fallback) {
        Write-Host "✖ No direct-download method for $Cmd" -ForegroundColor Red
        return
    }

    try {
        & $Fallback
    } catch {
        Write-Host "✖ Direct install of $Cmd failed" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkGray
    }

    Update-SessionPath
    if (Test-RealCommand $Cmd) {
        Write-Host "✔ $Cmd installed" -ForegroundColor Green
    } else {
        Write-Host "⚠ $Cmd still not found. Restart PowerShell and run update-scripts to retry." -ForegroundColor Yellow
    }
}

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
        Get-File -Url $url -OutFile $out
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
# DEPENDENCIES - direct-download fallbacks
# -------------------------------
Write-Host "`nInstalling dependencies..." -ForegroundColor Cyan

# Portable single-file tools (yt-dlp) live in $binDir, which goes on PATH once
Add-ToUserPath $binDir

function Install-GitDirect {
    # PortableGit is a self-extracting 7z archive: no installer, no admin needed.
    $url = Get-GitHubAssetUrl -Repo "git-for-windows/git" -Pattern '^PortableGit-[\d.]+-64-bit\.7z\.exe$'
    if (-not $url) { throw "Could not find PortableGit on GitHub (GitHub blocked or rate-limited?)." }

    $exe  = Join-Path $env:TEMP "PortableGit.7z.exe"
    $dest = Join-Path $toolsDir "git"

    Get-File -Url $url -OutFile $exe
    Start-Process -FilePath $exe -ArgumentList "-y", "-o`"$dest`"" -Wait
    Remove-Item $exe -ErrorAction SilentlyContinue

    if (-not (Test-Path (Join-Path $dest "cmd\git.exe"))) { throw "PortableGit extraction failed." }
    Add-ToUserPath (Join-Path $dest "cmd")
}

function Install-YtDlpDirect {
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    Get-File -Url "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" `
             -OutFile (Join-Path $binDir "yt-dlp.exe")
}

function Install-FfmpegDirect {
    # Gyan.dev "essentials" build, the same build the winget package ships
    Expand-ToolZip -Name "ffmpeg" `
                   -Url "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip" `
                   -Exe "ffmpeg.exe"
}

function Install-Aria2Direct {
    $url = Get-GitHubAssetUrl -Repo "aria2/aria2" -Pattern '^aria2-[\d.]+-win-64bit-build\d+\.zip$'
    if (-not $url) { throw "No Windows build of aria2 found on GitHub." }
    Expand-ToolZip -Name "aria2" -Url $url -Exe "aria2c.exe"
}

function Install-FastfetchDirect {
    $url = Get-GitHubAssetUrl -Repo "fastfetch-cli/fastfetch" -Pattern '^fastfetch-windows-amd64\.zip$'
    if (-not $url) { throw "No Windows build of fastfetch found on GitHub." }
    Expand-ToolZip -Name "fastfetch" -Url $url -Exe "fastfetch.exe"
}

function Install-ExiftoolDirect {
    # Read the real download links from exiftool.org. The page can mention
    # several versions and old zips get removed from the server, so the
    # newest link is tried first and older ones only if it fails.
    $page = Invoke-WebRequest -Uri "https://exiftool.org/" -UseBasicParsing

    $links = [regex]::Matches($page.Content, 'href=["'']([^"'']*exiftool-(\d+\.\d+)_64\.zip)["'']') |
        ForEach-Object {
            [pscustomobject]@{
                Url     = [Uri]::new([Uri]"https://exiftool.org/", $_.Groups[1].Value).AbsoluteUri
                Version = [version]$_.Groups[2].Value
            }
        } |
        Sort-Object Version -Descending

    if (-not $links) { throw "No ExifTool Windows download link was found on exiftool.org." }

    $zip  = Join-Path $env:TEMP "exiftool.zip"
    $dest = Join-Path $toolsDir "exiftool"

    $downloaded = $false
    foreach ($link in $links) {
        try {
            Get-File -Url $link.Url -OutFile $zip
            $downloaded = $true
            break
        } catch {
            Write-Host "  $($link.Url) failed, trying the next link" -ForegroundColor DarkGray
        }
    }
    if (-not $downloaded) { throw "None of the ExifTool download links on exiftool.org worked." }

    Expand-Archive -Path $zip -DestinationPath $dest -Force
    Remove-Item $zip -ErrorAction SilentlyContinue

    # The zip ships "exiftool(-k).exe"; the toolkit calls plain "exiftool"
    $exe = Get-ChildItem -Path $dest -Recurse -Filter "exiftool*.exe" -File |
        Where-Object { $_.Name -match '^exiftool(\(-k\))?\.exe$' } |
        Select-Object -First 1
    if (-not $exe) { throw "exiftool.exe was not found inside the archive." }

    if ($exe.Name -ne "exiftool.exe") {
        Rename-Item -Path $exe.FullName -NewName "exiftool.exe"
    }
    Add-ToUserPath $exe.DirectoryName
}

function Install-PwshDirect {
    # Portable zip: no MSI, no admin needed
    $url = Get-GitHubAssetUrl -Repo "PowerShell/PowerShell" -Pattern '^PowerShell-[\d.]+-win-x64\.zip$'
    if (-not $url) { throw "Could not find the PowerShell 7 zip on GitHub." }
    Expand-ToolZip -Name "pwsh" -Url $url -Exe "pwsh.exe"
}

function Install-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "scoop already installed"
        return
    }

    if ($admin) {
        # Scoop's official installer refuses to run elevated by design.
        Write-Host "✖ Skipping scoop - it cannot be installed from an Administrator session." -ForegroundColor Yellow
        Write-Host "  Re-run this installer from a normal (non-Administrator) PowerShell window to get scoop." -ForegroundColor DarkGray
        return
    }

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
    if (Test-RealCommand "aria2c") {
        Write-Host "aria2c already installed"
        return
    }

    # Scoop handles portable apps well when it exists
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "Installing aria2c via scoop..."
        try { scoop install aria2 } catch {
            Write-Host "  scoop failed: $($_.Exception.Message)" -ForegroundColor DarkGray
        }
        Update-SessionPath
        if (Test-RealCommand "aria2c") {
            Write-Host "✔ aria2c ready (scoop)" -ForegroundColor Green
            return
        }
    }

    Install-Tool -Cmd "aria2c" -WingetId "aria2.aria2" -Fallback "Install-Aria2Direct"
}

function Find-PythonExe {
    # Looks in the usual install folders, in case python is installed
    # but PATH doesn't know about it yet.
    $hits = @()
    $hits += Get-ChildItem "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe" -ErrorAction SilentlyContinue
    $hits += Get-ChildItem "$env:ProgramFiles\Python3*\python.exe" -ErrorAction SilentlyContinue
    $hits += Get-ChildItem "$toolsDir\python\python.exe" -ErrorAction SilentlyContinue
    return $hits | Select-Object -First 1
}

function Install-PythonEmbedded {
    # Direct install that skips the python.org installer (msiexec), which can
    # fail silently on locked-down LTSC images. The embeddable zip is just
    # unpacked, and pip is added by hand.
    $version = "3.13.5"
    $dest    = Join-Path $toolsDir "python"
    $zip     = Join-Path $env:TEMP "python-embed.zip"

    Get-File -Url "https://www.python.org/ftp/python/$version/python-$version-embed-amd64.zip" -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $dest -Force
    Remove-Item $zip -ErrorAction SilentlyContinue

    # The embeddable build ignores site-packages (where pip and every
    # installed package live) until "import site" is switched on.
    $pth = Get-ChildItem "$dest\python*._pth" | Select-Object -First 1
    if (-not $pth) { throw "python._pth not found in the embeddable build." }
    (Get-Content $pth.FullName) -replace '^#\s*import site', 'import site' |
        Set-Content $pth.FullName -Encoding ASCII

    $py     = Join-Path $dest "python.exe"
    $getPip = Join-Path $env:TEMP "get-pip.py"
    Get-File -Url "https://bootstrap.pypa.io/get-pip.py" -OutFile $getPip
    & $py $getPip
    if ($LASTEXITCODE -ne 0) { throw "get-pip.py failed (exit code $LASTEXITCODE)." }
    Remove-Item $getPip -ErrorAction SilentlyContinue

    Add-ToUserPathFirst (Join-Path $dest "Scripts")
    Add-ToUserPathFirst $dest
}

function Install-Python {
    if (Test-RealCommand "python") {
        Write-Host "python already installed"
        return
    }

    # Python may already be installed but missing from PATH (e.g. from an earlier run)
    $found = Find-PythonExe
    if ($found) {
        Add-ToUserPathFirst $found.DirectoryName
        if (Test-RealCommand "python") {
            Write-Host "✔ python found at $($found.DirectoryName)" -ForegroundColor Green
            return
        }
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "Installing python via winget..."
        try { winget source update | Out-Null } catch {}
        winget install --id Python.Python.3 -e --source winget --silent --accept-package-agreements --accept-source-agreements
        Update-SessionPath
        if (Test-RealCommand "python") {
            Write-Host "✔ python installed (winget)" -ForegroundColor Green
            return
        }
        Write-Host "winget did not leave a working python. Trying the direct download..." -ForegroundColor Yellow
    } else {
        Write-Host "winget not found, installing python directly..." -ForegroundColor DarkGray
    }

    try {
        Install-PythonEmbedded
    } catch {
        Write-Host "✖ Direct install of python failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Install it manually from https://www.python.org/downloads/" -ForegroundColor Yellow
        return
    }

    Update-SessionPath
    if (Test-RealCommand "python") {
        Write-Host "✔ python installed (direct download)" -ForegroundColor Green
    }
}

# ---- Install the tools ----
Install-Tool -Cmd "git"       -WingetId "Git.Git"                  -Fallback "Install-GitDirect"
Install-Scoop
Install-Tool -Cmd "yt-dlp"    -WingetId "yt-dlp.yt-dlp"            -Fallback "Install-YtDlpDirect"
Install-Tool -Cmd "ffmpeg"    -WingetId "Gyan.FFmpeg"              -Fallback "Install-FfmpegDirect"
Install-Aria2
Install-Tool -Cmd "fastfetch" -WingetId "Fastfetch-cli.Fastfetch"  -Fallback "Install-FastfetchDirect"
Install-Tool -Cmd "exiftool"  -WingetId "OliverBetz.ExifTool"      -Fallback "Install-ExiftoolDirect"
Install-Python
Install-Tool -Cmd "pwsh"      -WingetId "Microsoft.PowerShell"     -Fallback "Install-PwshDirect"

# -------------------------------
# POWERSHELL MODULES
# -------------------------------
Write-Host "`nInstalling PowerShell modules..." -ForegroundColor Cyan

# NuGet is only needed by Windows PowerShell 5.1, where Install-Module asks
# for it. Skip it under PowerShell 7.
if ($PSVersionTable.PSEdition -ne 'Core') {
    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    } catch {
        Write-Host "Could not install the NuGet provider: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Install-PSModuleIfMissing {
    param([string]$ModuleName)

    $module = Get-Module -ListAvailable -Name $ModuleName

    if (-not $module) {
        Write-Host "Installing $ModuleName..."
        try {
            Install-Module $ModuleName -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
            Write-Host "✔ Installed $ModuleName" -ForegroundColor Green
        }
        catch {
            Write-Host "✖ Failed to install $ModuleName ($($_.Exception.Message))" -ForegroundColor Yellow
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
            Write-Host "✔ Scoop extras bucket already present." -ForegroundColor Yellow
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
# TOOL CHECK
# -------------------------------
Write-Host "`n=== Tool check ===" -ForegroundColor Cyan
foreach ($c in @("git", "yt-dlp", "ffmpeg", "aria2c", "fastfetch", "exiftool", "python", "pwsh")) {
    if (Test-RealCommand $c) {
        Write-Host "✔ $c" -ForegroundColor Green
    } else {
        Write-Host "✖ $c (missing)" -ForegroundColor Red
    }
}

# -------------------------------
# DONE
# -------------------------------
Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
Write-Host "Restart PowerShell to apply all changes."
