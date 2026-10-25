<#
.SYNOPSIS
    Uninstaller for ps1-scripts-win (undoes install.ps1 v1.2.12)

.DESCRIPTION
    Removes everything install.ps1 adds:
      - The toolkit folder (C:\Windows\ps1-scripts-win or $HOME\ps1-scripts-win).
        This includes the portable tools the installer unpacked under tools\
        (git, ffmpeg, aria2, fastfetch, exiftool, pwsh, yt-dlp, embedded python).
      - Its User PATH entries, plus the PATH entries for any dependency this
        script removes
      - The toolkit block in both PowerShell profile files. A profile file is
        deleted if nothing else is left in it.
      - The cmd.exe AutoRun entry that runs fastfetch
      - The CurrentUser execution policy the installer set to RemoteSigned
      - The CompletionPredictor module
      - The pip packages lyricsgenius and instaloader, if Python is kept
      - System-wide dependencies the installer may have added (Git, Python,
        FFmpeg, yt-dlp, aria2, fastfetch, ExifTool, Scoop, PowerShell 7).
        You are asked first, and everything is kept by default, because other
        software may use these.

    Left in place on purpose: PSReadLine (built into PowerShell), the NuGet
    package provider (shared by all module installs), and any dependency you
    choose to keep.

.USAGE
    irm https://raw.githubusercontent.com/therajatshahare/ps1-scripts-win/main/uninstall.ps1 | iex

    To skip the dependency prompt, set one of these before running the command:
    $script:RemoveDeps = $false   # keep system-wide dependencies
    $script:RemoveDeps = $true    # remove system-wide dependencies
#>

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Red
Write-Host "           ps1-scripts-win              " -ForegroundColor Red
Write-Host "          Uninstall Starting            " -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red

# -------------------------------
# CONFIG
# -------------------------------
$adminDir    = "C:\Windows\ps1-scripts-win"
$userDir     = Join-Path $HOME "ps1-scripts-win"
$toolFolders = @($adminDir, $userDir)

# Scoop installs to $env:SCOOP when set, otherwise ~\scoop
$scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $HOME "scoop" }

# Same Known Folder lookup as install.ps1, so the same profile files are cleaned
$documentsPath = [Environment]::GetFolderPath("MyDocuments")
$profilePaths = @(
    (Join-Path $documentsPath "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"),
    (Join-Path $documentsPath "PowerShell\Microsoft.PowerShell_profile.ps1")
)

# The tools install.ps1 installs. Scoop = Scoop package name, if one applies.
$depTable = @(
    @{ Cmd = "git";       Name = "Git";          Winget = "Git.Git";                 Scoop = "git" }
    @{ Cmd = "python";    Name = "Python";       Winget = "Python.Python.3";         Scoop = $null }
    @{ Cmd = "ffmpeg";    Name = "FFmpeg";       Winget = "Gyan.FFmpeg";             Scoop = "ffmpeg" }
    @{ Cmd = "yt-dlp";    Name = "yt-dlp";       Winget = "yt-dlp.yt-dlp";           Scoop = "yt-dlp" }
    @{ Cmd = "aria2c";    Name = "aria2";        Winget = "aria2.aria2";             Scoop = "aria2" }
    @{ Cmd = "fastfetch"; Name = "fastfetch";    Winget = "Fastfetch-cli.Fastfetch"; Scoop = "fastfetch" }
    @{ Cmd = "exiftool";  Name = "ExifTool";     Winget = "OliverBetz.ExifTool";     Scoop = "exiftool" }
    @{ Cmd = "pwsh";      Name = "PowerShell 7"; Winget = "Microsoft.PowerShell";    Scoop = $null }
    @{ Cmd = "scoop";     Name = "Scoop";        Winget = $null;                     Scoop = $null }
)

# -------------------------------
# HELPERS
# -------------------------------
function Test-RealCommand {
    # The WindowsApps folder holds Store "app execution alias" stubs (python.exe
    # etc.) that Get-Command finds even when nothing is installed. Ignore them.
    param([string]$CmdName)
    $c = Get-Command $CmdName -ErrorAction SilentlyContinue
    if (-not $c) { return $false }
    if ($c.Source -and $c.Source -like "*\WindowsApps\*") { return $false }
    return $true
}

function Get-CommandPath {
    param([string]$CmdName)
    if (-not (Test-RealCommand $CmdName)) { return $null }
    return (Get-Command $CmdName -ErrorAction SilentlyContinue).Source
}

function Test-InFolder {
    # True if $Path is $Folder itself or anything inside it
    param([string]$Path, [string]$Folder)
    if (-not $Path -or -not $Folder) { return $false }
    $p = $Path.TrimEnd('\')
    $f = $Folder.TrimEnd('\')
    return ($p -eq $f) -or $p.StartsWith("$f\", [StringComparison]::OrdinalIgnoreCase)
}

function Test-InAnyFolder {
    param([string]$Path, [string[]]$Folders)
    foreach ($f in $Folders) {
        if (Test-InFolder -Path $Path -Folder $f) { return $true }
    }
    return $false
}

function Remove-FromPath {
    # Removes PATH entries that equal, or sit inside, any of $Folders.
    # Changes the User PATH (saved) and the current session.
    param([string[]]$Folders)
    $Folders = @($Folders | Where-Object { $_ })
    if ($Folders.Count -eq 0) { return }

    $userParts = @([Environment]::GetEnvironmentVariable("Path", "User") -split ';' | Where-Object { $_ })
    $kept      = @($userParts | Where-Object { -not (Test-InAnyFolder -Path $_ -Folders $Folders) })
    $removed   = $userParts.Count - $kept.Count

    if ($removed -gt 0) {
        [Environment]::SetEnvironmentVariable("Path", ($kept -join ';'), "User")
        $word = if ($removed -eq 1) { "entry" } else { "entries" }
        Write-Host "[OK] Removed $removed $word from the User PATH" -ForegroundColor Green
    } else {
        Write-Host "No matching User PATH entries"
    }

    $env:PATH = (@($env:PATH -split ';') | Where-Object {
        $_ -and -not (Test-InAnyFolder -Path $_ -Folders $Folders)
    }) -join ';'
}

function Remove-ProfileBlock {
    param([string]$ProfilePath)
    if (-not (Test-Path $ProfilePath)) { return }

    $original = [System.IO.File]::ReadAllText($ProfilePath)

    # install.ps1 used one of two end markers over time. Remove either.
    $content = $original -replace '(?s)\s*# ===== ps1-scripts-win Setup =====.*?# ===== End ps1-scripts-win Script Setup =====\s*', "`r`n"
    $content = $content -replace '(?s)\s*# ===== ps1-scripts-win Setup =====.*?# ===== End ps1-scripts-win =====\s*', "`r`n"

    if ($content -eq $original) {
        Write-Host "No toolkit block in: $ProfilePath"
        return
    }

    $content = $content.Trim()
    $dir = Split-Path -Parent $ProfilePath

    if ($content -eq "") {
        # Nothing else is in the file, so remove it and its folder if that is empty too
        Remove-Item $ProfilePath -Force
        Write-Host "[OK] Removed empty profile: $ProfilePath" -ForegroundColor Green
        if ((Test-Path $dir) -and -not (Get-ChildItem -Path $dir -Force | Select-Object -First 1)) {
            Remove-Item $dir -Force
            Write-Host "[OK] Removed empty folder: $dir" -ForegroundColor Green
        }
    } else {
        [System.IO.File]::WriteAllText($ProfilePath, $content, [System.Text.UTF8Encoding]::new($false))
        Write-Host "[OK] Removed toolkit block from: $ProfilePath" -ForegroundColor Green
    }
}

function Remove-ToolkitAutoRun {
    $keyPath = "HKCU:\Software\Microsoft\Command Processor"
    if (-not (Test-Path $keyPath)) { Write-Host "No cmd.exe AutoRun key"; return }

    $current = (Get-ItemProperty -Path $keyPath -Name AutoRun -ErrorAction SilentlyContinue).AutoRun
    if (-not $current) { Write-Host "No cmd.exe AutoRun set"; return }

    # install.ps1 adds: call "<dir>\autorun.cmd", either alone or joined with " & "
    $call = 'call\s+"[^"]*ps1-scripts-win[\\/]autorun\.cmd"'
    $new  = [regex]::Replace($current, '\s*&\s*' + $call, '')
    $new  = [regex]::Replace($new, '^\s*' + $call + '\s*(&\s*)?', '').Trim()

    if ($new -eq $current.Trim()) { Write-Host "AutoRun has no toolkit entry"; return }

    if ($new) {
        Set-ItemProperty -Path $keyPath -Name AutoRun -Value $new
        Write-Host "[OK] Removed the toolkit call from cmd.exe AutoRun (other entries kept)" -ForegroundColor Green
    } else {
        Remove-ItemProperty -Path $keyPath -Name AutoRun
        Write-Host "[OK] Removed cmd.exe AutoRun" -ForegroundColor Green
        if ((Get-Item -Path $keyPath).Property.Count -eq 0) {
            Remove-Item -Path $keyPath -ErrorAction SilentlyContinue
        }
    }
}

function Uninstall-PythonOrg {
    # python.org installers register an uninstaller under the Uninstall key.
    # winget can't remove them, so run that uninstaller silently.
    $entries = Get-ItemProperty -Path @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    ) -ErrorAction SilentlyContinue | Where-Object {
        $_.UninstallString -and (
            $_.Publisher -like "*Python Software Foundation*" -or $_.DisplayName -like "Python 3*"
        )
    }

    $commands = @($entries | Select-Object -ExpandProperty UninstallString -Unique)
    if ($commands.Count -eq 0) {
        Write-Host "  No Python uninstall entry found in the registry." -ForegroundColor DarkGray
        return
    }

    foreach ($cmd in $commands) {
        if ($cmd -match '^\s*"?(.+?\.exe)"?\s*(.*)$') {
            $exe   = $Matches[1]
            $extra = $Matches[2]
            # Windows lists MSI removals as "/I"; the removal switch is "/X"
            if ($exe -match 'msiexec') { $extra = $extra -replace '/I', '/X' }
            Start-Process -FilePath $exe -ArgumentList "$extra /quiet /norestart" -Wait
        }
    }
}

# -------------------------------
# 1. CHECK DEPENDENCIES
# -------------------------------
Write-Host "`nChecking dependencies..." -ForegroundColor Cyan

$wingetAvailable = [bool](Get-Command winget -ErrorAction SilentlyContinue)

$deps = foreach ($d in $depTable) {
    $src    = Get-CommandPath $d.Cmd
    $state  = "missing"
    $method = "none"

    if ($src) {
        if (Test-InAnyFolder -Path $src -Folders $toolFolders) {
            $state = "toolkit";   $method = "folder"       # removed with the toolkit folder
        }
        elseif ($d.Cmd -eq "pwsh" -and (Test-InFolder -Path $src -Folder $PSHOME)) {
            $state = "running";   $method = "none"         # the shell running this script
        }
        elseif ($d.Cmd -eq "scoop") {
            $state = "system";    $method = "scoop-self"
        }
        elseif (Test-InFolder -Path $src -Folder $scoopRoot) {
            $state = "system";    $method = "scoop-app"
        }
        elseif ($d.Cmd -eq "python" -and $src -like "*\Programs\Python\*") {
            $state = "system";    $method = "python-org"
        }
        else {
            $state = "system";    $method = "winget"
        }
    }

    [pscustomobject]@{
        Cmd    = $d.Cmd
        Name   = $d.Name
        Winget = $d.Winget
        Scoop  = $d.Scoop
        Source = $src
        State  = $state
        Method = $method
    }
}

foreach ($d in ($deps | Where-Object { $_.State -ne 'system' })) {
    switch ($d.State) {
        'toolkit' { $text = "inside the toolkit folder (removed with it)" }
        'running' { $text = "the shell running this script (kept; remove it later from Settings > Apps)" }
        default   { $text = "not installed" }
    }
    Write-Host ("  {0,-14} {1}" -f $d.Name, $text)
}

# -------------------------------
# 2. CHOOSE SYSTEM-WIDE DEPENDENCIES TO REMOVE
# -------------------------------
$systemDeps = @($deps | Where-Object { $_.State -eq 'system' })
$selected   = @()

if ($systemDeps.Count -gt 0) {
    Write-Host "`nInstalled system-wide. Other software may use these, so they are kept unless you choose otherwise:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $systemDeps.Count; $i++) {
        Write-Host ("  [{0}] {1,-14} {2}" -f ($i + 1), $systemDeps[$i].Name, $systemDeps[$i].Source)
    }
    if ($systemDeps | Where-Object { $_.Method -eq 'scoop-self' }) {
        Write-Host "  Removing Scoop also deletes every app installed through it." -ForegroundColor DarkGray
    }
    Write-Host ""

    if (Test-Path variable:script:RemoveDeps) {
        if ($script:RemoveDeps) {
            $selected = $systemDeps
            Write-Host "RemoveDeps = `$true, so all of them will be removed." -ForegroundColor Yellow
        } else {
            Write-Host "RemoveDeps = `$false, so all of them will be kept." -ForegroundColor DarkGray
        }
    }
    elseif ([Environment]::UserInteractive) {
        Write-Host "Enter numbers to remove (e.g. 1,3), 'all', or press Enter to keep them all:" -ForegroundColor Cyan
        $answer = Read-Host ">"
        if ($answer -match '^\s*all\s*$') {
            $selected = $systemDeps
        }
        elseif ($answer -match '\d') {
            $idx = @($answer -split ',' | ForEach-Object { $_.Trim() } |
                Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ - 1 })
            $selected = @($idx | Where-Object { $_ -ge 0 -and $_ -lt $systemDeps.Count } |
                ForEach-Object { $systemDeps[$_] })
        }
    }
}

# -------------------------------
# 3. PIP PACKAGES THE TOOLKIT ADDED
# -------------------------------
Write-Host "`nPython packages..." -ForegroundColor Cyan
$pythonDep   = $deps | Where-Object { $_.Cmd -eq "python" } | Select-Object -First 1
$pythonGoing = [bool]($selected | Where-Object { $_.Cmd -eq "python" })

if ($pythonDep.State -eq "system" -and -not $pythonGoing) {
    python -m pip uninstall -y lyricsgenius instaloader 2>&1 | Out-Null
    Write-Host "[OK] Removed pip packages lyricsgenius and instaloader (Python kept)" -ForegroundColor Green
}
elseif ($pythonDep.State -eq "toolkit") {
    Write-Host "Python is inside the toolkit folder, so its packages go with it"
}
elseif ($pythonGoing) {
    Write-Host "Python is being removed, so its packages go with it"
}
else {
    Write-Host "Python not installed, nothing to do"
}

# -------------------------------
# 4. TOOLKIT FOLDERS
# -------------------------------
Write-Host "`nRemoving the toolkit folder..." -ForegroundColor Cyan

foreach ($dir in $toolFolders) {
    if (-not (Test-Path $dir)) {
        Write-Host "Not present: $dir"
        continue
    }
    try {
        Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
        Write-Host "[OK] Removed: $dir" -ForegroundColor Green
    } catch {
        Write-Host "[FAIL] Could not fully remove $dir" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkGray
        if ($dir -eq $adminDir) {
            Write-Host "  $adminDir needs an Administrator PowerShell window to remove." -ForegroundColor DarkGray
        }
        Write-Host "  If a file is in use (for example pwsh.exe, if you are running this from the toolkit's PowerShell 7), close that program and delete the folder by hand." -ForegroundColor DarkGray
    }
}

# -------------------------------
# 5. POWERSHELL PROFILES
# -------------------------------
Write-Host "`nCleaning PowerShell profiles..." -ForegroundColor Cyan
foreach ($p in $profilePaths) {
    Remove-ProfileBlock -ProfilePath $p
}

# -------------------------------
# 6. CMD.EXE AUTORUN
# -------------------------------
Write-Host "`nCleaning cmd.exe AutoRun..." -ForegroundColor Cyan
Remove-ToolkitAutoRun

# -------------------------------
# 7. EXECUTION POLICY
# -------------------------------
Write-Host "`nResetting execution policy..." -ForegroundColor Cyan
try {
    $policy = Get-ExecutionPolicy -Scope CurrentUser
    if ($policy -eq 'RemoteSigned') {
        Set-ExecutionPolicy -ExecutionPolicy Undefined -Scope CurrentUser -Force
        Write-Host "[OK] CurrentUser execution policy reset to default (it was RemoteSigned)" -ForegroundColor Green
        Write-Host "  If you had RemoteSigned before installing, restore it with: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor DarkGray
    } else {
        Write-Host "CurrentUser execution policy is '$policy', leaving it alone"
    }
} catch {
    Write-Host "[FAIL] Could not reset the execution policy: $($_.Exception.Message)" -ForegroundColor Yellow
}

# -------------------------------
# 8. POWERSHELL MODULES
# -------------------------------
Write-Host "`nRemoving PowerShell modules..." -ForegroundColor Cyan

# Unload first, since the profile loaded it into this session
Remove-Module CompletionPredictor -Force -ErrorAction SilentlyContinue

if (Get-Module -ListAvailable -Name CompletionPredictor) {
    try {
        Uninstall-Module CompletionPredictor -AllVersions -Force -ErrorAction Stop
        Write-Host "[OK] Removed module: CompletionPredictor" -ForegroundColor Green
    } catch {
        Write-Host "[FAIL] Could not remove CompletionPredictor: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "CompletionPredictor not installed"
}
Write-Host "PSReadLine is built into PowerShell, so it is left in place." -ForegroundColor DarkGray

# -------------------------------
# 9. SELECTED DEPENDENCIES
# -------------------------------
Write-Host "`nRemoving selected dependencies..." -ForegroundColor Cyan

$pathCleanup = @()

if ($selected.Count -eq 0) {
    Write-Host "Keeping all system-wide dependencies." -ForegroundColor DarkGray
}

# Scoop-managed apps first, while Scoop still exists
foreach ($dep in @($selected | Where-Object { $_.Method -eq 'scoop-app' })) {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop uninstall $dep.Scoop 2>&1 | Out-Null
    }
    Start-Sleep -Milliseconds 300
    if (Test-Path $dep.Source) {
        Write-Host "[FAIL] $($dep.Name) is still present: $($dep.Source)" -ForegroundColor Yellow
    } else {
        Write-Host "[OK] Removed $($dep.Name) (Scoop)" -ForegroundColor Green
    }
}

# winget packages and the python.org install
foreach ($dep in @($selected | Where-Object { $_.Method -in @('winget', 'python-org') })) {
    if ($dep.Method -eq 'python-org') {
        Uninstall-PythonOrg
        $pathCleanup += (Split-Path -Parent $dep.Source)   # python.org folder, Scripts included
    }
    elseif ($wingetAvailable -and $dep.Winget) {
        winget uninstall --id $dep.Winget -e --silent | Out-Null
    }
    else {
        Write-Host "[SKIP] $($dep.Name): winget is not available. Remove it manually." -ForegroundColor Yellow
        continue
    }

    Start-Sleep -Milliseconds 300
    # Check the original file path, not Get-Command, which can return stale results
    if (Test-Path $dep.Source) {
        Write-Host "[FAIL] $($dep.Name) is still present: $($dep.Source)" -ForegroundColor Yellow
        Write-Host "  Remove it from Settings > Apps, or run 'winget list' to find its package ID." -ForegroundColor DarkGray
    } else {
        Write-Host "[OK] Removed $($dep.Name)" -ForegroundColor Green
    }
}

# Scoop itself, last
if (@($selected | Where-Object { $_.Method -eq 'scoop-self' }).Count -gt 0) {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        "y" | scoop uninstall scoop -p 2>&1 | Out-Null
    }
    if (Test-Path $scoopRoot) {
        # Scoop's uninstaller can leave junctions behind. rd /s /q removes them without following.
        cmd /c rd /s /q "`"$scoopRoot`"" 2>&1 | Out-Null
    }
    if (Test-Path $scoopRoot) {
        Write-Host "[FAIL] Scoop folder still present: $scoopRoot" -ForegroundColor Yellow
        Write-Host "  Close apps installed through Scoop, then run: cmd /c rd /s /q `"$scoopRoot`"" -ForegroundColor DarkGray
    } else {
        Write-Host "[OK] Removed Scoop" -ForegroundColor Green
        $pathCleanup += $scoopRoot
    }
}

# -------------------------------
# 10. USER PATH
# -------------------------------
Write-Host "`nCleaning the User PATH..." -ForegroundColor Cyan
Remove-FromPath -Folders (@($toolFolders) + $pathCleanup)

# -------------------------------
# DONE
# -------------------------------
Write-Host "`n=== Uninstall Complete ===" -ForegroundColor Green
Write-Host "Kept on purpose: PSReadLine, the NuGet package provider, and any dependency you chose not to remove." -ForegroundColor DarkGray
Write-Host "Close every PowerShell and cmd window, then open a new one, so the removed PATH, profile and functions are gone." -ForegroundColor Yellow
