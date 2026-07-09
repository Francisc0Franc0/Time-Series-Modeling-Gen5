param(
  [string]$Symbol = "AMD",

  [Parameter(Mandatory = $true)]
  [string]$EndDate,

  [Parameter(Mandatory = $true)]
  [string]$AsOfTimestamp,

  [string]$RegimeContextSymbols = "AMD,NVDA,TSLA",

  [double]$TrainQuarters = 8,

  [double]$OosQuarters = 1,

  [int]$FoldCount = 5,

  [int]$QuantileStateCount = 3,

  [int]$KmeansStateCount = 9,

  [int]$KmeansNstart = 30,

  [int]$MinTrainStateRows = 20,

  [string]$CandidateFamilies = "ema_cross,ema_trend,bollinger_touch,bollinger_mid_reversion,rsi_mr,zret_mr,breakout,pullback_in_uptrend,vol_expansion_breakout,donchian_breakout_vol_expand,no_trade",

  [string]$FastPeriods = "8,12",

  [string]$SlowPeriods = "30,50",

  [string]$BbLookbackPeriods = "10,20",

  [string]$BbSdMultipliers = "1.5,2",

  [ValidateSet("standard", "modest_expanded", "gen4_daily_default")]
  [string]$StrategyGridPreset = "gen4_daily_default",

  [int]$WarmupDays = 340,

  [switch]$Refresh,

  [switch]$SkipChildRuns,

  [string]$RscriptPath = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"
)

$ErrorActionPreference = "Stop"

if ($TrainQuarters -le 0) {
  throw "-TrainQuarters must be positive."
}
if ($OosQuarters -le 0) {
  throw "-OosQuarters must be positive."
}
if ($FoldCount -lt 1) {
  throw "-FoldCount must be a positive integer."
}
if ($QuantileStateCount -lt 2 -or $QuantileStateCount -gt 5) {
  throw "-QuantileStateCount must be between 2 and 5."
}
if ($KmeansStateCount -lt 2 -or $KmeansStateCount -gt 25) {
  throw "-KmeansStateCount must be between 2 and 25."
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
$workbenchRunner = Join-Path $scriptDir "run_pca_router_workbench.ps1"
$summaryScript = Join-Path $scriptDir "run_pca_comparison_report.R"

if (-not (Test-Path -LiteralPath $workbenchRunner)) {
  throw "Expected PCA router workbench runner was not found: $workbenchRunner"
}
if (-not (Test-Path -LiteralPath $summaryScript)) {
  throw "Expected PCA comparison R script was not found: $summaryScript"
}
if (-not (Test-Path -LiteralPath $RscriptPath)) {
  $cmd = Get-Command Rscript -ErrorAction SilentlyContinue
  if ($null -eq $cmd) {
    throw "Rscript was not found at '$RscriptPath' and is not available on PATH."
  }
  $RscriptPath = $cmd.Source
}

$comparisons = @(
  @{ PanelMode = "contextual_snapshot"; StateMap = "quantile_grid"; StateCount = $QuantileStateCount },
  @{ PanelMode = "contextual_snapshot"; StateMap = "kmeans"; StateCount = $KmeansStateCount },
  @{ PanelMode = "behavioral_pool"; StateMap = "quantile_grid"; StateCount = $QuantileStateCount },
  @{ PanelMode = "behavioral_pool"; StateMap = "kmeans"; StateCount = $KmeansStateCount }
)

Write-Host "Gen5 PCA router comparison"
Write-Host "  Symbol: $Symbol"
Write-Host "  Regime Context Universe: $RegimeContextSymbols"
Write-Host "  Fold count: $FoldCount"
Write-Host "  Quantile grid: ${QuantileStateCount}x$QuantileStateCount"
Write-Host "  K-means clusters: $KmeansStateCount"
Write-Host "  End date: $EndDate"
Write-Host "  As of: $AsOfTimestamp"
Write-Host "  Strategy grid preset: $StrategyGridPreset"
Write-Host "  Refresh: $($Refresh.IsPresent)"
Write-Host "  Skip child runs: $($SkipChildRuns.IsPresent)"

if (-not $SkipChildRuns.IsPresent) {
  foreach ($comparison in $comparisons) {
    Write-Host ""
    Write-Host "Running $($comparison.PanelMode) / $($comparison.StateMap) ..."
    $runnerParams = @{
      Symbol = $Symbol
      EndDate = $EndDate
      AsOfTimestamp = $AsOfTimestamp
      RegimeContextSymbols = $RegimeContextSymbols
      PanelMode = $comparison.PanelMode
      StateMap = $comparison.StateMap
      TrainQuarters = $TrainQuarters
      OosQuarters = $OosQuarters
      FoldCount = $FoldCount
      StateCount = $comparison.StateCount
      KmeansNstart = $KmeansNstart
      MinTrainStateRows = $MinTrainStateRows
      CandidateFamilies = $CandidateFamilies
      FastPeriods = $FastPeriods
      SlowPeriods = $SlowPeriods
      BbLookbackPeriods = $BbLookbackPeriods
      BbSdMultipliers = $BbSdMultipliers
      StrategyGridPreset = $StrategyGridPreset
      WarmupDays = $WarmupDays
      RscriptPath = $RscriptPath
    }
    if ($Refresh.IsPresent) {
      $runnerParams.Refresh = $true
    }
    & $workbenchRunner @runnerParams
    if ($LASTEXITCODE -ne 0) {
      throw "run_pca_router_workbench.ps1 failed for $($comparison.PanelMode) / $($comparison.StateMap) with exit code $LASTEXITCODE."
    }
  }
}

$env:GEN5_PCA_COMPARISON_SYMBOL = $Symbol
$env:GEN5_PCA_COMPARISON_END_DATE = $EndDate
$env:GEN5_PCA_COMPARISON_AS_OF_TIMESTAMP = $AsOfTimestamp
$env:GEN5_PCA_COMPARISON_REGIME_CONTEXT_SYMBOLS = $RegimeContextSymbols
$env:GEN5_PCA_COMPARISON_TRAIN_QUARTERS = [string]$TrainQuarters
$env:GEN5_PCA_COMPARISON_OOS_QUARTERS = [string]$OosQuarters
$env:GEN5_PCA_COMPARISON_FOLD_COUNT = [string]$FoldCount
$env:GEN5_PCA_COMPARISON_QUANTILE_STATE_COUNT = [string]$QuantileStateCount
$env:GEN5_PCA_COMPARISON_KMEANS_STATE_COUNT = [string]$KmeansStateCount
$env:GEN5_PCA_COMPARISON_CANDIDATE_FAMILIES = $CandidateFamilies
$env:GEN5_PCA_COMPARISON_STRATEGY_GRID_PRESET = $StrategyGridPreset

Push-Location $repoRoot
try {
  & $RscriptPath $summaryScript
  if ($LASTEXITCODE -ne 0) {
    throw "run_pca_comparison_report.R failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
