param(
  [string]$AsOf = "2026-07-01 17:30:00",
  [string]$Quarter = "2026Q3",
  [string]$Feed = "",
  [string]$PreviousAuthorityDir = "",
  [switch]$NoContinuity,
  [switch]$NoRefresh
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$rscript = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"
$refresh = -not $NoRefresh.IsPresent
$continuity = -not $NoContinuity.IsPresent
$args = @((Join-Path $PSScriptRoot "run_live_advice_bridge.R"), "--as-of=$AsOf", "--quarter=$Quarter", "--refresh=$refresh", "--continuity=$continuity")
if ($Feed) { $args += "--feed=$Feed" }
if ($PreviousAuthorityDir) { $args += "--previous-authority-dir=$PreviousAuthorityDir" }
& $rscript @args
