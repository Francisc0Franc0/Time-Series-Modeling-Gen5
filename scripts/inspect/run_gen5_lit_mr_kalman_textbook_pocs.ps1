$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$rscript = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"

if (-not (Test-Path -LiteralPath $rscript)) {
  throw "Expected Rscript was not found at $rscript"
}

$env:GEN5_KALMAN_RUN_ID = "lit_mr_04_1_05_1_kalman_textbook_20260729"
if (-not $env:GEN5_KALMAN_REFRESH) {
  $env:GEN5_KALMAN_REFRESH = "false"
}

Push-Location $repoRoot
try {
  & $rscript "scripts/inspect/run_gen5_lit_mr_kalman_textbook_pocs.R"
  if ($LASTEXITCODE -ne 0) {
    throw "Kalman textbook runner failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
