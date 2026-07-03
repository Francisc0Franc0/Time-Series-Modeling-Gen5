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

  [ValidateSet("quantile_grid", "pca_kmeans", "pca_kmeans_auto")]
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

  [ValidateSet("standard", "modest_expanded", "gen4_daily_default")]
  [string]$StrategyGridPreset = "gen4_daily_default",

  [int]$WarmupDays = 340,

  [switch]$Refresh,

  [switch]$SkipChildRuns,

  [switch]$MediumGrid,

  [switch]$ActivePlusRiskStateMapTriage,

  [switch]$ActivePlusRiskAutoMax15Triage,

  [switch]$TemporalContextReplication,

  [string]$RscriptPath = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"
)

$ErrorActionPreference = "Stop"

function Get-ContextUniverseSymbols {
  param(
    [string]$UniverseId,
    [string]$ActiveSymbols
  )

  $active = $ActiveSymbols.Split(",") | ForEach-Object { $_.Trim().ToUpperInvariant() } | Where-Object { $_.Length -gt 0 } | Select-Object -Unique
  if ($active.Count -lt 1) {
    throw "-ActiveSymbols must contain at least one symbol."
  }
  $risk = @("SPY", "QQQ", "IWM", "SMH", "TLT", "GLD", "VXX")

  switch ($UniverseId) {
    "active_self_context" { return ($active -join ",") }
    "active_plus_risk_context" { return (($active + $risk | Select-Object -Unique) -join ",") }
    "ex_active_market_risk_context" { return ($risk -join ",") }
    default { throw "Unknown context universe id '$UniverseId'." }
  }
}

if ($FoldCount -lt 1) {
  throw "-FoldCount must be a positive integer."
}
if ($SlotCount -lt 1) {
  throw "-SlotCount must be positive."
}
if ($ActivePlusRiskStateMapTriage.IsPresent -and $ActivePlusRiskAutoMax15Triage.IsPresent) {
  throw "Choose either -ActivePlusRiskStateMapTriage or -ActivePlusRiskAutoMax15Triage, not both."
}
$presetCount = @($MediumGrid.IsPresent, $ActivePlusRiskStateMapTriage.IsPresent, $ActivePlusRiskAutoMax15Triage.IsPresent, $TemporalContextReplication.IsPresent) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
if ($presetCount -gt 1) {
  throw "Choose only one multi-surface preset: -MediumGrid, -ActivePlusRiskStateMapTriage, -ActivePlusRiskAutoMax15Triage, or -TemporalContextReplication."
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

if ($ActivePlusRiskStateMapTriage.IsPresent -or $ActivePlusRiskAutoMax15Triage.IsPresent) {
  $universeList = @("active_plus_risk_context")
} else {
  $universeList = @("active_self_context", "active_plus_risk_context", "ex_active_market_risk_context")
}
if ($ActivePlusRiskStateMapTriage.IsPresent) {
  $surfaceList = @(
    @{ SurfaceId = "behavioral_pool_quantile_grid_3x3"; PcaPanelMode = "pooled_asset_day"; StateEngine = "quantile_grid"; GridN = 3 },
    @{ SurfaceId = "behavioral_pool_kmeans_k9"; PcaPanelMode = "pooled_asset_day"; StateEngine = "pca_kmeans"; GridN = 9 },
    @{ SurfaceId = "behavioral_pool_kmeans_auto_max9"; PcaPanelMode = "pooled_asset_day"; StateEngine = "pca_kmeans_auto"; GridN = 9 }
  )
} elseif ($ActivePlusRiskAutoMax15Triage.IsPresent) {
  $surfaceList = @(
    @{ SurfaceId = "behavioral_pool_quantile_grid_3x3"; PcaPanelMode = "pooled_asset_day"; StateEngine = "quantile_grid"; GridN = 3 },
    @{ SurfaceId = "behavioral_pool_kmeans_k9"; PcaPanelMode = "pooled_asset_day"; StateEngine = "pca_kmeans"; GridN = 9 },
    @{ SurfaceId = "behavioral_pool_kmeans_auto_max15"; PcaPanelMode = "pooled_asset_day"; StateEngine = "pca_kmeans_auto"; GridN = 15 }
  )
} elseif ($TemporalContextReplication.IsPresent) {
  $surfaceList = @(
    @{ SurfaceId = "behavioral_pool_quantile_grid_3x3"; PcaPanelMode = "pooled_asset_day"; StateEngine = "quantile_grid"; GridN = 3 },
    @{ SurfaceId = "behavioral_pool_kmeans_k9"; PcaPanelMode = "pooled_asset_day"; StateEngine = "pca_kmeans"; GridN = 9 }
  )
} elseif ($MediumGrid.IsPresent) {
  $surfaceList = @(
    @{ SurfaceId = "contextual_snapshot_quantile_grid"; PcaPanelMode = "date_aligned_context"; StateEngine = "quantile_grid"; GridN = 3 },
    @{ SurfaceId = "contextual_snapshot_kmeans"; PcaPanelMode = "date_aligned_context"; StateEngine = "pca_kmeans"; GridN = 9 },
    @{ SurfaceId = "behavioral_pool_quantile_grid"; PcaPanelMode = "pooled_asset_day"; StateEngine = "quantile_grid"; GridN = 3 },
    @{ SurfaceId = "behavioral_pool_kmeans"; PcaPanelMode = "pooled_asset_day"; StateEngine = "pca_kmeans"; GridN = 9 }
  )
} else {
  $surfaceList = @(
    @{ SurfaceId = "single_surface"; PcaPanelMode = $PcaPanelMode; StateEngine = $StateEngine; GridN = $GridN }
  )
}

Write-Host "Gen5.1 Context-Universe Factorial Portfolio Inspection"
if ($ActivePlusRiskStateMapTriage.IsPresent) {
  Write-Host "  Purpose: compare active-plus-risk behavioral-pool 3x3, fixed k9, and auto k-means max9 state maps."
} elseif ($ActivePlusRiskAutoMax15Triage.IsPresent) {
  Write-Host "  Purpose: compare active-plus-risk behavioral-pool 3x3, fixed k9, and auto k-means max15 state maps."
} elseif ($TemporalContextReplication.IsPresent) {
  Write-Host "  Purpose: temporal replication of active-self, active-plus-risk, and external-risk context using behavioral-pool 3x3 and fixed k9."
} else {
  Write-Host "  Purpose: compare active-self, active-plus-risk, and external-risk context for the same active set."
}
Write-Host "  Active Allocation Set: $ActiveSymbols"
Write-Host "  Medium grid: $($MediumGrid.IsPresent)"
Write-Host "  Active-plus-risk state-map triage: $($ActivePlusRiskStateMapTriage.IsPresent)"
Write-Host "  Active-plus-risk auto-k max15 triage: $($ActivePlusRiskAutoMax15Triage.IsPresent)"
Write-Host "  Temporal context replication: $($TemporalContextReplication.IsPresent)"
Write-Host "  PCA surfaces: $($surfaceList.Count)"
Write-Host "  Universe ids: $($universeList -join ', ')"
Write-Host "  Fold count: $FoldCount"
Write-Host "  End date: $EndDate"
Write-Host "  As of: $AsOfTimestamp"
Write-Host "  Refresh: $($Refresh.IsPresent)"
Write-Host "  Skip child runs: $($SkipChildRuns.IsPresent)"

foreach ($surface in $surfaceList) {
  foreach ($universeId in $universeList) {
    $regimeContextSymbols = Get-ContextUniverseSymbols -UniverseId $universeId -ActiveSymbols $ActiveSymbols
    Write-Host ""
    Write-Host "Running portfolio packet for '$universeId' / '$($surface.SurfaceId)': $regimeContextSymbols"
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
      GridN = $surface.GridN
      StateEngine = $surface.StateEngine
      PcaPanelMode = $surface.PcaPanelMode
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
      throw "run_portfolio_strategy_poc.ps1 failed for context universe '$universeId' / surface '$($surface.SurfaceId)' with exit code $LASTEXITCODE."
    }
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
$env:GEN5_CONTEXT_FACTORIAL_MEDIUM_GRID = if ($MediumGrid.IsPresent) { "true" } else { "false" }
$env:GEN5_CONTEXT_FACTORIAL_STATE_MAP_TRIAGE = if ($ActivePlusRiskStateMapTriage.IsPresent) { "true" } else { "false" }
$env:GEN5_CONTEXT_FACTORIAL_AUTO_MAX15_TRIAGE = if ($ActivePlusRiskAutoMax15Triage.IsPresent) { "true" } else { "false" }
$env:GEN5_CONTEXT_FACTORIAL_TEMPORAL_CONTEXT_REPLICATION = if ($TemporalContextReplication.IsPresent) { "true" } else { "false" }
$env:GEN5_CONTEXT_FACTORIAL_UNIVERSE_IDS = if ($ActivePlusRiskStateMapTriage.IsPresent -or $ActivePlusRiskAutoMax15Triage.IsPresent) { "active_plus_risk_context" } else { "" }

Push-Location $repoRoot
try {
  & $RscriptPath $summaryScript
  if ($LASTEXITCODE -ne 0) {
    throw "run_context_universe_factorial_portfolio.R failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
