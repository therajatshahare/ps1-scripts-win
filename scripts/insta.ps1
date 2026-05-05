param(
    [Parameter(Mandatory = $true)]
    [string]$Username,

    [ValidateSet("full", "update")]
    [string]$Mode = "full",

    [string]$Account = "1"
)

# -------------------------------
# Account config file
# -------------------------------
$ConfigDir = Join-Path $env:LOCALAPPDATA "Instaloader"
$ConfigFile = Join-Path $ConfigDir "insta-accounts.json"
$EfsBackupMarker = Join-Path $ConfigDir ".efs-backup-reminder.done"

if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir | Out-Null
}

# -------------------------------
# Protect Instaloader session/config files with Windows EFS
# -------------------------------
function Protect-InstaloaderData {
    param(
        [string]$FolderPath,
        [string]$BackupMarkerPath
    )

    if (-not (Test-Path $FolderPath)) {
        return
    }

    Write-Host "Checking Instaloader data protection..." -ForegroundColor DarkGray

    try {
        # Encrypt folder so new files added later are encrypted automatically
        cipher /E "$FolderPath" | Out-Null

        # Encrypt existing files inside the folder
        cipher /E /A "$FolderPath\*" | Out-Null

        Write-Host "Instaloader session/config folder is protected with Windows EFS." -ForegroundColor Green
    }
    catch {
        Write-Host "Warning: Could not apply EFS encryption to Instaloader folder." -ForegroundColor Yellow
    }

    # Ask once for EFS certificate backup
    if (-not (Test-Path $BackupMarkerPath)) {
        Write-Host ""
        Write-Host "Important: Your Instaloader session files are now encrypted." -ForegroundColor Yellow
        Write-Host "You should back up your Windows EFS certificate as a .pfx file." -ForegroundColor Yellow
        Write-Host "Without this backup, encrypted files may become unreadable after Windows reinstall." -ForegroundColor Yellow
        Write-Host ""

        $BackupChoice = Read-Host "Create EFS certificate backup on Desktop now? (y/n)"

        if ($BackupChoice -eq "y" -or $BackupChoice -eq "Y") {
            try {
                $BackupPath = Join-Path $HOME "Desktop\EFS-Backup"
                cipher /x "$BackupPath"

                Write-Host ""
                Write-Host "EFS backup created on Desktop." -ForegroundColor Green
                Write-Host "Keep the .pfx file and its password very safe." -ForegroundColor Yellow
            }
            catch {
                Write-Host "Warning: EFS backup command failed. You can run it manually later:" -ForegroundColor Yellow
                Write-Host "cipher /x `"$HOME\Desktop\EFS-Backup`"" -ForegroundColor Cyan
            }
        }
        else {
            Write-Host "Skipped EFS backup. You can create it later with:" -ForegroundColor Yellow
            Write-Host "cipher /x `"$HOME\Desktop\EFS-Backup`"" -ForegroundColor Cyan
        }

        # Create marker so the script does not ask every time
        "EFS backup reminder shown on $(Get-Date)" |
            Set-Content -Path $BackupMarkerPath -Encoding UTF8

        # Encrypt marker too
        try {
            cipher /E /A "$BackupMarkerPath" | Out-Null
        } catch {}
    }
}

# Apply protection early
Protect-InstaloaderData -FolderPath $ConfigDir -BackupMarkerPath $EfsBackupMarker

# Create account config file if missing
if (-not (Test-Path $ConfigFile)) {
    $defaultAccounts = @{
        "1" = ""
        "2" = ""
        "3" = ""
    }

    $defaultAccounts |
        ConvertTo-Json |
        Set-Content -Path $ConfigFile -Encoding UTF8

    # Encrypt newly created config file
    try {
        cipher /E /A "$ConfigFile" | Out-Null
    } catch {}
}

# Load account config
$accounts = Get-Content $ConfigFile -Raw | ConvertFrom-Json -AsHashtable

# -------------------------------
# Choose login account
# -------------------------------
if ($Account -eq "ask") {
    $LoginUser = Read-Host "Enter Instagram login username"
}
else {
    # If the account slot does not exist, create it
    if (-not $accounts.ContainsKey($Account)) {
        $accounts[$Account] = ""

        $accounts |
            ConvertTo-Json |
            Set-Content -Path $ConfigFile -Encoding UTF8

        try {
            cipher /E /A "$ConfigFile" | Out-Null
        } catch {}
    }

    $LoginUser = $accounts[$Account]

    # If account slot is blank, ask username
    if ([string]::IsNullOrWhiteSpace($LoginUser)) {
        Write-Host "No username saved for account $Account." -ForegroundColor Yellow
        $LoginUser = Read-Host "Enter Instagram login username"

        if (-not [string]::IsNullOrWhiteSpace($LoginUser)) {
            $SaveChoice = Read-Host "Save '$LoginUser' to account slot $Account? (y/n)"

            if ($SaveChoice -eq "y" -or $SaveChoice -eq "Y") {
                $accounts[$Account] = $LoginUser

                $accounts |
                    ConvertTo-Json |
                    Set-Content -Path $ConfigFile -Encoding UTF8

                try {
                    cipher /E /A "$ConfigFile" | Out-Null
                } catch {}

                Write-Host "Saved '$LoginUser' to account slot $Account." -ForegroundColor Green
            }
        }
    }
}

if ([string]::IsNullOrWhiteSpace($LoginUser)) {
    Write-Host "No login username entered. Exiting." -ForegroundColor Red
    exit 1
}

# DO NOT change directory → use current working directory instead
# Fixes permission issue when script is inside C:\Windows

Write-Host "Processing profile: $Username" -ForegroundColor Cyan
Write-Host "Using login account: $LoginUser" -ForegroundColor Cyan
Write-Host "Download location: $(Get-Location)" -ForegroundColor DarkGray

# -------------------------------
# Execute based on mode
# -------------------------------
switch ($Mode) {
    "update" {
        Write-Host "Running FAST UPDATE mode..." -ForegroundColor Yellow
        instaloader --login $LoginUser --fast-update $Username
    }

    "full" {
        Write-Host "Running FULL DOWNLOAD mode..." -ForegroundColor Yellow
        instaloader --login $LoginUser $Username
    }
}

# After Instaloader runs, encrypt any newly created session files
try {
    cipher /E "$ConfigDir" | Out-Null
    cipher /E /A "$ConfigDir\*" | Out-Null
} catch {}

# -------------------------------
# Proper result handling
# -------------------------------
if ($LASTEXITCODE -eq 0) {
    Write-Host "Operation completed successfully!" -ForegroundColor Green

    # -------------------------------
    # Move .json.xz and .txt files to json-data folder
    # -------------------------------
    $ProfileFolder = Join-Path (Get-Location) $Username
    $JsonDataFolder = Join-Path $ProfileFolder "json-data"

    if (Test-Path $ProfileFolder) {
        if (-not (Test-Path $JsonDataFolder)) {
            New-Item -ItemType Directory -Path $JsonDataFolder | Out-Null
            Write-Host "Created metadata folder: json-data" -ForegroundColor DarkGray
        }

        $MetadataFiles = Get-ChildItem -Path $ProfileFolder -File |
            Where-Object {
                $_.Name -like "*.json.xz" -or $_.Name -like "*.txt"
            }

        if ($MetadataFiles.Count -gt 0) {
            $MetadataFiles | Move-Item -Destination $JsonDataFolder -Force
            Write-Host "Moved $($MetadataFiles.Count) metadata file(s) to json-data folder." -ForegroundColor Green
        }
        else {
            Write-Host "No .json.xz or .txt files found to move." -ForegroundColor DarkGray
        }
    }
    else {
        Write-Host "Profile folder not found: $ProfileFolder" -ForegroundColor Yellow
    }
}
else {
    Write-Host "Operation failed. Check credentials, session, or connection." -ForegroundColor Red

    if ($Host.Name -eq 'ConsoleHost') {
        Read-Host "Press Enter to continue..."
    }

    exit 1
}

Write-Host ""

# Optional pause only for interactive runs
if ($Host.Name -eq 'ConsoleHost') {
    Read-Host "Press Enter to continue..."
}

exit 0
