param(
  [string]$AsOf = "2026-06-30 17:30:00",
  [string]$Quarter = "2026Q3",
  [string]$Symbols = "AMD,NVDA,PLTR,TSLA,SOFI",
  [string]$Feed = "",
  [switch]$Refresh
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$rscript = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"
$args = @((Join-Path $PSScriptRoot "build_live_advice_bridge_authority.R"), "--as-of=$AsOf", "--quarter=$Quarter", "--symbols=$Symbols", "--refresh=$($Refresh.IsPresent)")
if ($Feed) { $args += "--feed=$Feed" }
& $rscript @args
