param()

Write-Host "Checking for Winget updates..." -ForegroundColor Cyan
winget upgrade --include-unknown

Write-Host ""
Write-Host "Checking for Scoop updates..." -ForegroundColor Cyan
scoop update
scoop status

Write-Host ""
$response = Read-Host "Do you want to run the Upgrade? (Y/N)"

if ($response -eq 'Y' -or $response -eq 'y') {
    $upgradeScript = Join-Path $PSScriptRoot "upgrade.ps1"

    if (Test-Path $upgradeScript) {
        Write-Host ""
        Write-Host "Running Upgrade script..." -ForegroundColor Cyan
        & $upgradeScript
    }
    else {
        Write-Host ""
        Write-Host "upgrade.ps1 not found in $PSScriptRoot" -ForegroundColor Red
    }
}
else {
    Write-Host ""
    Write-Host "Skipping Upgrade." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to continue..."
}
