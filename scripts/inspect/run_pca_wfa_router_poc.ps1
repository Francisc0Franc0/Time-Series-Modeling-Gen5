param(
  [string]$Symbol = "AMD",

  [Parameter(Mandatory = $true)]
  [string]$EndDate,

  [Parameter(Mandatory = $true)]
  [string]$AsOfTimestamp,

  [double]$TrainQuarters = 8,

  [double]$OosQuarters = 1,

  [int]$FoldCount = 1,

  [int]$GridN = 3,

  [ValidateSet("quantile_grid", "pca_kmeans")]
  [string]$StateEngine = "quantile_grid",

  [int]$KmeansNstart = 30,

  [string]$RegimeContextSymbols = "",

  [ValidateSet("date_aligned_context", "pooled_asset_day")]
  [string]$PcaPanelMode = "date_aligned_context",

  [int]$MinTrainStateRows = 20,

  [string]$CandidateFamilies = "ema_cross,bollinger_touch,no_trade",

  [string]$FastPeriods = "8,12",

  [string]$SlowPeriods = "30,50",

  [string]$BbLookbackPeriods = "10,20",

  [string]$BbSdMultipliers = "1.5,2",

  [int]$WarmupDays = 340,

  [switch]$Refresh,

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
if ($StateEngine -eq "quantile_grid" -and ($GridN -lt 2 -or $GridN -gt 5)) {
  throw "-GridN must be between 2 and 5 for quantile grids, or use -ClusterCount semantics through -GridN for k-means."
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
$rScript = Join-Path $scriptDir "run_pca_wfa_router_poc.R"

if (-not (Test-Path -LiteralPath $RscriptPath)) {
  $cmd = Get-Command Rscript -ErrorAction SilentlyContinue
  if ($null -eq $cmd) {
    throw "Rscript was not found at '$RscriptPath' and is not available on PATH."
  }
  $RscriptPath = $cmd.Source
}

$env:GEN5_PCA_WFA_SYMBOL = $Symbol
$env:GEN5_PCA_WFA_END_DATE = $EndDate
$env:GEN5_PCA_WFA_AS_OF_TIMESTAMP = $AsOfTimestamp
$env:GEN5_PCA_WFA_TRAIN_QUARTERS = [string]$TrainQuarters
$env:GEN5_PCA_WFA_OOS_QUARTERS = [string]$OosQuarters
$env:GEN5_PCA_WFA_FOLD_COUNT = [string]$FoldCount
$env:GEN5_PCA_WFA_GRID_N = [string]$GridN
$env:GEN5_PCA_WFA_STATE_ENGINE = $StateEngine
$env:GEN5_PCA_WFA_KMEANS_NSTART = [string]$KmeansNstart
$env:GEN5_PCA_WFA_REGIME_CONTEXT_SYMBOLS = $RegimeContextSymbols
$env:GEN5_PCA_WFA_PANEL_MODE = $PcaPanelMode
$env:GEN5_PCA_WFA_MIN_TRAIN_STATE_ROWS = [string]$MinTrainStateRows
$env:GEN5_PCA_WFA_CANDIDATE_FAMILIES = $CandidateFamilies
$env:GEN5_PCA_WFA_FAST_PERIODS = $FastPeriods
$env:GEN5_PCA_WFA_SLOW_PERIODS = $SlowPeriods
$env:GEN5_PCA_WFA_BB_LOOKBACK_PERIODS = $BbLookbackPeriods
$env:GEN5_PCA_WFA_BB_SD_MULTIPLIERS = $BbSdMultipliers
$env:GEN5_PCA_WFA_WARMUP_DAYS = [string]$WarmupDays
$env:GEN5_PCA_WFA_REFRESH = if ($Refresh.IsPresent) { "true" } else { "false" }

Push-Location $repoRoot
try {
  & $RscriptPath $rScript
  if ($LASTEXITCODE -ne 0) {
    throw "run_pca_wfa_router_poc.R failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
