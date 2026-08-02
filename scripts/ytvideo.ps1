param(
    [string]$res,
    [string]$filename,
    [string]$url
)

# -------------------------------
# Validate yt-dlp
# -------------------------------
if (-not (Get-Command yt-dlp -ErrorAction SilentlyContinue)) {
    Write-Host "yt-dlp not found. Please install and add to PATH."
    exit 1
}

# -------------------------------
# Argument handling
# -------------------------------
# Supported call styles:
#   ytvideo "filename" "URL"                  -> single video, no resolution
#   ytvideo "resolution" "filename" "URL"     -> single video, with resolution
#   ytvideo "resolution" "playlist URL"       -> playlist, auto-named, no rename
$isPlaylist = $false

if (-not $url) {
    if ($filename -match '^https?://') {
        # 2 args given, and the 2nd one is a URL -> "resolution" + "playlist URL"
        $url = $filename
        $filename = ""
        $isPlaylist = $true
    } else {
        # 2 args given, old style -> "filename" + "URL" (no resolution)
        $url = $filename
        $filename = $res
        $res = ""
    }
}

if (-not $url) {
    Write-Host 'Usage:'
    Write-Host '  ytvideo [resolution] "filename" "URL"    (single video)'
    Write-Host '  ytvideo [resolution] "playlist URL"      (playlist, auto-named)'
    exit 1
}

if (-not $isPlaylist -and -not $filename) {
    Write-Host 'Usage: ytvideo [resolution] "filename" "URL"'
    exit 1
}

# -------------------------------
# Sanitize filename (single video only)
# -------------------------------
if (-not $isPlaylist) {
    $filename = $filename -replace '[\\/:*?"<>|]', '_'
}

# -------------------------------
# Output directory
# -------------------------------
$outputDir = "YT-DLP"
if (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# -------------------------------
# Format selection
# -------------------------------
$format = "bestvideo+bestaudio/best"

switch ($res.ToLower()) {
    "4k"     { $format = "bestvideo[height<=2160][height>=1440]+bestaudio/best" }
    "2k"     { $format = "bestvideo[height<=1440][height>=1080]+bestaudio/best" }
    "1080p"  { $format = "bestvideo[height<=1080][height>=720]+bestaudio/best" }
    "720p"   { $format = "bestvideo[height<=720][height>=480]+bestaudio/best" }
    "480p"   { $format = "bestvideo[height<=480][height>=360]+bestaudio/best" }
    "360p"   { $format = "bestvideo[height<=360][height>=240]+bestaudio/best" }
    "240p"   { $format = "bestvideo[height<=240]+bestaudio/best" }
}

# -------------------------------
# Download
# -------------------------------
if ($isPlaylist) {
    Write-Host "Playlist mode: downloading with auto-generated names..."
    yt-dlp -f $format --yes-playlist --merge-output-format mkv `
        --write-subs --sub-lang en --embed-subs --ignore-errors `
        -o "$outputDir\%(playlist_index)02d - %(title)s.%(ext)s" "$url"

    Add-Content "yt-dlp-log.txt" "[$(Get-Date)] Downloaded playlist: $url"
} else {
    # Subtitle detection (single video only)
    $subs = yt-dlp --list-subs "$url" 2>$null
    $hasRealSub = $subs -match '^en ' -and $subs -notmatch 'auto-generated'

    if ($hasRealSub) {
        Write-Host "Real English subtitles found. Downloading with subtitles..."
        yt-dlp -f $format --merge-output-format mkv --sub-lang en --write-subs --embed-subs `
            -o "$outputDir\$filename.mkv" "$url"
    } else {
        Write-Host "No real English subtitles found. Downloading without subtitles..."
        yt-dlp -f $format --merge-output-format mkv `
            -o "$outputDir\$filename.mkv" "$url"
    }

    Add-Content "yt-dlp-log.txt" "[$(Get-Date)] Downloading $url as $filename.mkv"
}
