param(
  [Parameter(Mandatory = $true)]
  [string]$Symbol,

  [string]$StartDate,

  [int]$TradingWindowDays = 730,

  [Parameter(Mandatory = $true)]
  [string]$EndDate,

  [Parameter(Mandatory = $true)]
  [string]$AsOfTimestamp,

  [string]$FastPeriods = "8,12,20",

  [string]$SlowPeriods = "30,50,80,120",

  [double]$Leverage = 1.0,

  [switch]$Refresh,

  [string]$RscriptPath = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($StartDate) -and $TradingWindowDays -le 0) {
  throw "Provide -StartDate or a positive -TradingWindowDays value."
}
if ($Leverage -le 0) {
  throw "-Leverage must be a positive number."
}
if ([string]::IsNullOrWhiteSpace($FastPeriods)) {
  throw "-FastPeriods must be a comma-separated list of positive integers."
}
if ([string]::IsNullOrWhiteSpace($SlowPeriods)) {
  throw "-SlowPeriods must be a comma-separated list of positive integers."
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir "..\..")
$rScript = Join-Path $scriptDir "run_ema_cross_backtest.R"

if (-not (Test-Path -LiteralPath $RscriptPath)) {
  $cmd = Get-Command Rscript -ErrorAction SilentlyContinue
  if ($null -eq $cmd) {
    throw "Rscript was not found at '$RscriptPath' and is not available on PATH."
  }
  $RscriptPath = $cmd.Source
}

$env:GEN5_EMA_CROSS_SYMBOL = $Symbol
$env:GEN5_EMA_CROSS_START_DATE = $StartDate
$env:GEN5_EMA_CROSS_TRADING_WINDOW_DAYS = [string]$TradingWindowDays
$env:GEN5_EMA_CROSS_END_DATE = $EndDate
$env:GEN5_AS_OF_TIMESTAMP = $AsOfTimestamp
$env:GEN5_EMA_CROSS_FAST_PERIODS = $FastPeriods
$env:GEN5_EMA_CROSS_SLOW_PERIODS = $SlowPeriods
$env:GEN5_EMA_CROSS_LEVERAGE = [string]$Leverage
$env:GEN5_EMA_CROSS_REFRESH = if ($Refresh.IsPresent) { "true" } else { "false" }

Push-Location $repoRoot
try {
  & $RscriptPath $rScript
  if ($LASTEXITCODE -ne 0) {
    throw "run_ema_cross_backtest.R failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
