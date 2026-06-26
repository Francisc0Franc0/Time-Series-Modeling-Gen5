param(
  [string]$Symbols = "AMD,NVDA,TSLA,META,QQQ,SPY",

  [string]$StartDate,

  [int]$LookbackDays = 0,

  [Parameter(Mandatory = $true)]
  [string]$EndDate,

  [Parameter(Mandatory = $true)]
  [string]$AsOfTimestamp,

  [double]$TrainQuarters = 8,

  [double]$OosQuarters = 1,

  [int]$FoldCount = 3,

  [string]$FastPeriods = "8,12,20",

  [string]$SlowPeriods = "30,50,80,120",

  [string]$BbLookbackPeriods = "10,20,30",

  [string]$BbSdMultipliers = "1.5,2,2.5",

  [string]$CandidateFamilies = "ema_cross,bollinger_touch",

  [string]$MaxHoldSessions = "10,20,40",

  [string]$StopLossPcts = "0.10",

  [string]$TakeProfitPcts = "0.25",

  [switch]$Refresh,

  [string]$RscriptPath = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Symbols)) {
  throw "-Symbols must be a comma-separated list."
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
if ([string]::IsNullOrWhiteSpace($FastPeriods)) {
  throw "-FastPeriods must be a comma-separated list of positive integers."
}
if ([string]::IsNullOrWhiteSpace($SlowPeriods)) {
  throw "-SlowPeriods must be a comma-separated list of positive integers."
}
if ([string]::IsNullOrWhiteSpace($BbLookbackPeriods)) {
  throw "-BbLookbackPeriods must be a comma-separated list of positive integers."
}
if ([string]::IsNullOrWhiteSpace($BbSdMultipliers)) {
  throw "-BbSdMultipliers must be a comma-separated list of positive numbers."
}
if ([string]::IsNullOrWhiteSpace($CandidateFamilies)) {
  throw "-CandidateFamilies must be a comma-separated list."
}
if ([string]::IsNullOrWhiteSpace($MaxHoldSessions)) {
  throw "-MaxHoldSessions must be a comma-separated list of positive integers."
}
if ([string]::IsNullOrWhiteSpace($StopLossPcts)) {
  throw "-StopLossPcts must be a comma-separated list of positive decimal percentages, such as 0.10."
}
if ([string]::IsNullOrWhiteSpace($TakeProfitPcts)) {
  throw "-TakeProfitPcts must be a comma-separated list of positive decimal percentages, such as 0.25."
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir "..\..")
$rScript = Join-Path $scriptDir "run_multi_asset_wfa_batch.R"

if (-not (Test-Path -LiteralPath $RscriptPath)) {
  $cmd = Get-Command Rscript -ErrorAction SilentlyContinue
  if ($null -eq $cmd) {
    throw "Rscript was not found at '$RscriptPath' and is not available on PATH."
  }
  $RscriptPath = $cmd.Source
}

$env:GEN5_WFA_BATCH_SYMBOLS = $Symbols
$env:GEN5_WFA_BATCH_START_DATE = $StartDate
$env:GEN5_WFA_BATCH_LOOKBACK_DAYS = if ($LookbackDays -gt 0) { [string]$LookbackDays } else { "" }
$env:GEN5_WFA_BATCH_END_DATE = $EndDate
$env:GEN5_WFA_BATCH_AS_OF_TIMESTAMP = $AsOfTimestamp
$env:GEN5_WFA_BATCH_TRAIN_QUARTERS = [string]$TrainQuarters
$env:GEN5_WFA_BATCH_OOS_QUARTERS = [string]$OosQuarters
$env:GEN5_WFA_BATCH_FOLD_COUNT = [string]$FoldCount
$env:GEN5_WFA_BATCH_FAST_PERIODS = $FastPeriods
$env:GEN5_WFA_BATCH_SLOW_PERIODS = $SlowPeriods
$env:GEN5_WFA_BATCH_BB_LOOKBACK_PERIODS = $BbLookbackPeriods
$env:GEN5_WFA_BATCH_BB_SD_MULTIPLIERS = $BbSdMultipliers
$env:GEN5_WFA_BATCH_CANDIDATE_FAMILIES = $CandidateFamilies
$env:GEN5_WFA_BATCH_MAX_HOLD_SESSIONS = $MaxHoldSessions
$env:GEN5_WFA_BATCH_STOP_LOSS_PCTS = $StopLossPcts
$env:GEN5_WFA_BATCH_TAKE_PROFIT_PCTS = $TakeProfitPcts
$env:GEN5_WFA_BATCH_REFRESH = if ($Refresh.IsPresent) { "true" } else { "false" }

Push-Location $repoRoot
try {
  & $RscriptPath $rScript
  if ($LASTEXITCODE -ne 0) {
    throw "run_multi_asset_wfa_batch.R failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
