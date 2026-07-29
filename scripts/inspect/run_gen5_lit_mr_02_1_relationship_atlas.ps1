$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$rscript = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"

if (-not (Test-Path -LiteralPath $rscript)) {
  throw "Expected Rscript was not found at $rscript"
}

$env:GEN5_MR02_PANEL_ID = "RELATIONSHIP_ATLAS_01"
$env:GEN5_MR02_PANEL_RUN_ID = "lit_mr_02_1_relationship_atlas_01_20260729"
if (-not $env:GEN5_MR02_PANEL_REFRESH) {
  $env:GEN5_MR02_PANEL_REFRESH = "true"
}

Push-Location $repoRoot
try {
  & $rscript "scripts/inspect/run_gen5_lit_mr_02_1_pair_panel.R"
  if ($LASTEXITCODE -ne 0) {
    throw "Relationship-atlas runner failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
