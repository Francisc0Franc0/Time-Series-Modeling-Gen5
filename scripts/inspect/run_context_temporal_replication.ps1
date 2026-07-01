param(
  [string]$ActiveSymbols = "AMD,NVDA,TSLA,META,MSTR",

  [string]$WindowDates = "2024-12-31,2025-03-31,2025-06-30,2025-09-30,2025-12-31,2026-03-31,2026-06-23",

  [string]$AsOfTime = "17:30:00",

  [switch]$Refresh,

  [switch]$SkipChildRuns,

  [string]$RscriptPath = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$contextRunner = Join-Path $scriptDir "run_context_universe_factorial_portfolio.ps1"

if (-not (Test-Path -LiteralPath $contextRunner)) {
  throw "Expected context factorial runner was not found: $contextRunner"
}

$dates = $WindowDates.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }
if ($dates.Count -lt 1) {
  throw "-WindowDates must include at least one yyyy-mm-dd date."
}

Write-Host "Gen5.1 Temporal Context Replication"
Write-Host "  Active symbols: $ActiveSymbols"
Write-Host "  Windows: $($dates -join ', ')"
Write-Host "  Surfaces: behavioral_pool quantile 3x3 and fixed k9"
Write-Host "  Context universes: active_self, active_plus_risk, ex_active_market_risk"
Write-Host "  Refresh: $($Refresh.IsPresent)"
Write-Host "  Skip child runs: $($SkipChildRuns.IsPresent)"
Write-Host "  Research/inspection only; portfolio accounting is not accepted allocation evidence."

foreach ($date in $dates) {
  $asOfTimestamp = "$date $AsOfTime"
  Write-Host ""
  Write-Host "=== Temporal context replication window: $date / $asOfTimestamp ==="
  $params = @{
    ActiveSymbols = $ActiveSymbols
    EndDate = $date
    AsOfTimestamp = $asOfTimestamp
    TemporalContextReplication = $true
    RscriptPath = $RscriptPath
  }
  if ($Refresh.IsPresent) {
    $params.Refresh = $true
  }
  if ($SkipChildRuns.IsPresent) {
    $params.SkipChildRuns = $true
  }
  & $contextRunner @params
  if ($LASTEXITCODE -ne 0) {
    throw "Temporal context replication failed for $date with exit code $LASTEXITCODE."
  }
}
