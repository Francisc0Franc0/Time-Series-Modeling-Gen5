param(
  [ValidateSet("RETROSPECTIVE", "FRESH_ATLAS_01")]
  [string]$Lane = "RETROSPECTIVE",
  [switch]$Refresh,
  [switch]$DevelopmentRefresh
)

$ErrorActionPreference = "Stop"
$env:GEN5_MR032_LANE = $Lane
$env:GEN5_MR032_REFRESH = if ($Refresh) { "true" } else { "false" }
$env:GEN5_MR032_DEVELOPMENT_REFRESH = if ($DevelopmentRefresh) {
  "true"
} else {
  $env:GEN5_MR032_REFRESH
}
$env:GEN5_MR032_RUN_ID = "lit_mr_03_2_$($Lane.ToLower())_20260729"

& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" `
  "literature_studies\scripts\run_gen5_lit_mr_03_2_relaxed_triplet_research.R"
if ($LASTEXITCODE -ne 0) {
  throw "LIT-MR-03.2 $Lane runner failed with exit code $LASTEXITCODE."
}
