param(
  [string]$SummaryId = "ctxfac_temporal_context_replication_20241231_20260623"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")
$rScript = Join-Path $scriptDir "run_context_temporal_replication_summary.R"

$rscriptExe = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"
if (-not (Test-Path $rscriptExe)) {
  $cmd = Get-Command Rscript -ErrorAction SilentlyContinue
  if ($null -eq $cmd) {
    throw "Cannot find Rscript. Expected $rscriptExe or Rscript on PATH."
  }
  $rscriptExe = $cmd.Source
}

Push-Location $repoRoot
try {
  $env:GEN5_CONTEXT_TEMPORAL_SUMMARY_ID = $SummaryId
  & $rscriptExe $rScript
  if ($LASTEXITCODE -ne 0) {
    throw "run_context_temporal_replication_summary.R failed with exit code $LASTEXITCODE."
  }
} finally {
  Remove-Item Env:\GEN5_CONTEXT_TEMPORAL_SUMMARY_ID -ErrorAction SilentlyContinue
  Pop-Location
}
