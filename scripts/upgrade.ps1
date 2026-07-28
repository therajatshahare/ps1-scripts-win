param()

Write-Host "Updating Scoop and all installed Scoop apps..." -ForegroundColor Cyan
scoop update *

Write-Host ""
$response = Read-Host "Do you want to upgrade all Winget apps? (Y/N)"

if ($response -eq 'Y' -or $response -eq 'y') {
    Write-Host ""
    Write-Host "Installing all Winget updates..." -ForegroundColor Cyan
    winget upgrade --all `
        --include-unknown `
        --silent `
        --accept-package-agreements `
        --accept-source-agreements
}
else {
    Write-Host ""
    Write-Host "Skipping Winget updates." -ForegroundColor Yellow
}

Write-Host ""
Read-Host "Press Enter to continue..."
