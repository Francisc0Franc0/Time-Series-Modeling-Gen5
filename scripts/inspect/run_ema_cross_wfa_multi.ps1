$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = Join-Path $scriptDir "run_multi_signal_wfa_poc.ps1"

& $target @args
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
