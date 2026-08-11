param(
    [string]$res,
    [string]$filename,
    [string]$url
)

# ===============================
# ytvideo.ps1
# Merged from hytvideo.ps1 (horizontal) + vytvideo.ps1 (vertical)
# Uses YouTube's fixed DASH itag numbers to pick the requested
# quality tier directly, prioritizing av01 > avc1 > vp9. Itags map
# to quality tiers consistently regardless of orientation, so this
# works correctly for vertical AND horizontal videos - including
# mixed playlists - without any width/height detection at all.
# ===============================

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
#   ytvideo "playlist URL"                    -> playlist, highest quality, auto-named
#   ytvideo "resolution" "playlist URL"       -> playlist, auto-named, no rename
#   ytvideo "filename" "URL"                  -> single video, no resolution
#   ytvideo "resolution" "filename" "URL"     -> single video, with resolution

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
    Write-Host '  ytvideo [resolution] "filename" "URL"    (single video)'
    Write-Host '  ytvideo [resolution] "playlist URL"      (playlist, auto-named)'
    Write-Host '  ytvideo "playlist URL"                   (playlist, highest quality, auto-named)'
    exit 1
}

# A playlist is detected by the URL itself, not by which args were passed
$isPlaylist = $url -match 'playlist'

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
# YouTube's DASH itags are a fixed, well-known scheme where each itag
# represents a quality tier consistently, REGARDLESS of orientation
# (e.g. itag 137 is always "the 1080p avc1 stream", whether the video
# is 1080x1920 vertical or 1920x1080 horizontal). So instead of
# filtering by width/height, we just request the itags directly for
# the chosen tier, in codec priority order: av01 -> avc1 -> vp9.
# This sidesteps the vertical/horizontal problem entirely - no
# orientation detection needed - and also avoids the square-video
# edge case a width/height filter could hit.
function Get-FormatChain([string]$res) {
    $res = $res.ToLower()

    # av01, avc1, vp9 itags per tier (avc1 has no standard 1440p/2160p
    # DASH itag on most videos, so those tiers only offer av01/vp9)
    $itagMap = @{
        "4k"    = @("401", "313")
        "2k"    = @("400", "271")
        "1080p" = @("399", "137", "248")
        "720p"  = @("398", "136", "247")
        "480p"  = @("397", "135", "244")
        "360p"  = @("396", "134", "243")
        "240p"  = @("395", "133", "242")
    }

    if (-not $itagMap.ContainsKey($res)) {
        return "bestvideo+bestaudio/best"
    }

    $chain = $itagMap[$res] -join "/"
    # Safety net: if none of the fixed itags exist on this video
    # (rare/older content that doesn't follow the standard scheme),
    # fall back to a generic bestvideo+bestaudio before the final
    # single-file "best" fallback.
    return "($chain)+bestaudio/bestvideo+bestaudio/best"
}

# -------------------------------
# Download
# -------------------------------
$format = Get-FormatChain $res

if ($isPlaylist) {
    Write-Host "Playlist mode: downloading with auto-generated names (each video's orientation is resolved individually)..."
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
