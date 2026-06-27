param(
  [Parameter(Mandatory = $true)]
  [string]$Symbol,

  [Parameter(Mandatory = $true)]
  [string]$EndDate,

  [Parameter(Mandatory = $true)]
  [string]$AsOfTimestamp,

  [double]$TrainQuarters = 8,

  [double]$OosQuarters = 1,

  [int]$ClusterCount = 9,

  [int]$KmeansNstart = 30,

  [int]$WarmupDays = 320,

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
if ($ClusterCount -lt 2 -or $ClusterCount -gt 25) {
  throw "-ClusterCount must be between 2 and 25."
}
if ($KmeansNstart -lt 1) {
  throw "-KmeansNstart must be positive."
}
if ($WarmupDays -lt 220) {
  throw "-WarmupDays should be at least 220 so the 200-day anchor can initialize."
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir "..\..")
$rScript = Join-Path $scriptDir "run_pca_kmeans_regime_poc.R"

if (-not (Test-Path -LiteralPath $RscriptPath)) {
  $cmd = Get-Command Rscript -ErrorAction SilentlyContinue
  if ($null -eq $cmd) {
    throw "Rscript was not found at '$RscriptPath' and is not available on PATH."
  }
  $RscriptPath = $cmd.Source
}

$env:GEN5_PCA_KMEANS_SYMBOL = $Symbol
$env:GEN5_PCA_KMEANS_END_DATE = $EndDate
$env:GEN5_PCA_KMEANS_AS_OF_TIMESTAMP = $AsOfTimestamp
$env:GEN5_PCA_KMEANS_TRAIN_QUARTERS = [string]$TrainQuarters
$env:GEN5_PCA_KMEANS_OOS_QUARTERS = [string]$OosQuarters
$env:GEN5_PCA_KMEANS_CLUSTER_COUNT = [string]$ClusterCount
$env:GEN5_PCA_KMEANS_NSTART = [string]$KmeansNstart
$env:GEN5_PCA_KMEANS_WARMUP_DAYS = [string]$WarmupDays
$env:GEN5_PCA_KMEANS_REFRESH = if ($Refresh.IsPresent) { "true" } else { "false" }

Push-Location $repoRoot
try {
  & $RscriptPath $rScript
  if ($LASTEXITCODE -ne 0) {
    throw "run_pca_kmeans_regime_poc.R failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
