param(
    [Parameter(Position = 0)]
    [string]$Path = ".",

    [int]$Depth,

    [string[]]$Exclude = @('.git', 'node_modules', '$RECYCLE.BIN', 'System Volume Information', '.venv', '__pycache__'),

    [string]$Filter,

    [switch]$Tree,

    [switch]$ExcludeHidden
)

if (-not (Test-Path $Path)) {
    Write-Host "✖ Path not found: $Path" -ForegroundColor Red
    return
}

$resolvedRoot = (Resolve-Path $Path).ProviderPath

Write-Host "Listing folders under: $resolvedRoot" -ForegroundColor Cyan
if ($Depth) { Write-Host "Depth limit: $Depth" -ForegroundColor DarkGray }
if ($Filter) { Write-Host "Filter: $Filter" -ForegroundColor DarkGray }
if ($Exclude) { Write-Host "Excluding: $($Exclude -join ', ')" -ForegroundColor DarkGray }
Write-Host ""

# Collect errors (e.g. access-denied on protected system folders) instead of
# letting them spam the console - report a single summary count at the end.
$errs = $null
$gciParams = @{
    Path         = $resolvedRoot
    Directory    = $true
    Recurse      = $true
    Force        = -not $ExcludeHidden
    ErrorAction  = 'SilentlyContinue'
    ErrorVariable = 'errs'
}
if ($Depth) { $gciParams['Depth'] = $Depth }

$folders = Get-ChildItem @gciParams | Where-Object {
    $name = $_.Name
    $excluded = $false
    foreach ($pattern in $Exclude) {
        if ($name -like $pattern) { $excluded = $true; break }
    }
    if ($excluded) { return $false }
    if ($Filter -and $name -notlike $Filter) { return $false }
    return $true
} | Sort-Object FullName

if (-not $folders) {
    Write-Host "No matching folders found." -ForegroundColor Yellow
} elseif ($Tree) {
    foreach ($folder in $folders) {
        $relative = $folder.FullName.Substring($resolvedRoot.Length).TrimStart('\', '/')
        $level = ($relative -split '[\\/]').Count - 1
        $indent = '  ' * $level
        $isHidden = $folder.Attributes -band [System.IO.FileAttributes]::Hidden
        $color = if ($isHidden) { 'DarkGray' } else { 'White' }
        Write-Host "$indent├─ $($folder.Name)" -ForegroundColor $color
    }
} else {
    foreach ($folder in $folders) {
        $isHidden = $folder.Attributes -band [System.IO.FileAttributes]::Hidden
        $color = if ($isHidden) { 'DarkGray' } else { 'White' }
        Write-Host $folder.FullName -ForegroundColor $color
    }
}

Write-Host ""
Write-Host "Found $($folders.Count) folder(s)." -ForegroundColor Cyan
if ($errs -and $errs.Count -gt 0) {
    Write-Host "Skipped $($errs.Count) folder(s) due to access errors." -ForegroundColor Yellow
}
