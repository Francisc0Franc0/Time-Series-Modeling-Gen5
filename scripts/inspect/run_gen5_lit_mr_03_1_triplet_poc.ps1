$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$rscript = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"

if (-not (Test-Path -LiteralPath $rscript)) {
  throw "Expected Rscript was not found at $rscript"
}

$env:GEN5_MR03_RUN_ID = "lit_mr_03_1_triplets_20260729"
if (-not $env:GEN5_MR03_REFRESH) {
  $env:GEN5_MR03_REFRESH = "true"
}

Push-Location $repoRoot
try {
  & $rscript "scripts/inspect/run_gen5_lit_mr_03_1_triplet_poc.R"
  if ($LASTEXITCODE -ne 0) {
    throw "Triplet runner failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
