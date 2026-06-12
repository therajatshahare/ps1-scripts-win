param(
    [Parameter(Mandatory = $true)]
    [string]$Username,

    [ValidateSet("full", "update")]
    [string]$Mode = "full",

    [string]$Account = "1"
)

$ConfigDir = Join-Path $env:LOCALAPPDATA "Instaloader"
$ConfigFile = Join-Path $ConfigDir "insta-accounts.json"
$EfsBackupMarker = Join-Path $ConfigDir ".efs-backup-reminder.done"

if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}

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
        cipher /E "$FolderPath" | Out-Null
        cipher /E /A "$FolderPath\*" | Out-Null
        Write-Host "Instaloader session/config folder is protected with Windows EFS." -ForegroundColor Green
    }
    catch {
        Write-Host "Warning: Could not apply EFS encryption to Instaloader folder." -ForegroundColor Yellow
    }

    if (-not (Test-Path $BackupMarkerPath)) {
        Write-Host ""
        Write-Host "Important: Your Instaloader session files are now encrypted." -ForegroundColor Yellow
        Write-Host "You should back up your Windows EFS certificate as a .pfx file." -ForegroundColor Yellow
        Write-Host "Without this backup, encrypted files may become unreadable after Windows reinstall." -ForegroundColor Yellow
        Write-Host ""

        $BackupChoice = Read-Host "Create EFS certificate backup on Desktop now? (y/n)"
        $BackupPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "EFS-Backup"

        if ($BackupChoice -eq "y" -or $BackupChoice -eq "Y") {
            try {
                cipher /x "$BackupPath"
                $efsExitCode = $LASTEXITCODE

                if ($efsExitCode -eq 0) {
                    Write-Host ""
                    Write-Host "EFS backup created on Desktop." -ForegroundColor Green
                    Write-Host "Keep the .pfx file and its password very safe." -ForegroundColor Yellow
                } else {
                    Write-Host ""
                    Write-Host "EFS backup failed." -ForegroundColor Red
                    Write-Host "Try manually:" -ForegroundColor Yellow
                    Write-Host "cipher /x `"$BackupPath`"" -ForegroundColor Cyan
                }
            }
            catch {
                Write-Host "Warning: EFS backup command failed. You can run it manually later:" -ForegroundColor Yellow
                Write-Host "cipher /x `"$BackupPath`"" -ForegroundColor Cyan
            }
        }
        else {
            Write-Host "Skipped EFS backup. You can create it later with:" -ForegroundColor Yellow
            Write-Host "cipher /x `"$BackupPath`"" -ForegroundColor Cyan
        }

        "EFS backup reminder shown on $(Get-Date)" |
            Set-Content -Path $BackupMarkerPath -Encoding UTF8

        try {
            cipher /E /A "$BackupMarkerPath" | Out-Null
        } catch {}
    }
}

Protect-InstaloaderData -FolderPath $ConfigDir -BackupMarkerPath $EfsBackupMarker

if (-not (Test-Path $ConfigFile)) {
    $defaultAccounts = @{
        "1" = ""
        "2" = ""
        "3" = ""
    }

    $defaultAccounts |
        ConvertTo-Json |
        Set-Content -Path $ConfigFile -Encoding UTF8

    try {
        cipher /E /A "$ConfigFile" | Out-Null
    } catch {}
}

$accountsObject = Get-Content $ConfigFile -Raw | ConvertFrom-Json
$accounts = @{}

$accountsObject.PSObject.Properties | ForEach-Object {
    $accounts[$_.Name] = $_.Value
}

if ($Account -eq "ask") {
    $LoginUser = Read-Host "Enter Instagram login username"
}
else {
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

Write-Host "Processing profile: $Username" -ForegroundColor Cyan
Write-Host "Using login account: $LoginUser" -ForegroundColor Cyan
Write-Host "Download location: $(Get-Location)" -ForegroundColor DarkGray

switch ($Mode) {
    "update" {
        Write-Host "Running FAST UPDATE mode..." -ForegroundColor Yellow
        instaloader --login $LoginUser --fast-update --abort-on=400,401,403,429 $Username
    }

    "full" {
        Write-Host "Running FULL DOWNLOAD mode..." -ForegroundColor Yellow
        instaloader --login $LoginUser --abort-on=400,401,403,429 $Username
    }
}

$instaloaderExitCode = $LASTEXITCODE

try {
    cipher /E "$ConfigDir" | Out-Null
    cipher /E /A "$ConfigDir\*" | Out-Null
} catch {}

if ($instaloaderExitCode -eq 0) {
    Write-Host "Operation completed successfully!" -ForegroundColor Green

    $ProfileFolder = Join-Path (Get-Location) $Username
    $JsonDataFolder = Join-Path $ProfileFolder "json-data"

    if (Test-Path $ProfileFolder) {
        if (-not (Test-Path $JsonDataFolder)) {
            New-Item -ItemType Directory -Path $JsonDataFolder -Force | Out-Null
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
    exit 1
}

Write-Host ""
exit 0
