$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$rscript = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"

if (-not (Test-Path -LiteralPath $rscript)) {
  throw "Expected Rscript was not found at $rscript."
}

Push-Location $repoRoot
try {
  $env:GEN5_MR03_SCOPE = "TRIPLET_ATLAS_01"
  $env:GEN5_MR03_RUN_ID = "lit_mr_03_1_triplet_atlas_01_20260729"
  $env:GEN5_MR03_REFRESH = "true"
  & $rscript "scripts/inspect/run_gen5_lit_mr_03_1_triplet_poc.R"
  if ($LASTEXITCODE -ne 0) {
    throw "Triplet-atlas runner failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
