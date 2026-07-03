param(
  [string]$Symbol = "AMD",

  [Parameter(Mandatory = $true)]
  [string]$EndDate,

  [Parameter(Mandatory = $true)]
  [string]$AsOfTimestamp,

  [string]$UniverseIds = "baseline_context,similar_high_beta_tech_semis,diverse_market_risk_context",

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

function Get-PcaContextUniverseSymbols {
  param([string]$UniverseId)

  switch ($UniverseId) {
    "baseline_context" { return "AMD,NVDA,TSLA" }
    "similar_high_beta_tech_semis" { return "AMD,NVDA,TSLA,SMH,AVGO,MU,INTC" }
    "diverse_market_risk_context" { return "AMD,NVDA,TSLA,SPY,QQQ,IWM,SMH,TLT,GLD,VXX" }
    default { throw "Unknown -UniverseIds value '$UniverseId'." }
  }
}

if ($Symbol -ne "AMD") {
  throw "This Gen5.1 context-universe panel is currently scoped to AMD-only research/trading/allocation."
}
if ($FoldCount -lt 1) {
  throw "-FoldCount must be a positive integer."
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir "..\..")
$comparisonRunner = Join-Path $scriptDir "run_pca_comparison_report.ps1"
$summaryScript = Join-Path $scriptDir "run_pca_context_universe_panels.R"

if (-not (Test-Path -LiteralPath $comparisonRunner)) {
  throw "Expected PCA comparison runner was not found: $comparisonRunner"
}
if (-not (Test-Path -LiteralPath $summaryScript)) {
  throw "Expected PCA context-universe summary script was not found: $summaryScript"
}
if (-not (Test-Path -LiteralPath $RscriptPath)) {
  $cmd = Get-Command Rscript -ErrorAction SilentlyContinue
  if ($null -eq $cmd) {
    throw "Rscript was not found at '$RscriptPath' and is not available on PATH."
  }
  $RscriptPath = $cmd.Source
}

$universeList = @($UniverseIds.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($universeList.Count -lt 1) {
  throw "-UniverseIds must contain at least one universe id."
}

Write-Host "Gen5 PCA context-universe panels"
Write-Host "  Symbol / Research Candidate Universe: $Symbol"
Write-Host "  Tradeable Universe: $Symbol"
Write-Host "  Active Allocation Set: $Symbol"
Write-Host "  Universe ids: $($universeList -join ', ')"
Write-Host "  Fold count: $FoldCount"
Write-Host "  End date: $EndDate"
Write-Host "  As of: $AsOfTimestamp"
Write-Host "  Strategy grid preset: $StrategyGridPreset"
Write-Host "  Refresh: $($Refresh.IsPresent)"
Write-Host "  Skip child runs: $($SkipChildRuns.IsPresent)"

if (-not $SkipChildRuns.IsPresent) {
  foreach ($universeId in $universeList) {
    $regimeContextSymbols = Get-PcaContextUniverseSymbols -UniverseId $universeId
    Write-Host ""
    Write-Host "Running context universe '$universeId': $regimeContextSymbols"
    $runnerParams = @{
      Symbol = $Symbol
      EndDate = $EndDate
      AsOfTimestamp = $AsOfTimestamp
      RegimeContextSymbols = $regimeContextSymbols
      TrainQuarters = $TrainQuarters
      OosQuarters = $OosQuarters
      FoldCount = $FoldCount
      QuantileStateCount = $QuantileStateCount
      KmeansStateCount = $KmeansStateCount
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
    & $comparisonRunner @runnerParams
    if ($LASTEXITCODE -ne 0) {
      throw "run_pca_comparison_report.ps1 failed for context universe '$universeId' with exit code $LASTEXITCODE."
    }
  }
}

$env:GEN5_PCA_UNIVERSE_COMPARISON_SYMBOL = $Symbol
$env:GEN5_PCA_UNIVERSE_COMPARISON_END_DATE = $EndDate
$env:GEN5_PCA_UNIVERSE_COMPARISON_AS_OF_TIMESTAMP = $AsOfTimestamp
$env:GEN5_PCA_UNIVERSE_COMPARISON_FOLD_COUNT = [string]$FoldCount
$env:GEN5_PCA_UNIVERSE_COMPARISON_UNIVERSE_IDS = ($universeList -join ",")
$env:GEN5_PCA_UNIVERSE_COMPARISON_STRATEGY_GRID_PRESET = $StrategyGridPreset

Push-Location $repoRoot
try {
  & $RscriptPath $summaryScript
  if ($LASTEXITCODE -ne 0) {
    throw "run_pca_context_universe_panels.R failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
