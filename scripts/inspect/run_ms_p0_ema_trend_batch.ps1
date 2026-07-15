$ErrorActionPreference = "Continue"
$repo = "C:\Users\Franc\OneDrive\Documents\Francis\Peltata Project\Time-Series-Modeling-Gen5"
$logDir = Join-Path $repo "runs\research_workbench"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$stdout = Join-Path $logDir "ms_p0_ema_trend.log"
$stderr = Join-Path $logDir "ms_p0_ema_trend.err.log"
$done = Join-Path $logDir "ms_p0_ema_trend.completed.txt"
Set-Content -LiteralPath $done -Value "RUNNING" -Encoding ASCII

$env:GEN5_WFA_BATCH_AS_OF_TIMESTAMP = "2020-12-31 17:30:00"
$env:GEN5_WFA_BATCH_SYMBOLS = "AMD,NVDA,TSLA,MSTR,AVGO"
$env:GEN5_WFA_BATCH_START_DATE = "2018-01-01"
$env:GEN5_WFA_BATCH_END_DATE = "2020-12-31"
$env:GEN5_WFA_BATCH_FOLD_COUNT = "4"
$env:GEN5_WFA_BATCH_CANDIDATE_FAMILIES = "ema_trend"
$env:GEN5_WFA_BATCH_EMA_TREND_FAST_PERIODS = "1,5,10,15,20"
$env:GEN5_WFA_BATCH_EMA_TREND_SLOW_PERIODS = "10,15,20,50,75"
$env:GEN5_WFA_BATCH_MAX_HOLD_SESSIONS = "9999"
$env:GEN5_WFA_BATCH_STOP_LOSS_PCTS = "0.99"
$env:GEN5_WFA_BATCH_TAKE_PROFIT_PCTS = "9"

try {
  Set-Location -LiteralPath $repo
  & "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" (Join-Path $repo "scripts\inspect\run_multi_asset_wfa_batch.R") *>> $stdout
  if ($LASTEXITCODE -ne 0) { throw "MS-P0 R batch failed with exit code $LASTEXITCODE. See $stdout" }
  Set-Content -LiteralPath $done -Value ("Completed " + (Get-Date -Format o)) -Encoding ASCII
} catch {
  $_ | Out-File -LiteralPath $stderr -Append -Encoding ASCII
  exit 1
}
