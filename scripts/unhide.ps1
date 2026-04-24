param(
    [Parameter(Mandatory=$true)]
    [string]$file
)

# -------------------------------
# Validate path
# -------------------------------
$item = Get-Item $file -Force -ErrorAction SilentlyContinue

if (-not $item) {
    Write-Host "File or folder not found: $file" -ForegroundColor Red
    exit 1
}

# -------------------------------
# Remove Hidden + System + ReadOnly
# -------------------------------

$item.Attributes = $item.Attributes `
    -band (-bnot [System.IO.FileAttributes]::Hidden) `
    -band (-bnot [System.IO.FileAttributes]::System) `
    -band (-bnot [System.IO.FileAttributes]::ReadOnly)

Write-Host "File '$file' is now visible."
