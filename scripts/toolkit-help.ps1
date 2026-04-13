param(
    [string]$Command
)

Write-Host ""

# ===============================
# MAIN HELP (no argument)
# ===============================
if (-not $Command) {

    Write-Host "=== Cmd-Scripts Toolkit Help ===" -ForegroundColor Cyan

    Write-Host "`n🎥 Media Commands" -ForegroundColor Yellow
    Write-Host "  ytvideo    → Download YouTube video"
    Write-Host "  vytvideo   → Download vertical video"
    Write-Host "  ytaudio    → Extract audio"

    Write-Host "`n🎵 Metadata & Lyrics" -ForegroundColor Yellow
    Write-Host "  showmeta     → Show metadata"
    Write-Host "  showformat   → Show formats"
    Write-Host "  showlyrics   → Fetch lyrics"

    Write-Host "`n📁 File Utilities" -ForegroundColor Yellow
    Write-Host "  folders   → List folders"
    Write-Host "  hide      → Hide file"
    Write-Host "  unhide    → Unhide file"
    Write-Host "  exifpic   → Modify EXIF data"

    Write-Host "`n⚡ System Tools" -ForegroundColor Yellow
    Write-Host "  update    → Update tools"
    Write-Host "  upgrade   → Upgrade system"
    Write-Host "  aria      → Downloader"

    Write-Host "`n📸 Instagram" -ForegroundColor Yellow
    Write-Host "  insta     → Profile downloader"

    Write-Host "`n🔁 Toolkit" -ForegroundColor Yellow
    Write-Host "  update-scripts   → Update toolkit"
    Write-Host "  toolkit-version  → Show version"

    Write-Host "`nTip: Run 'toolkit-help <command>' for detailed usage" -ForegroundColor DarkGray
    Write-Host ""
    return
}

# ===============================
# COMMAND-SPECIFIC HELP
# ===============================
switch ($Command.ToLower()) {

    "ytvideo" {
        Write-Host "ytvideo [res] ""name"" ""url""" -ForegroundColor Cyan
        Write-Host "Download YouTube video (≤4K)"
        Write-Host ""
        Write-Host "Example:"
        Write-Host "  ytvideo 2k ""video"" ""https://youtu.be/..."""
        Write-Host ""
        Write-Host "Resolutions:"
        Write-Host "  4k, 2k, 1080p, 720p, 480p, 360p, 240p"
        Write-Host ""
        Write-Host "Notes:"
        Write-Host "  • No resolution = best/original quality"
        Write-Host "  • Output format: MKV"
    }

    "vytvideo" {
        Write-Host "vytvideo [res] ""name"" ""url""" -ForegroundColor Cyan
        Write-Host "Download vertical videos (Reels/Shorts)"
        Write-Host ""
        Write-Host "Example:"
        Write-Host "  vytvideo 2k ""video"" ""https://youtu.be/..."""
        Write-Host ""
        Write-Host "Notes:"
        Write-Host "  • Uses same resolution options as ytvideo"
        Write-Host "  • Output format: MKV"
    }

    "ytaudio" {
        Write-Host "ytaudio ""name"" ""url""" -ForegroundColor Cyan
        Write-Host "Extract audio in FLAC format"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  ytaudio ""song"" ""https://youtu.be/..."""
        Write-Host "  ytaudio ""https://youtu.be/..."""
        Write-Host ""
        Write-Host "Notes:"
        Write-Host "  • Best quality audio (FLAC)"
        Write-Host "  • Metadata and thumbnail embedded"
    }

    "exifpic" {
        Write-Host "exifpic ""YYYY:MM:DD HH:MM"" [file]" -ForegroundColor Cyan
        Write-Host "Modify EXIF date/time"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  exifpic ""2024:01:01 10:00"""
        Write-Host "    → Apply to all JPG/PNG in current folder"
        Write-Host ""
        Write-Host "  exifpic ""2024:01:01 10:00"" ""image.jpg"""
        Write-Host "    → Apply to specific file"
        Write-Host ""
        Write-Host "Notes:"
        Write-Host "  • Format: YYYY:MM:DD HH:MM"
        Write-Host "  • Overwrites original metadata"
    }

    "insta" {
        Write-Host "insta <user> [full|update]" -ForegroundColor Cyan
        Write-Host "Download Instagram profile posts"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  insta username"
        Write-Host "    → Full download (default)"
        Write-Host ""
        Write-Host "  insta username update"
        Write-Host "    → Download only new posts"
        Write-Host ""
        Write-Host "Modes:"
        Write-Host "  full    → Download all posts"
        Write-Host "  update  → Download only new posts (fast)"
        Write-Host ""
        Write-Host "Notes:"
        Write-Host "  • Requires login (saved session)"
        Write-Host "  • Files saved in current directory"
    }

    default {
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Write-Host "Use 'toolkit-help' to see available commands"
    }
}

Write-Host ""
