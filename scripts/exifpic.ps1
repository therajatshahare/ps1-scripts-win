param(
    [Parameter(Position = 0)]
    [string]$DateTime,

    [Parameter(Position = 1)]
    [string]$File
)

# Validate input
if (-not $DateTime) {
    Write-Host "Usage: exifpic `"YYYY:MM:DD HH:MM`"" -ForegroundColor Yellow
    Write-Host "Or:    exifpic `"YYYY:MM:DD HH:MM`" `"filename.jpg`"" -ForegroundColor Yellow
    return
}

# If specific file is provided
if ($File) {
    exiftool -overwrite_original `
        "-DateTimeOriginal=$DateTime" `
        "-CreateDate=$DateTime" `
        "-FileModifyDate=$DateTime" `
        "-FileCreateDate=$DateTime" `
        "$File"
    return
}

# Otherwise, process all JPG and PNG files in current directory
Get-ChildItem -Path .\* -File -Include *.jpg, *.png | ForEach-Object {
    exiftool -overwrite_original `
        "-DateTimeOriginal=$DateTime" `
        "-CreateDate=$DateTime" `
        "-FileModifyDate=$DateTime" `
        "-FileCreateDate=$DateTime" `
        "$($_.FullName)"
}
