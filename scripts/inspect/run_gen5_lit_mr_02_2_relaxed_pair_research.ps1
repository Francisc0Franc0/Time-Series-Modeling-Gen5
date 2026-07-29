param(
  [ValidateSet("RETROSPECTIVE", "FRESH_ATLAS_01")]
  [string]$Lane = "RETROSPECTIVE",
  [switch]$Refresh,
  [switch]$DevelopmentRefresh
)

$ErrorActionPreference = "Stop"
$env:GEN5_MR022_LANE = $Lane
$env:GEN5_MR022_REFRESH = if ($Refresh) { "true" } else { "false" }
$env:GEN5_MR022_DEVELOPMENT_REFRESH = if ($DevelopmentRefresh) {
  "true"
} else {
  $env:GEN5_MR022_REFRESH
}
$env:GEN5_MR022_RUN_ID = "lit_mr_02_2_$($Lane.ToLower())_20260729"

& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" `
  "scripts\inspect\run_gen5_lit_mr_02_2_relaxed_pair_research.R"
if ($LASTEXITCODE -ne 0) {
  throw "LIT-MR-02.2 $Lane runner failed with exit code $LASTEXITCODE."
}
