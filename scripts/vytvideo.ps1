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
#   vytvideo "playlist URL"                    -> playlist, highest quality, auto-named
#   vytvideo "resolution" "playlist URL"       -> playlist, auto-named, no rename
#   vytvideo "filename" "URL"                  -> single video, no resolution
#   vytvideo "resolution" "filename" "URL"     -> single video, with resolution

if (-not $filename -and -not $url) {
    # Only 1 arg supplied -> could be a bare URL (no resolution, no filename)
    if ($res -match '^https?://') {
        $url = $res
        $res = ""
    }
} elseif (-not $url) {
    # 2 args supplied
    if ($filename -match '^https?://') {
        # "resolution" + "URL"
        $url = $filename
        $filename = ""
    } else {
        # "filename" + "URL" (old style, no resolution)
        $url = $filename
        $filename = $res
        $res = ""
    }
}

if (-not $url) {
    Write-Host 'Usage:'
    Write-Host '  vytvideo [resolution] "filename" "URL"    (single video)'
    Write-Host '  vytvideo [resolution] "playlist URL"      (playlist, auto-named)'
    Write-Host '  vytvideo "playlist URL"                   (playlist, highest quality, auto-named)'
    exit 1
}

# A playlist is detected by the URL itself, not by which args were passed
$isPlaylist = $url -match 'playlist'

if (-not $isPlaylist -and -not $filename) {
    Write-Host 'Usage: vytvideo [resolution] "filename" "URL"'
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
# Resolution mapping (width-based, codec-specific — for vertical video)
# -------------------------------
$target = 0
switch ($res.ToLower()) {
    "4k"    { $target = 2160 }
    "2k"    { $target = 1440 }
    "1080p" { $target = 1080 }
    "720p"  { $target = 720 }
    "480p"  { $target = 480 }
    "360p"  { $target = 360 }
    "240p"  { $target = 240 }
}

$upper = $target + 1

# Format selector: prefer av01, then avc1, then vp9, pinned to exact width
if ($target -gt 0) {
    $format = "(bestvideo[vcodec=av01][width>=$target][width<$upper]/bestvideo[vcodec=avc1][width>=$target][width<$upper]/bestvideo[vcodec=vp9][width>=$target][width<$upper])+bestaudio/best"
} else {
    $format = "bestvideo+bestaudio/best"
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
