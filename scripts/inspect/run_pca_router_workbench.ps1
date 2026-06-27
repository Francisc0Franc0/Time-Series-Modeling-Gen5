param(
  [string]$Symbol = "AMD",

  [Parameter(Mandatory = $true)]
  [string]$EndDate,

  [Parameter(Mandatory = $true)]
  [string]$AsOfTimestamp,

  [string]$RegimeContextSymbols = "",

  [ValidateSet("contextual_snapshot", "behavioral_pool")]
  [string]$PanelMode = "contextual_snapshot",

  [ValidateSet("quantile_grid", "kmeans")]
  [string]$StateMap = "quantile_grid",

  [double]$TrainQuarters = 8,

  [double]$OosQuarters = 1,

  [int]$FoldCount = 5,

  [int]$StateCount = 3,

  [int]$KmeansNstart = 30,

  [int]$MinTrainStateRows = 20,

  [string]$CandidateFamilies = "ema_cross,ema_trend,bollinger_touch,bollinger_mid_reversion,rsi_mr,zret_mr,breakout,pullback_in_uptrend,vol_expansion_breakout,donchian_breakout_vol_expand,no_trade",

  [string]$FastPeriods = "8,12",

  [string]$SlowPeriods = "30,50",

  [string]$BbLookbackPeriods = "10,20",

  [string]$BbSdMultipliers = "1.5,2",

  [int]$WarmupDays = 340,

  [switch]$Refresh,

  [string]$RscriptPath = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"
)

$ErrorActionPreference = "Stop"

$pcaPanelMode = switch ($PanelMode) {
  "contextual_snapshot" { "date_aligned_context" }
  "behavioral_pool" { "pooled_asset_day" }
}
$stateEngine = switch ($StateMap) {
  "quantile_grid" { "quantile_grid" }
  "kmeans" { "pca_kmeans" }
}

if ($StateMap -eq "quantile_grid" -and ($StateCount -lt 2 -or $StateCount -gt 5)) {
  throw "-StateCount must be between 2 and 5 for -StateMap quantile_grid."
}
if ($StateMap -eq "kmeans" -and ($StateCount -lt 2 -or $StateCount -gt 25)) {
  throw "-StateCount must be between 2 and 25 for -StateMap kmeans."
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$runner = Join-Path $scriptDir "run_pca_wfa_router_poc.ps1"
if (-not (Test-Path -LiteralPath $runner)) {
  throw "Expected PCA WFA router runner was not found: $runner"
}

Write-Host "Gen5 PCA router workbench"
Write-Host "  Panel mode: $PanelMode -> $pcaPanelMode"
Write-Host "  State map: $StateMap -> $stateEngine"
Write-Host "  State count/grid: $StateCount"
Write-Host "  Regime Context Universe: $RegimeContextSymbols"
Write-Host "  Research/Trade/Allocation target: $Symbol"

$runnerParams = @{
  Symbol = $Symbol
  EndDate = $EndDate
  AsOfTimestamp = $AsOfTimestamp
  TrainQuarters = $TrainQuarters
  OosQuarters = $OosQuarters
  FoldCount = $FoldCount
  GridN = $StateCount
  StateEngine = $stateEngine
  KmeansNstart = $KmeansNstart
  RegimeContextSymbols = $RegimeContextSymbols
  PcaPanelMode = $pcaPanelMode
  MinTrainStateRows = $MinTrainStateRows
  CandidateFamilies = $CandidateFamilies
  FastPeriods = $FastPeriods
  SlowPeriods = $SlowPeriods
  BbLookbackPeriods = $BbLookbackPeriods
  BbSdMultipliers = $BbSdMultipliers
  WarmupDays = $WarmupDays
  RscriptPath = $RscriptPath
}
if ($Refresh.IsPresent) {
  $runnerParams.Refresh = $true
}

& $runner @runnerParams
if ($LASTEXITCODE -ne 0) {
  throw "run_pca_wfa_router_poc.ps1 failed with exit code $LASTEXITCODE."
}
