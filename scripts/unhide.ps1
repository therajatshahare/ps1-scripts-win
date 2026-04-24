param(
    [Parameter(Mandatory=$true)]
    [string]$file
)

# -------------------------------
# Get item safely
# -------------------------------
$item = Get-Item $file -Force -ErrorAction SilentlyContinue

if (-not $item) {
    Write-Host "File or folder not found: $file" -ForegroundColor Red
    exit 1
}

# -------------------------------
# If folder → unhide everything inside
# -------------------------------
if ($item.PSIsContainer) {

    Get-ChildItem $file -Recurse -Force | ForEach-Object {
        $_.Attributes = $_.Attributes `
            -band (-bnot [System.IO.FileAttributes]::Hidden) `
            -band (-bnot [System.IO.FileAttributes]::System) `
            -band (-bnot [System.IO.FileAttributes]::ReadOnly)
    }
}

# -------------------------------
# Unhide main item
# -------------------------------
$item.Attributes = $item.Attributes `
    -band (-bnot [System.IO.FileAttributes]::Hidden) `
    -band (-bnot [System.IO.FileAttributes]::System) `
    -band (-bnot [System.IO.FileAttributes]::ReadOnly)

Write-Host "File/folder '$file' is now fully visible."
