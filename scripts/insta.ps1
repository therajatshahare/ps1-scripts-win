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

if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir | Out-Null
}

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
