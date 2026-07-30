param(
  [string]$RunId = "lit_mr_06_1_buy_on_gap_20260730_v2",
  [switch]$RefreshDaily,
  [switch]$RefreshEntries
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$env:GEN5_LIT_MR_06_1_RUN_ID = $RunId
$env:GEN5_LIT_MR_06_1_REFRESH_DAILY = if ($RefreshDaily) { "true" } else { "false" }
$env:GEN5_LIT_MR_06_1_REFRESH_ENTRIES = if ($RefreshEntries) { "true" } else { "false" }

Push-Location $repoRoot
try {
  & "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" `
    "literature_studies\scripts\run_gen5_lit_mr_06_1_buy_on_gap_poc.R"
  if ($LASTEXITCODE -ne 0) {
    throw "LIT-MR-06.1 runner failed with exit code $LASTEXITCODE."
  }
}
finally {
  Pop-Location
}
