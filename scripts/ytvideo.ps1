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
# Cookie / bot-check handling
# -------------------------------
# Cookie args are kept in script scope so that once the user opts in,
# every later yt-dlp call in this run (subtitle re-check, retry, each
# playlist attempt) reuses the same browser without asking again.
$script:cookieArgs = @()

# Errors that mean "YouTube wants authentication", not "the video is broken"
function Test-NeedsCookies([string]$text) {
    if (-not $text) { return $false }
    return (
        $text -match "Sign in to confirm you" -or
        $text -match "confirm you.{0,3}re not a bot" -or
        $text -match "HTTP Error 429" -or
        $text -match "Too Many Requests" -or
        $text -match "Use --cookies-from-browser" -or
        $text -match "This video is only available to Music Premium members" -or
        $text -match "Please sign in"
    )
}

# Ask the user whether to retry with browser cookies, and which browser.
# Returns $true if cookies were enabled.
function Request-Cookies {
    if ($script:cookieArgs.Count -gt 0) { return $true }   # already enabled

    Write-Host ""
    Write-Host "YouTube blocked that request (bot check / rate limit)." -ForegroundColor Yellow
    $answer = Read-Host "Would you like to retry using cookies from your browser? (y/n)"

    if ($answer -notmatch '^(y|yes)$') {
        Write-Host "Continuing without cookies." -ForegroundColor Yellow
        return $false
    }

    $browser = Read-Host "Which browser? (firefox/chrome/edge/brave/opera/vivaldi/chromium) [firefox]"
    if ([string]::IsNullOrWhiteSpace($browser)) { $browser = "firefox" }
    $browser = $browser.Trim().ToLower()

    $script:cookieArgs = @("--cookies-from-browser", $browser)
    Write-Host "Retrying with cookies from $browser..." -ForegroundColor Cyan
    Add-Content "yt-dlp-log.txt" "[$(Get-Date)] Enabled --cookies-from-browser $browser for: $url"
    return $true
}

# Run yt-dlp with the current cookie args, echoing output live while also
# capturing it so we can inspect it for auth errors afterwards.
# Returns a hashtable: @{ Success = bool; Output = string }
function Invoke-YtDlp([string[]]$Arguments) {
    $allArgs = @()
    if ($script:cookieArgs.Count -gt 0) { $allArgs += $script:cookieArgs }
    $allArgs += $Arguments

    # --newline keeps the progress readable: yt-dlp normally redraws one
    # line with carriage returns, which turns to mush once piped.
    $captured = & yt-dlp --newline @allArgs 2>&1 | ForEach-Object {
        Write-Host $_
        $_
    }
    $ok = ($LASTEXITCODE -eq 0)

    return @{ Success = $ok; Output = ($captured -join "`n") }
}

# -------------------------------
# Download
# -------------------------------
$format = Get-FormatChain $res

# Build the yt-dlp argument list for the current mode.
# Subtitle detection is re-run on retry, because the first check may
# itself have been blocked (silently reporting "no subtitles").
function Get-DownloadArgs {
    if ($isPlaylist) {
        Write-Host "Playlist mode: downloading with auto-generated names (each video's orientation is resolved individually)..."
        return @(
            "-f", $format, "--yes-playlist", "--merge-output-format", "mkv",
            "--write-subs", "--sub-lang", "en", "--embed-subs", "--ignore-errors",
            "-o", "$outputDir\%(playlist_index)02d - %(title)s.%(ext)s", $url
        )
    }

    $subsArgs = @()
    if ($script:cookieArgs.Count -gt 0) { $subsArgs += $script:cookieArgs }
    $subsArgs += @("--list-subs", $url)
    $subs = (& yt-dlp @subsArgs 2>$null) -join "`n"
    $hasRealSub = $subs -match '(?m)^en ' -and $subs -notmatch 'auto-generated'

    if ($hasRealSub) {
        Write-Host "Real English subtitles found. Downloading with subtitles..."
        return @(
            "-f", $format, "--merge-output-format", "mkv",
            "--sub-lang", "en", "--write-subs", "--embed-subs",
            "-o", "$outputDir\$filename.mkv", $url
        )
    }

    Write-Host "No real English subtitles found. Downloading without subtitles..."
    return @(
        "-f", $format, "--merge-output-format", "mkv",
        "-o", "$outputDir\$filename.mkv", $url
    )
}

$result = Invoke-YtDlp (Get-DownloadArgs)

# If it failed because YouTube wants auth, offer to retry with cookies
if (-not $result.Success -and (Test-NeedsCookies $result.Output)) {
    if (Request-Cookies) {
        $result = Invoke-YtDlp (Get-DownloadArgs)
    }
}

if ($isPlaylist) {
    Add-Content "yt-dlp-log.txt" "[$(Get-Date)] Downloaded playlist: $url"
} else {
    Add-Content "yt-dlp-log.txt" "[$(Get-Date)] Downloading $url as $filename.mkv"
}

if (-not $result.Success) {
    Write-Host ""
    Write-Host "Download failed." -ForegroundColor Red
    if (Test-NeedsCookies $result.Output) {
        Write-Host "YouTube is still refusing the request. Things to try:" -ForegroundColor Yellow
        Write-Host "  - Make sure you're signed in to YouTube in the browser you picked"
        Write-Host "  - Close that browser fully (it can lock its cookie database), then retry"
        Write-Host "  - Wait a while if you've been rate-limited (HTTP 429)"
    }
    exit 1
}
