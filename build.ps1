# Builds dist/worksheet-workshop.html from the source page.
#
#   - Refreshes the show list from shows-database.js
#   - If show-posters.js exists (local only, listed in .gitignore), embeds the poster thumbnails
#
# Usage:  powershell -ExecutionPolicy Bypass -File .\build.ps1
#         powershell -ExecutionPolicy Bypass -File .\build.ps1 -PostersPath C:\path\to\show-posters.js
param([string]$PostersPath = (Join-Path $PSScriptRoot "show-posters.js"))
$ErrorActionPreference = "Stop"

$srcPath = Join-Path $PSScriptRoot "worksheet-workshop.html"
$dbPath = Join-Path $PSScriptRoot "shows-database.js"
$h = (Get-Content $srcPath -Raw -Encoding UTF8) -replace "`r`n", "`n"
$db = ((Get-Content $dbPath -Raw -Encoding UTF8) -replace "`r`n", "`n").TrimEnd()

# 1) Show database
$showBegin = "// ---- BEGIN SHOWS (generated from shows-database.js by build.ps1; edit that file, then rebuild)"
$showEnd = "// ---- END SHOWS"
$rxShows = "(?s)// ---- BEGIN SHOWS.*?" + [regex]::Escape($showEnd)
if (-not [regex]::IsMatch($h, $rxShows)) { throw "SHOWS markers not found in worksheet-workshop.html" }
$showsBlock = $showBegin + "`n" + $db + "`n" + $showEnd
$h = [regex]::Replace($h, $rxShows, { param($m) $showsBlock })

# 2) Posters (optional)
$postBegin = "// ---- BEGIN POSTERS (TMDB thumbnails; replace between the markers to update)"
$postEnd = "// ---- END POSTERS"
$rxPosters = "(?s)" + [regex]::Escape($postBegin) + ".*?" + [regex]::Escape($postEnd)
if (-not [regex]::IsMatch($h, $rxPosters)) { throw "POSTERS markers not found in worksheet-workshop.html" }
if (Test-Path $PostersPath) {
  $posters = ((Get-Content $PostersPath -Raw -Encoding UTF8) -replace "`r`n", "`n").TrimEnd()
  $postBlock = $postBegin + "`n" + $posters + "`n" + $postEnd
  $h = [regex]::Replace($h, $rxPosters, { param($m) $postBlock })
  $postersNote = "with posters"
} else {
  $postersNote = "WITHOUT posters (no show-posters.js found; shows use initials tiles)"
}

$distDir = Join-Path $PSScriptRoot "dist"
New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$outPath = Join-Path $distDir "worksheet-workshop.html"
[IO.File]::WriteAllText($outPath, $h, (New-Object Text.UTF8Encoding $false))
"Built $outPath ($([math]::Round((Get-Item $outPath).Length / 1024)) KB), $postersNote."
