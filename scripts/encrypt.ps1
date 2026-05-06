param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path,

    [switch]$y,

    [switch]$n
)

# -------------------------------
# Validate action
# -------------------------------
if ($y -and $n) {
    Write-Host "Use only one option: -y for encrypt OR -n for decrypt." -ForegroundColor Red
    exit 1
}

if (-not $y -and -not $n) {
    Write-Host "Missing option." -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  encrypt ""file-or-folder-path"" -y   → Encrypt"
    Write-Host "  encrypt ""file-or-folder-path"" -n   → Decrypt"
    exit 1
}

# -------------------------------
# Validate path
# -------------------------------
if (-not (Test-Path $Path)) {
    Write-Host "Path not found: $Path" -ForegroundColor Red
    exit 1
}

$item = Get-Item $Path

# -------------------------------
# Encrypt
# -------------------------------
if ($y) {
    Write-Host "Encrypting: $Path" -ForegroundColor Cyan

    try {
        if ($item.PSIsContainer) {
            # Encrypt folder so new files added later are encrypted automatically
            cipher /E "$Path" | Out-Null

            # Encrypt all existing files and subfolders recursively
            cipher /E /A /S:"$Path" | Out-Null

            Write-Host "Folder and contents encrypted successfully." -ForegroundColor Green
        }
        else {
            # Encrypt single file
            cipher /E /A "$Path" | Out-Null

            Write-Host "File encrypted successfully." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Encryption failed." -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "Important: EFS encryption depends on your Windows user certificate." -ForegroundColor Yellow
    Write-Host "If Windows is reinstalled or your user profile is lost, encrypted files may become unreadable without a .pfx backup." -ForegroundColor Yellow
    Write-Host ""

    $backupChoice = Read-Host "Create EFS certificate backup on Desktop now? (y/n)"

    if ($backupChoice -eq "y" -or $backupChoice -eq "Y") {
        try {
            $backupPath = Join-Path $HOME "Desktop\EFS-Backup"
            cipher /x "$backupPath"

            Write-Host ""
            Write-Host "EFS certificate backup created on Desktop." -ForegroundColor Green
            Write-Host "Keep the .pfx file and its password very safe." -ForegroundColor Yellow
        }
        catch {
            Write-Host "Backup failed. You can run it manually later:" -ForegroundColor Yellow
            Write-Host "cipher /x `"$HOME\Desktop\EFS-Backup`"" -ForegroundColor Cyan
        }
    }
    else {
        Write-Host "Skipped EFS backup." -ForegroundColor Yellow
        Write-Host "You can create it later with:" -ForegroundColor Cyan
        Write-Host "cipher /x `"$HOME\Desktop\EFS-Backup`"" -ForegroundColor Cyan
    }

    exit 0
}

# -------------------------------
# Decrypt
# -------------------------------
if ($n) {
    Write-Host "Decrypting: $Path" -ForegroundColor Cyan

    try {
        if ($item.PSIsContainer) {
            # Decrypt folder and all existing files/subfolders recursively
            cipher /D /A /S:"$Path" | Out-Null

            # Decrypt folder itself so new files are not automatically encrypted
            cipher /D "$Path" | Out-Null

            Write-Host "Folder and contents decrypted successfully." -ForegroundColor Green
        }
        else {
            # Decrypt single file
            cipher /D /A "$Path" | Out-Null

            Write-Host "File decrypted successfully." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Decryption failed." -ForegroundColor Red
        exit 1
    }

    exit 0
}