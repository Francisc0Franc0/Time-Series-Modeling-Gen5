$ErrorActionPreference = "Continue"
$repo = "C:\Users\Franc\OneDrive\Documents\Francis\Peltata Project\Time-Series-Modeling-Gen5"
$log = Join-Path $repo "runs\research_workbench\ms_p0_candidate_atlas.log"
$done = Join-Path $repo "runs\research_workbench\ms_p0_candidate_atlas.completed.txt"
Set-Content -LiteralPath $done -Value "RUNNING" -Encoding ASCII
$rscript = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"

function Invoke-CandidateWindow([string] $family, [int] $year) {
  $codes = @{
    ema_trend = "et"; ema_cross = "ec"; bollinger_touch = "bt"; bollinger_mid_reversion = "bm"
    rsi_mr = "rs"; zret_mr = "zr"; breakout = "br"; pullback_in_uptrend = "pb"
  }
  $runLabel = "m2$($codes[$family])$($year.ToString().Substring(2, 2))"
  # The WFA uses four fixed 91-day OOS folds. A named year therefore needs the
  # first post-year-end session available to complete the fourth fold.
  $startYear = $year - 2
  $endYear = $year + 1
  $env:GEN5_WFA_BATCH_AS_OF_TIMESTAMP = "$endYear-01-03 17:30:00"
  $env:GEN5_WFA_BATCH_SYMBOLS = "AMD,NVDA,TSLA,MSTR,AVGO"
  $env:GEN5_WFA_BATCH_START_DATE = "$startYear-01-01"
  $env:GEN5_WFA_BATCH_END_DATE = "$endYear-01-03"
  $env:GEN5_WFA_BATCH_FOLD_COUNT = "4"
  # The raw candidate competes with both Gen5.2 abstention semantics.
  $env:GEN5_WFA_BATCH_CANDIDATE_FAMILIES = "$family,no_trade_exit_immediate"
  # Short folder tags keep Windows output paths below MAX_PATH while retaining unique provenance.
  $env:GEN5_WFA_BATCH_RUN_LABEL = $runLabel
  $env:GEN5_WFA_BATCH_OUTPUT_PREFIX = $runLabel
  $env:GEN5_WFA_BATCH_MAX_HOLD_SESSIONS = "9999"
  $env:GEN5_WFA_BATCH_STOP_LOSS_PCTS = "0.99"
  $env:GEN5_WFA_BATCH_TAKE_PROFIT_PCTS = "9"
  if ($family -eq "ema_trend") {
    $env:GEN5_WFA_BATCH_EMA_TREND_FAST_PERIODS = "1,5,10,15,20"
    $env:GEN5_WFA_BATCH_EMA_TREND_SLOW_PERIODS = "10,15,20,50,75"
  }
  Set-Location -LiteralPath $repo
  & $rscript (Join-Path $repo "scripts\inspect\run_multi_asset_wfa_batch.R") *>> $log
  if ($LASTEXITCODE -ne 0) { throw "Raw WFA failed: $family $year" }
  $root = Join-Path $repo "runs\research_workbench\wfa_pocs\$runLabel"
  $env:GEN5_MS_P0_ROOT = $root
  & $rscript (Join-Path $repo "scripts\inspect\run_ms_p0_ema_trend_state_map.R") *>> $log
  if ($LASTEXITCODE -ne 0) { throw "State map failed: $family $year" }
}

try {
  foreach ($year in 2020..2024) { Invoke-CandidateWindow "ema_trend" $year }
  foreach ($family in @("ema_cross","bollinger_touch","bollinger_mid_reversion","rsi_mr","zret_mr","breakout","pullback_in_uptrend")) {
    foreach ($year in 2020..2024) { Invoke-CandidateWindow $family $year }
  }
  Set-Content -LiteralPath $done -Value ("Completed " + (Get-Date -Format o)) -Encoding ASCII
} catch {
  $_ | Out-File -LiteralPath $log -Append -Encoding ASCII
  exit 1
}
