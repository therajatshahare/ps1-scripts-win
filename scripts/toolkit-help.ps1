param(
    [string]$Command
)

Write-Host ""

# ===============================
# MAIN HELP (no argument)
# ===============================
if (-not $Command) {

    Write-Host "" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "           ps1-scripts-win Help          " -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Note: All the scripts will be saved in $HOME\ps1-scripts-win directory." -ForegroundColor Cyan

    Write-Host "`nMedia Commands" -ForegroundColor Yellow
    Write-Host "  ytvideo    -> Download YouTube video"
    Write-Host "  vytvideo   -> Download vertical video"
    Write-Host "  hytvideo   -> Download horizontal video"
    Write-Host "  ytaudio    -> Extract audio"

    Write-Host "`nMetadata & Lyrics" -ForegroundColor Yellow
    Write-Host "  showmeta     -> Show metadata"
    Write-Host "  showformat   -> Show formats"
    Write-Host "  showlyrics   -> Fetch lyrics"

    Write-Host "`nFile Utilities" -ForegroundColor Yellow
    Write-Host "  folders   -> List folders (filter, depth, tree view)"
    Write-Host "  hide      -> Hide file"
    Write-Host "  unhide    -> Unhide file"
    Write-Host "  exifpic   -> Modify EXIF data"

    Write-Host "`nSystem Tools" -ForegroundColor Yellow
    Write-Host "  update    -> Update tools"
    Write-Host "  upgrade   -> Upgrade system"
    Write-Host "  aria      -> Downloader"

    Write-Host "`nInstagram" -ForegroundColor Yellow
    Write-Host "  insta     -> Profile downloader"

    Write-Host "`nToolkit" -ForegroundColor Yellow
    Write-Host "  update-scripts   -> Update toolkit"
    Write-Host "  toolkit-version  -> Show version"

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
        Write-Host "Download YouTube video (up to 4K)"
        Write-Host ""
        Write-Host "Example:"
        Write-Host "  ytvideo 2k ""video"" ""https://youtu.be/..."""
        Write-Host ""
        Write-Host "Resolutions:"
        Write-Host "  original, 4k, 2k, 1080p, 720p, 480p, 360p, 240p"
        Write-Host ""
        Write-Host "Notes:"
        Write-Host "  - original = best/original quality"
        Write-Host "  - auto detect the video orientation"
        Write-Host "  - output format: MKV"
    }

    "vytvideo" {
        Write-Host "vytvideo [res] ""name"" ""url""" -ForegroundColor Cyan
        Write-Host "Download vertical videos (for...Reels/Shorts)"
        Write-Host ""
        Write-Host "Example:"
        Write-Host "  vytvideo 2k ""video"" ""https://youtu.be/..."""
        Write-Host ""
        Write-Host "Notes:"
        Write-Host "  - Uses same resolution options as ytvideo"
        Write-Host "  - Output format: MKV"
    }

    "hytvideo" {
        Write-Host "hytvideo [res] ""name"" ""url""" -ForegroundColor Cyan
        Write-Host "Download horizontal videos (for...TV/Normal Video)"
        Write-Host ""
        Write-Host "Example:"
        Write-Host "  hytvideo 2k ""video"" ""https://youtu.be/..."""
        Write-Host ""
        Write-Host "Notes:"
        Write-Host "  - Uses same resolution options as ytvideo"
        Write-Host "  - Output format: MKV"
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
        Write-Host "  - Best quality audio (FLAC)"
        Write-Host "  - Metadata and thumbnail embedded"
    }

    "exifpic" {
        Write-Host "exifpic ""YYYY:MM:DD HH:MM"" [file]" -ForegroundColor Cyan
        Write-Host "Modify EXIF date/time"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  exifpic ""2024:01:01 10:00"""
        Write-Host "    -> Apply to all JPG/PNG in current folder"
        Write-Host ""
        Write-Host "  exifpic ""2024:01:01 10:00"" ""image.jpg"""
        Write-Host "    -> Apply to specific file"
        Write-Host ""
        Write-Host "Notes:"
        Write-Host "  - Format: YYYY:MM:DD HH:MM"
        Write-Host "  - Overwrites original metadata"
    }

    "insta" {
        Write-Host "insta <user> [full|update] [account|ask]" -ForegroundColor Cyan
        Write-Host "Download Instagram profile posts using Instaloader"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  insta username"
        Write-Host "    -> Full download using default account slot 1"
        Write-Host ""
        Write-Host "  insta username update"
        Write-Host "    -> Fast update using default account slot 1"
        Write-Host ""
        Write-Host "  insta username update 2"
        Write-Host "    -> Fast update using account slot 2"
        Write-Host ""
        Write-Host "  insta username full 3"
        Write-Host "    -> Full download using account slot 3"
        Write-Host ""
        Write-Host "  insta username update ask"
        Write-Host "    -> Ask login username manually for this run"
        Write-Host ""
        Write-Host "Modes:"
        Write-Host "  full    -> Download all posts"
        Write-Host "  update  -> Download only new posts (fast)"
        Write-Host ""
        Write-Host "Account Slots:"
        Write-Host "  1, 2, 3, 4...  -> Use saved login username from account config"
        Write-Host "  ask            -> Ask Instagram login username manually"
        Write-Host ""
        Write-Host "How account slots work:"
        Write-Host "  - If the selected slot is empty, the script asks for username"
        Write-Host "  - You can save that username to the selected slot"
        Write-Host "  - Next time, the same slot automatically uses that username"
        Write-Host ""
        Write-Host "Account config file:"
        Write-Host "  $env:LOCALAPPDATA\Instaloader\insta-accounts.json"
        Write-Host ""
        Write-Host "View/edit account slots:"
        Write-Host "  notepad ""$env:LOCALAPPDATA\Instaloader\insta-accounts.json"""
        Write-Host ""
        Write-Host "Metadata cleanup:"
        Write-Host "  - .json.xz and .txt files are moved to profile\json-data"
        Write-Host ""
        Write-Host "Notes:"
        Write-Host "  - Requires Instaloader login/session"
        Write-Host "  - Files are saved in the current directory"
        Write-Host "  - Each Instagram login account has its own saved session"
    }

    "showmeta" {
        Write-Host "showmeta ""file""" -ForegroundColor Cyan
        Write-Host "Display full media metadata"
        Write-Host ""
        Write-Host "Example:"
        Write-Host "  showmeta ""video.mkv"""
    }

    "showformat" {
        Write-Host "showformat ""url""" -ForegroundColor Cyan
        Write-Host "Display format and stream details (YouTube/online sources)"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  showformat ""https://youtu.be/..."""
        Write-Host "  Only supports URLs (Not the local files)"
        Write-Host "  For local files use showmeta"
    }

    "showlyrics" {
        Write-Host "showlyrics ""file""" -ForegroundColor Cyan
        Write-Host "Fetch and embed lyrics into audio file"
        Write-Host ""
        Write-Host "Example:"
        Write-Host "  showlyrics ""song.flac"""
    }

    "folders" {
        Write-Host "folders [path] [-Depth n] [-Filter pattern] [-Exclude patterns] [-Tree] [-ExcludeHidden]" -ForegroundColor Cyan
        Write-Host "List folders, with filtering, depth limits, and tree view"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  folders"
        Write-Host "    -> List all folders under the current directory"
        Write-Host ""
        Write-Host "  folders -Tree"
        Write-Host "    -> Same listing, shown as an indented tree"
        Write-Host ""
        Write-Host "  folders D:\Projects -Depth 2"
        Write-Host "    -> Only 2 levels deep, starting from D:\Projects"
        Write-Host ""
        Write-Host "  folders -Filter ""*cache*"""
        Write-Host "    -> Only folders with ""cache"" in the name"
        Write-Host ""
        Write-Host "  folders -Exclude @()"
        Write-Host "    -> Don't exclude anything, show every folder"
        Write-Host ""
        Write-Host "Parameters:"
        Write-Host "  path             -> Starting directory (default: current directory)"
        Write-Host "  -Depth n         -> Limit recursion to n levels deep"
        Write-Host "  -Filter pattern  -> Only show folders matching a wildcard, e.g. ""*backup*"""
        Write-Host "  -Exclude list    -> Folder name patterns to skip (defaults below)"
        Write-Host "  -Tree            -> Show as an indented tree instead of a flat path list"
        Write-Host "  -ExcludeHidden   -> Hide hidden folders (shown by default)"
        Write-Host ""
        Write-Host "Default exclusions:"
        Write-Host "  .git, node_modules, `$RECYCLE.BIN, System Volume Information, .venv, __pycache__"
        Write-Host ""
        Write-Host "Notes:"
        Write-Host "  - Hidden folders are shown in dark gray to distinguish them"
        Write-Host "  - Folders skipped due to access errors are summarized, not shown one-by-one"
        Write-Host "  - Output is sorted alphabetically by full path"
    }

    default {
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Write-Host "Use 'toolkit-help' to see available commands"
    }
}

Write-Host ""
