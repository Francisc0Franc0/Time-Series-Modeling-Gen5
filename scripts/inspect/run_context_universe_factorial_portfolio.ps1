param(
  [string]$ActiveSymbols = "AMD,NVDA,TSLA,COIN,MSTR",

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

  [ValidateSet("quantile_grid")]
  [string]$StateEngine = "quantile_grid",

  [ValidateSet("pooled_asset_day")]
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

function Get-ContextUniverseSymbols {
  param([string]$UniverseId)

  switch ($UniverseId) {
    "active_self_context" { return "AMD,NVDA,TSLA,COIN,MSTR" }
    "active_plus_risk_context" { return "AMD,NVDA,TSLA,COIN,MSTR,SPY,QQQ,IWM,SMH,TLT,GLD,VXX" }
    "ex_active_market_risk_context" { return "SPY,QQQ,IWM,SMH,TLT,GLD,VXX" }
    default { throw "Unknown context universe id '$UniverseId'." }
  }
}

if ($FoldCount -lt 1) {
  throw "-FoldCount must be a positive integer."
}
if ($GridN -ne 3) {
  throw "This smallest useful factorial wrapper is scoped to quantile_grid 3x3."
}
if ($SlotCount -lt 1) {
  throw "-SlotCount must be positive."
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir "..\..")
$portfolioRunner = Join-Path $scriptDir "run_portfolio_strategy_poc.ps1"
$summaryScript = Join-Path $scriptDir "run_context_universe_factorial_portfolio.R"

if (-not (Test-Path -LiteralPath $portfolioRunner)) {
  throw "Expected portfolio POC runner was not found: $portfolioRunner"
}
if (-not (Test-Path -LiteralPath $summaryScript)) {
  throw "Expected context-universe factorial summary script was not found: $summaryScript"
}
if (-not (Test-Path -LiteralPath $RscriptPath)) {
  $cmd = Get-Command Rscript -ErrorAction SilentlyContinue
  if ($null -eq $cmd) {
    throw "Rscript was not found at '$RscriptPath' and is not available on PATH."
  }
  $RscriptPath = $cmd.Source
}

$universeList = @("active_self_context", "active_plus_risk_context", "ex_active_market_risk_context")

Write-Host "Gen5.1 Context-Universe Factorial Portfolio Inspection"
Write-Host "  Purpose: compare active-self, active-plus-risk, and external-risk context for the same active set."
Write-Host "  Active Allocation Set: $ActiveSymbols"
Write-Host "  PCA surface: $PcaPanelMode + $StateEngine ${GridN}x${GridN}"
Write-Host "  Universe ids: $($universeList -join ', ')"
Write-Host "  Fold count: $FoldCount"
Write-Host "  End date: $EndDate"
Write-Host "  As of: $AsOfTimestamp"
Write-Host "  Refresh: $($Refresh.IsPresent)"
Write-Host "  Skip child runs: $($SkipChildRuns.IsPresent)"

foreach ($universeId in $universeList) {
  $regimeContextSymbols = Get-ContextUniverseSymbols -UniverseId $universeId
  Write-Host ""
  Write-Host "Running portfolio packet for '$universeId': $regimeContextSymbols"
  $runnerParams = @{
    ActiveSymbols = $ActiveSymbols
    RegimeContextSymbols = $regimeContextSymbols
    BaselineSymbol = "SPY"
    EndDate = $EndDate
    AsOfTimestamp = $AsOfTimestamp
    InitialCapital = $InitialCapital
    SlotCount = $SlotCount
    TrainQuarters = $TrainQuarters
    OosQuarters = $OosQuarters
    FoldCount = $FoldCount
    GridN = $GridN
    StateEngine = $StateEngine
    PcaPanelMode = $PcaPanelMode
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
  if ($SkipChildRuns.IsPresent) {
    $runnerParams.SkipChildRuns = $true
  }
  & $portfolioRunner @runnerParams
  if ($LASTEXITCODE -ne 0) {
    throw "run_portfolio_strategy_poc.ps1 failed for context universe '$universeId' with exit code $LASTEXITCODE."
  }
}

$env:GEN5_CONTEXT_FACTORIAL_ACTIVE_SYMBOLS = $ActiveSymbols
$env:GEN5_CONTEXT_FACTORIAL_END_DATE = $EndDate
$env:GEN5_CONTEXT_FACTORIAL_AS_OF_TIMESTAMP = $AsOfTimestamp
$env:GEN5_CONTEXT_FACTORIAL_FOLD_COUNT = [string]$FoldCount
$env:GEN5_CONTEXT_FACTORIAL_GRID_N = [string]$GridN
$env:GEN5_CONTEXT_FACTORIAL_STATE_ENGINE = $StateEngine
$env:GEN5_CONTEXT_FACTORIAL_PANEL_MODE = $PcaPanelMode
$env:GEN5_CONTEXT_FACTORIAL_STRATEGY_GRID_PRESET = $StrategyGridPreset
$env:GEN5_CONTEXT_FACTORIAL_REFRESH = if ($Refresh.IsPresent) { "true" } else { "false" }
$env:GEN5_CONTEXT_FACTORIAL_SKIP_CHILD_RUNS = if ($SkipChildRuns.IsPresent) { "true" } else { "false" }

Push-Location $repoRoot
try {
  & $RscriptPath $summaryScript
  if ($LASTEXITCODE -ne 0) {
    throw "run_context_universe_factorial_portfolio.R failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
