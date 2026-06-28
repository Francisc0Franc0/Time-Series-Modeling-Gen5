param(
  [string]$ActiveSymbols = "AMD,NVDA,TSLA,COIN,MSTR",

  [string]$RegimeContextSymbols = "AMD,NVDA,TSLA,COIN,MSTR,SMH,QQQ,SPY,IWM,TLT,GLD,VXX",

  [Parameter(Mandatory = $true)]
  [string]$EndDate,

  [Parameter(Mandatory = $true)]
  [string]$AsOfTimestamp,

  [double]$InitialCapital = 100000,

  [int]$SlotCount = 5,

  [double]$TrainQuarters = 8,

  [double]$OosQuarters = 1,

  [int]$FoldCount = 5,

  [int]$GridN = 3,

  [ValidateSet("quantile_grid", "pca_kmeans")]
  [string]$StateEngine = "quantile_grid",

  [ValidateSet("date_aligned_context", "pooled_asset_day")]
  [string]$PcaPanelMode = "pooled_asset_day",

  [int]$KmeansNstart = 30,

  [int]$MinTrainStateRows = 20,

  [string]$CandidateFamilies = "ema_cross,ema_trend,bollinger_touch,bollinger_mid_reversion,rsi_mr,zret_mr,breakout,pullback_in_uptrend,vol_expansion_breakout,donchian_breakout_vol_expand,no_trade",

  [string]$FastPeriods = "8,12",

  [string]$SlowPeriods = "30,50",

  [string]$BbLookbackPeriods = "10,20",

  [string]$BbSdMultipliers = "1.5,2",

  [ValidateSet("standard", "modest_expanded")]
  [string]$StrategyGridPreset = "standard",

  [int]$WarmupDays = 340,

  [switch]$Refresh,

  [switch]$SkipChildRuns,

  [string]$RscriptPath = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"
)

$ErrorActionPreference = "Stop"

if ($InitialCapital -le 0) {
  throw "-InitialCapital must be positive."
}
if ($SlotCount -lt 1) {
  throw "-SlotCount must be a positive integer."
}
if ($TrainQuarters -le 0) {
  throw "-TrainQuarters must be positive."
}
if ($OosQuarters -le 0) {
  throw "-OosQuarters must be positive."
}
if ($FoldCount -lt 1) {
  throw "-FoldCount must be a positive integer."
}
if ($StateEngine -eq "quantile_grid" -and ($GridN -lt 2 -or $GridN -gt 5)) {
  throw "-GridN must be between 2 and 5 for quantile grids."
}
if ($StateEngine -eq "pca_kmeans" -and ($GridN -lt 2 -or $GridN -gt 25)) {
  throw "For -StateEngine pca_kmeans, -GridN is interpreted as cluster count and must be between 2 and 25."
}
if ($KmeansNstart -lt 1) {
  throw "-KmeansNstart must be positive."
}
if ($MinTrainStateRows -lt 1) {
  throw "-MinTrainStateRows must be positive."
}
if ($WarmupDays -lt 320) {
  throw "-WarmupDays should be at least 320 for PCA feature warmup."
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir "..\..")
$rScript = Join-Path $scriptDir "run_portfolio_strategy_poc.R"

if (-not (Test-Path -LiteralPath $rScript)) {
  throw "Expected portfolio POC R script was not found: $rScript"
}
if (-not (Test-Path -LiteralPath $RscriptPath)) {
  $cmd = Get-Command Rscript -ErrorAction SilentlyContinue
  if ($null -eq $cmd) {
    throw "Rscript was not found at '$RscriptPath' and is not available on PATH."
  }
  $RscriptPath = $cmd.Source
}

$env:GEN5_PORTFOLIO_POC_ACTIVE_SYMBOLS = $ActiveSymbols
$env:GEN5_PORTFOLIO_POC_REGIME_CONTEXT_SYMBOLS = $RegimeContextSymbols
$env:GEN5_PORTFOLIO_POC_END_DATE = $EndDate
$env:GEN5_PORTFOLIO_POC_AS_OF_TIMESTAMP = $AsOfTimestamp
$env:GEN5_PORTFOLIO_POC_INITIAL_CAPITAL = [string]$InitialCapital
$env:GEN5_PORTFOLIO_POC_SLOT_COUNT = [string]$SlotCount
$env:GEN5_PORTFOLIO_POC_TRAIN_QUARTERS = [string]$TrainQuarters
$env:GEN5_PORTFOLIO_POC_OOS_QUARTERS = [string]$OosQuarters
$env:GEN5_PORTFOLIO_POC_FOLD_COUNT = [string]$FoldCount
$env:GEN5_PORTFOLIO_POC_GRID_N = [string]$GridN
$env:GEN5_PORTFOLIO_POC_STATE_ENGINE = $StateEngine
$env:GEN5_PORTFOLIO_POC_PANEL_MODE = $PcaPanelMode
$env:GEN5_PORTFOLIO_POC_KMEANS_NSTART = [string]$KmeansNstart
$env:GEN5_PORTFOLIO_POC_MIN_TRAIN_STATE_ROWS = [string]$MinTrainStateRows
$env:GEN5_PORTFOLIO_POC_CANDIDATE_FAMILIES = $CandidateFamilies
$env:GEN5_PORTFOLIO_POC_FAST_PERIODS = $FastPeriods
$env:GEN5_PORTFOLIO_POC_SLOW_PERIODS = $SlowPeriods
$env:GEN5_PORTFOLIO_POC_BB_LOOKBACK_PERIODS = $BbLookbackPeriods
$env:GEN5_PORTFOLIO_POC_BB_SD_MULTIPLIERS = $BbSdMultipliers
$env:GEN5_PORTFOLIO_POC_STRATEGY_GRID_PRESET = $StrategyGridPreset
$env:GEN5_PORTFOLIO_POC_WARMUP_DAYS = [string]$WarmupDays
$env:GEN5_PORTFOLIO_POC_REFRESH = if ($Refresh.IsPresent) { "true" } else { "false" }
$env:GEN5_PORTFOLIO_POC_SKIP_CHILD_RUNS = if ($SkipChildRuns.IsPresent) { "true" } else { "false" }

Write-Host "Gen5 Portfolio Strategy Accounting POC"
Write-Host "  Active Allocation Set: $ActiveSymbols"
Write-Host "  Regime Context Universe: $RegimeContextSymbols"
Write-Host "  End date: $EndDate"
Write-Host "  As of: $AsOfTimestamp"
Write-Host "  Initial capital: $InitialCapital"
Write-Host "  Slot count: $SlotCount"
Write-Host "  Panel mode: $PcaPanelMode"
Write-Host "  State engine: $StateEngine"
Write-Host "  Grid/cluster count: $GridN"
Write-Host "  Fold count: $FoldCount"
Write-Host "  Strategy grid preset: $StrategyGridPreset"
Write-Host "  Refresh: $($Refresh.IsPresent)"
Write-Host "  Skip child runs: $($SkipChildRuns.IsPresent)"

Push-Location $repoRoot
try {
  & $RscriptPath $rScript
  if ($LASTEXITCODE -ne 0) {
    throw "run_portfolio_strategy_poc.R failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
