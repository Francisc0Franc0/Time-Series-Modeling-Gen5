param(
  [string]$ComparisonId = "ctxfac_two_window_state_map_20260331_20260624",

  [string]$RscriptPath = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rScript = Join-Path $scriptDir "run_context_factorial_window_comparison.R"

if (-not (Test-Path -LiteralPath $rScript)) {
  throw "Expected comparison R script was not found: $rScript"
}
if (-not (Test-Path -LiteralPath $RscriptPath)) {
  $cmd = Get-Command Rscript -ErrorAction SilentlyContinue
  if ($null -eq $cmd) {
    throw "Rscript was not found at '$RscriptPath' and is not available on PATH."
  }
  $RscriptPath = $cmd.Source
}

$env:GEN5_CONTEXT_WINDOW_COMPARISON_ID = $ComparisonId

Write-Host "Gen5.1 Two-Window State-Map Comparison"
Write-Host "  Comparison id: $ComparisonId"
Write-Host "  Existing artifacts only; no WFA rerun."

& $RscriptPath $rScript
if ($LASTEXITCODE -ne 0) {
  throw "run_context_factorial_window_comparison.R failed with exit code $LASTEXITCODE."
}
