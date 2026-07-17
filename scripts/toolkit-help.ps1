param(
    [string]$Command
)

Write-Host ""

# ===============================
# MAIN HELP (no argument)
# ===============================
if (-not $Command) {

    Write-Host "" -ForegroundColor Cyan
    Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║      🚀 ps1-scripts-win Help         ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Green
    Write-Host "Note: All scripts are saved in your home folder under ps1-scripts-win." -ForegroundColor Cyan

    Write-Host "`n🎥 Media Commands" -ForegroundColor Yellow
    Write-Host "  ytvideo    → Download YouTube video"
    Write-Host "  vytvideo   → Download vertical video"
    Write-Host "  ytaudio    → Extract audio"

    Write-Host "`n🎵 Metadata & Lyrics" -ForegroundColor Yellow
    Write-Host "  showmeta     → Show metadata"
    Write-Host "  showformat   → Show formats"
    Write-Host "  showlyrics   → Fetch lyrics"

    Write-Host "`n📁 File Utilities" -ForegroundColor Yellow
    Write-Host "  folders    → List folders"
    Write-Host "  hide       → Hide file"
    Write-Host "  unhide     → Unhide file"
    Write-Host "  exifpic    → Modify EXIF data"

    Write-Host "`n⚡ System Tools" -ForegroundColor Yellow
    Write-Host "  update     → Update tools"
    Write-Host "  upgrade    → Upgrade system"
    Write-Host "  aria       → Downloader"

    Write-Host "`n📸 Instagram" -ForegroundColor Yellow
    Write-Host "  insta      → Profile downloader"

    Write-Host "`n🔁 Toolkit" -ForegroundColor Yellow
    Write-Host "  update-scripts   → Update toolkit"
    Write-Host "  toolkit-version  → Show version"

    Write-Host "`nTip: Run toolkit-help followed by a command name for detailed usage." -ForegroundColor DarkGray
    Write-Host ""
    return
}

# ===============================
# COMMAND-SPECIFIC HELP
# ===============================
switch ($Command.ToLower()) {

    "ytvideo" {
        Write-Host "ytvideo [res] name url" -ForegroundColor Cyan
        Write-Host "Download YouTube video"
        Write-Host ""
        Write-Host "Example:"
        Write-Host "  ytvideo 2k myvideo https://youtu.be/..."
        Write-Host ""
        Write-Host "Resolutions:"
        Write-Host "  4k, 2k, 1080p, 720p, 480p, 360p, 240p"
        Write-Host ""
        Write-Host "Notes:"
        Write-Host "  - No resolution defaults to best quality"
        Write-Host "  - Output format is MKV"
    }

    "vytvideo" {
        Write-Host "vytvideo [res] name url" -ForegroundColor Cyan
        Write-Host "Download vertical videos (Reels or Shorts)"
        Write-Host ""
        Write-Host "Example:"
        Write-Host "  vytvideo 2k myvideo https://youtu.be/..."
    }

    "ytaudio" {
        Write-Host "ytaudio name url" -ForegroundColor Cyan
        Write-Host "Extract audio in FLAC format"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  ytaudio songname https://youtu.be/..."
    }

    "exifpic" {
        Write-Host "exifpic YYYY:MM:DD HH:MM [file]" -ForegroundColor Cyan
        Write-Host "Modify EXIF date and time metadata"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  exifpic 2024:01:01 10:00"
        Write-Host "  exifpic 2024:01:01 10:00 image.jpg"
    }

    "insta" {
        Write-Host "insta user mode slot" -ForegroundColor Cyan
        Write-Host "Download Instagram profile posts using Instaloader"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  insta username"
        Write-Host "  insta username update"
        Write-Host "  insta username update 2"
        Write-Host ""
        Write-Host "Modes:"
        Write-Host "  full, update"
    }
    
    "showmeta" {
        Write-Host "showmeta filename" -ForegroundColor Cyan
        Write-Host "Display full media metadata using MediaInfo or FFprobe"
    }

    "showformat" {
        Write-Host "showformat url" -ForegroundColor Cyan
        Write-Host "Display stream formats for online video URLs"
    }

    "showlyrics" {
        Write-Host "showlyrics filename" -ForegroundColor Cyan
        Write-Host "Fetch and embed lyrics into an audio file"
    }

    "folders" {
        Write-Host "folders" -ForegroundColor Cyan
        Write-Host "Lists all directories in the current path."
    }

    "hide" {
        Write-Host "hide target" -ForegroundColor Cyan
        Write-Host "Hides a specified file or folder."
    }

    "unhide" {
        Write-Host "unhide target" -ForegroundColor Cyan
        Write-Host "Reveals a previously hidden file or folder."
    }

    "aria" {
        Write-Host "aria url" -ForegroundColor Cyan
        Write-Host "High-speed downloader utility using aria2c."
    }

    "update" {
        Write-Host "update" -ForegroundColor Cyan
        Write-Host "Updates external CLI tools like yt-dlp and ffmpeg."
    }

    "upgrade" {
        Write-Host "upgrade" -ForegroundColor Cyan
        Write-Host "Runs environment tool upgrades."
    }

    "update-scripts" {
        Write-Host "update-scripts" -ForegroundColor Cyan
        Write-Host "Pulls down the latest versions of the toolkit scripts."
    }

    "toolkit-version" {
        Write-Host "toolkit-version" -ForegroundColor Cyan
        Write-Host "Displays current installed version details."
    }

    default {
        Write-Host "Unknown command requested" -ForegroundColor Red
        Write-Host "Use toolkit-help to see available commands"
    }
}

Write-Host ""
