param(
  [string]$AsOf = "2026-07-01 17:30:00",
  [string]$Quarter = "2026Q3",
  [string]$Feed = "",
  [string]$PreviousAuthorityDir = "",
  [int]$MinTrainStateRows = 20,
  [switch]$NoContinuity,
  [switch]$NoRefresh
)

$ErrorActionPreference = "Stop"
$rscript = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"
$refresh = -not $NoRefresh.IsPresent
$continuity = -not $NoContinuity.IsPresent
$args = @(
  (Join-Path $PSScriptRoot "run_dual_live_advice_bridge.R"),
  "--as-of=$AsOf",
  "--quarter=$Quarter",
  "--refresh=$refresh",
  "--continuity=$continuity",
  "--min-train-state-rows=$MinTrainStateRows"
)
if ($Feed) { $args += "--feed=$Feed" }
if ($PreviousAuthorityDir) { $args += "--previous-authority-dir=$PreviousAuthorityDir" }
& $rscript @args
