param(
    [Parameter(Mandatory=$true)]
    [string]$file
)

# -------------------------------
# Validate path
# -------------------------------
if (-not (Test-Path $file -Force)) {
    Write-Host "File not found: $file"
    exit 1
}

# -------------------------------
# Remove Hidden + System + ReadOnly
# -------------------------------
$item = Get-Item $file -Force

$item.Attributes = $item.Attributes `
    -band (-bnot [System.IO.FileAttributes]::Hidden) `
    -band (-bnot [System.IO.FileAttributes]::System) `
    -band (-bnot [System.IO.FileAttributes]::ReadOnly)

Write-Host "File '$file' is now visible."
