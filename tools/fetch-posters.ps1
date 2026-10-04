# OPTIONAL: creates show-posters.js (small poster thumbnails from TMDB) for LOCAL use only.
# The file is listed in .gitignore on purpose: posters are studio artwork and TMDB content,
# so they should not be committed or redistributed in a public repository.
#
# Requirements: a free TMDB account and its "API Key" (themoviedb.org/settings/api).
# TMDB's terms: personal / non-commercial use unless you have a written agreement with TMDB,
# attribution required, and TMDB data may not be cached longer than 6 months.
#
# Usage:
#   $env:TMDB_KEY = "your-tmdb-api-key"
#   powershell -ExecutionPolicy Bypass -File .\tools\fetch-posters.ps1
#   powershell -ExecutionPolicy Bypass -File .\tools\fetch-posters.ps1 -Out C:\somewhere\show-posters.js
param([string]$Out = (Join-Path $PSScriptRoot "..\show-posters.js"))
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$key = $env:TMDB_KEY
if (-not $key) { throw "Set `$env:TMDB_KEY to your TMDB API key first." }

$db = Get-Content (Join-Path $PSScriptRoot "..\shows-database.js") -Raw -Encoding UTF8
$shows = [regex]::Matches($db, '(?m)^\s*S\("([^"]+)", "([^"]+)", "([^"]+)", (\d+),') | ForEach-Object {
  [pscustomobject]@{ id = $_.Groups[1].Value; name = $_.Groups[2].Value; type = $_.Groups[3].Value }
}

# show id -> "kind|search query" (kind: tv, movie, collection). Anything not listed uses the defaults below.
$ov = @{
  mickey = "tv|Mickey Mouse Clubhouse"; bluesclues = "tv|Blue's Clues & You!"; peanuts = "tv|The Snoopy Show"
  garfield = "tv|The Garfield Show"; scoobydoo = "tv|Scooby-Doo, Where Are You!"; ninjago = "tv|Ninjago: Masters of Spinjitzu"
  powerrangers = "tv|Mighty Morphin Power Rangers"; muppets = "tv|The Muppet Show"; dragonball = "tv|Dragon Ball Z"
  suitelife = "tv|The Suite Life of Zack & Cody"; legomasters = "tv|LEGO Masters"; hellokitty = "tv|Hello Kitty"
  percy = "tv|Percy Jackson and the Olympians"; geronimo = "tv|Geronimo Stilton"; avatar = "tv|Avatar: The Last Airbender"
  onepiece = "tv|One Piece"; pooh = "tv|Winnie the Pooh"; tmnt = "tv|Teenage Mutant Ninja Turtles"
  ghibli = "movie|Spirited Away"; barbie = "movie|Barbie"; mario = "movie|The Super Mario Bros. Movie"
  minecraft = "movie|A Minecraft Movie"; dogman = "movie|Dog Man"; badguys = "movie|The Bad Guys"
  sonic = "collection|Sonic the Hedgehog"; angrybirds = "collection|The Angry Birds Movie"; wimpy = "collection|Diary of a Wimpy Kid"
  narnia = "collection|The Chronicles of Narnia"; goosebumps = "collection|Goosebumps"
  marvel = "collection|The Avengers"; spiderman = "collection|Spider-Man"; starwars = "collection|Star Wars"
  hogwarts = "collection|Harry Potter"; dc = "collection|The Dark Knight"; lionking = "collection|The Lion King"
  despicable = "collection|Despicable Me"; nemo = "collection|Finding Nemo"; lilo = "collection|Lilo & Stitch"
  monsters = "collection|Monsters, Inc."; jurassic = "collection|Jurassic Park"; lotr = "collection|The Lord of the Rings"
  httyd = "collection|How to Train Your Dragon"; incredibles = "collection|The Incredibles"; legomovie = "collection|The LEGO Movie"
}
# Hand-picked TMDB ids where the first search result was the wrong version
$fix = @{
  avatar = "tv/246"; hxh = "tv/46298"; digimon = "tv/31654"; powerrangers = "tv/2328"; tomjerry = "tv/47480"
  ben10 = "tv/4686"; fullhouse = "tv/4313"; pooh = "tv/2005"; insideout = "movie/150540"; trolls = "collection/489724"
  tinkerbell = "collection/315595"; zombies = "movie/483980"; narnia = "collection/420"; wallacegromit = "collection/529"
  teletubbies = "tv/1682"
}
$skip = @("princesses", "lego", "hotwheels", "lol", "squishmallows", "roalddahl", "drseuss", "warriors", "magictreehouse")

function Norm($s) { ($s.ToLower() -replace "[^a-z0-9]", "") }
function Api($path, $q) {
  $u = "https://api.themoviedb.org/3/$path" + "?api_key=$key&query=" + [uri]::EscapeDataString($q)
  for ($i = 0; $i -lt 3; $i++) { try { return Invoke-RestMethod -Uri $u -TimeoutSec 30 } catch { Start-Sleep -Milliseconds 500 } }
  return $null
}
function Pick($results, $q) {
  $nq = Norm $q; $best = $null; $bestScore = -1; $i = 0
  foreach ($r in ($results | Select-Object -First 6)) {
    $title = if ($r.name) { $r.name } else { $r.title }
    if (-not $r.poster_path) { $i++; continue }
    $nt = Norm $title; $score = 0
    if ($nt -eq $nq) { $score += 100 } elseif ($nt.StartsWith($nq) -or $nq.StartsWith($nt)) { $score += 60 } elseif ($nt.Contains($nq)) { $score += 40 }
    $score += [math]::Min(30, [double]($r.popularity) / 10) - $i
    if ($score -gt $bestScore) { $best = $r; $bestScore = $score }
    $i++
  }
  return $best
}

Write-Host "Searching TMDB..."
$found = @()
foreach ($s in $shows) {
  if ($skip -contains $s.id) { continue }
  $poster = $null
  if ($fix.ContainsKey($s.id)) {
    $d = Invoke-RestMethod -Uri ("https://api.themoviedb.org/3/" + $fix[$s.id] + "?api_key=$key") -TimeoutSec 30
    $poster = $d.poster_path
  } else {
    $kind = $null; $q = $null
    if ($ov.ContainsKey($s.id)) { $p = $ov[$s.id].Split("|", 2); $kind = $p[0]; $q = $p[1] }
    elseif ($s.type -eq "TV" -or $s.type -eq "Anime") { $kind = "tv"; $q = ($s.name -replace "\s*\(.*?\)", "") }
    elseif ($s.type -eq "Movie") { $kind = "collection"; $q = ($s.name -replace "\s*\(.*?\)", "") }
    else { continue }   # games, books and toys without an override keep their initials tile
    $res = Api "search/$kind" $q
    $hit = $null
    if ($res) { $hit = Pick $res.results $q }
    if (-not $hit -and $kind -eq "collection") { $res = Api "search/movie" $q; if ($res) { $hit = Pick $res.results $q } }
    if ($hit) { $poster = $hit.poster_path }
  }
  if ($poster) { $found += [pscustomobject]@{ id = $s.id; poster = $poster } }
  Start-Sleep -Milliseconds 60
}

Write-Host "Downloading $($found.Count) thumbnails..."
$lines = @(
  "// Poster thumbnails (92px wide) for the show cards, from TMDB. LOCAL USE ONLY: do not commit.",
  "// This product uses TMDB and the TMDB APIs but is not endorsed, certified, or otherwise approved by TMDB.",
  "const POSTERS = {"
)
$n = 0
foreach ($m in $found) {
  $n++
  try {
    $r = Invoke-WebRequest -Uri ("https://image.tmdb.org/t/p/w92" + $m.poster) -UseBasicParsing -TimeoutSec 30
    $comma = if ($n -lt $found.Count) { "," } else { "" }
    $lines += ('  "' + $m.id + '": "data:image/jpeg;base64,' + [Convert]::ToBase64String($r.Content) + '"' + $comma)
  } catch { Write-Warning "Failed: $($m.id)" }
  Start-Sleep -Milliseconds 40
}
$lines += "};"

# TMDB's attribution logo (required whenever TMDB content is shown)
try {
  $logo = Invoke-WebRequest -Uri "https://www.themoviedb.org/assets/v4/logos/v2/blue_short-8e7b30f73a4020692ccca9c88bafe5dcb6f8a62a4c6bc55cd9ba82bb2cd95f6c.svg" -UseBasicParsing -TimeoutSec 30
  $lines += ('const TMDB_LOGO = "data:image/svg+xml;base64,' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$logo.Content)) + '";')
} catch { Write-Warning "Could not download the TMDB logo; add it manually for attribution." }

[IO.File]::WriteAllLines($Out, $lines, (New-Object Text.UTF8Encoding $false))
Write-Host "Wrote $Out. Now run build.ps1 to embed it."
