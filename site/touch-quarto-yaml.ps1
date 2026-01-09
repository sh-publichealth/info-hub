param(
  [string]$ProjectRoot = (Get-Location).Path,
  [string]$QuartoYaml  = "_quarto.yml",

  # Roots to poll, semicolon-separated relative to ProjectRoot (same as your WATCH_DIRS)
  [string]$WatchDirs   = "",

  # Polling interval (ms)
  [int]$PollMs         = 1000,

  # Quiet period: only update once no new changes have been seen for this long
  [int]$QuietMs        = 1500
)

$yamlPath = Join-Path $ProjectRoot $QuartoYaml
if (-not (Test-Path $yamlPath)) {
  throw "Can't find $yamlPath (expected _quarto.yml in project root)."
}

# Source file extensions to consider as “meaningful changes”
$patterns = @(
  "*.qmd","*.md","*.yml","*.yaml",
  "*.css","*.scss",
  "*.js","*.ts",
  "*.json",
  "*.bib","*.csl",
  "*.lua"
)

# Determine poll roots
$roots = @()
if ([string]::IsNullOrWhiteSpace($WatchDirs)) {
  $roots += $ProjectRoot
} else {
  $parts = $WatchDirs.Split(";") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
  foreach ($rel in $parts) {
    $full = Join-Path $ProjectRoot $rel
    if (Test-Path $full) { $roots += $full } else { Write-Host "WARNING: watch dir not found: $full" }
  }
  if ($roots.Count -eq 0) { $roots += $ProjectRoot }
}

function Update-QuartoYamlTouchMarker {
  $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  $tag   = "# touch: "

  $lines = Get-Content -LiteralPath $yamlPath -ErrorAction Stop

  if ($lines.Count -gt 0 -and $lines[-1].StartsWith($tag)) {
    $lines[-1] = "$tag$stamp"
  } else {
    $lines = @($lines) + "$tag$stamp"
  }

  # Write back UTF8 (no BOM) to avoid encoding surprises
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllLines($yamlPath, $lines, $utf8NoBom)

  Write-Host ("Updated _quarto.yml touch marker at {0}" -f $stamp)
}

Write-Host "Polling roots:"
$roots | ForEach-Object { Write-Host "  - $_" }
Write-Host "Poll interval: $PollMs ms"
Write-Host "Quiet period:  $QuietMs ms"
Write-Host "Touch target:  $yamlPath"
Write-Host "Press Ctrl+C to stop."

# Track the newest modification time we've seen
$lastMaxUtcTicks = 0L

# Coalescing state
$pending = $false
$lastChangeSeen = Get-Date "2000-01-01"

while ($true) {
  $maxUtc = $null

  foreach ($r in $roots) {
    foreach ($pat in $patterns) {
      Get-ChildItem -LiteralPath $r -Recurse -File -Filter $pat -ErrorAction SilentlyContinue |
        ForEach-Object {
          # Ignore _quarto.yml itself to avoid loops
          if ($_.FullName -ieq $yamlPath) { return }
          $t = $_.LastWriteTimeUtc
          if ($null -eq $maxUtc -or $t -gt $maxUtc) { $maxUtc = $t }
        }
    }
  }

  if ($null -ne $maxUtc) {
    $ticks = $maxUtc.Ticks
    if ($ticks -gt $lastMaxUtcTicks) {
      $lastMaxUtcTicks = $ticks
      $pending = $true
      $lastChangeSeen = Get-Date
      Write-Host ("Change seen (latest file write at UTC {0:HH:mm:ss.fff})" -f $maxUtc)
    }
  }

  if ($pending) {
    $since = (Get-Date) - $lastChangeSeen
    if ($since.TotalMilliseconds -ge $QuietMs) {
      $pending = $false
      Update-QuartoYamlTouchMarker
    }
  }

  Start-Sleep -Milliseconds $PollMs
}
