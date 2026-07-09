param(
  [Parameter(Mandatory = $true)]
  [string]$Symbol,

  [string]$StartDate,

  [int]$LookbackDays = 1065,

  [Parameter(Mandatory = $true)]
  [string]$EndDate,

  [Parameter(Mandatory = $true)]
  [string]$AsOfTimestamp,

  [double]$TrainQuarters = 8,

  [double]$OosQuarters = 1,

  [string]$FastPeriods = "8,12,20",

  [string]$SlowPeriods = "30,50,80,120",

  [switch]$Refresh,

  [string]$RscriptPath = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($StartDate) -and $LookbackDays -le 0) {
  throw "Provide -StartDate or a positive -LookbackDays value."
}
if ($TrainQuarters -le 0) {
  throw "-TrainQuarters must be positive."
}
if ($OosQuarters -le 0) {
  throw "-OosQuarters must be positive."
}
if ([string]::IsNullOrWhiteSpace($FastPeriods)) {
  throw "-FastPeriods must be a comma-separated list of positive integers."
}
if ([string]::IsNullOrWhiteSpace($SlowPeriods)) {
  throw "-SlowPeriods must be a comma-separated list of positive integers."
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir "..\..")
$rScript = Join-Path $scriptDir "run_ema_cross_wfa_poc.R"

if (-not (Test-Path -LiteralPath $RscriptPath)) {
  $cmd = Get-Command Rscript -ErrorAction SilentlyContinue
  if ($null -eq $cmd) {
    throw "Rscript was not found at '$RscriptPath' and is not available on PATH."
  }
  $RscriptPath = $cmd.Source
}

$env:GEN5_WFA_SYMBOL = $Symbol
$env:GEN5_WFA_START_DATE = $StartDate
$env:GEN5_WFA_LOOKBACK_DAYS = [string]$LookbackDays
$env:GEN5_WFA_END_DATE = $EndDate
$env:GEN5_AS_OF_TIMESTAMP = $AsOfTimestamp
$env:GEN5_WFA_TRAIN_QUARTERS = [string]$TrainQuarters
$env:GEN5_WFA_OOS_QUARTERS = [string]$OosQuarters
$env:GEN5_WFA_FAST_PERIODS = $FastPeriods
$env:GEN5_WFA_SLOW_PERIODS = $SlowPeriods
$env:GEN5_WFA_REFRESH = if ($Refresh.IsPresent) { "true" } else { "false" }

Push-Location $repoRoot
try {
  & $RscriptPath $rScript
  if ($LASTEXITCODE -ne 0) {
    throw "run_ema_cross_wfa_poc.R failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
