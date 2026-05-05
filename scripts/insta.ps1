param(
    [Parameter(Mandatory = $true)]
    [string]$Username,

    [ValidateSet("full", "update")]
    [string]$Mode = "full",

    [ValidateSet("1", "2", "3", "ask")]
    [string]$Account = "1"
)

# -------------------------------
# Optional saved Instagram login accounts
# You can keep only account 1 here if you want
# -------------------------------
$accounts = @{
    "1" = "aroallfather"
    "2" = ""
    "3" = ""
}

# -------------------------------
# Choose login account
# -------------------------------
if ($Account -eq "ask") {
    $LoginUser = Read-Host "Enter Instagram login username"
}
else {
    $LoginUser = $accounts[$Account]

    if ([string]::IsNullOrWhiteSpace($LoginUser)) {
        Write-Host "No username saved for account $Account." -ForegroundColor Yellow
        $LoginUser = Read-Host "Enter Instagram login username"
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

# Execute based on mode
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

# Proper result handling
if ($LASTEXITCODE -eq 0) {
    Write-Host "Operation completed successfully!" -ForegroundColor Green
} else {
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
