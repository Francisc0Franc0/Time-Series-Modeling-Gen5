param(
  [string]$RscriptPath = $env:GEN5_RSCRIPT
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")
Set-Location -LiteralPath $repoRoot

if ([string]::IsNullOrWhiteSpace($RscriptPath)) {
  $candidate = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"
  if (Test-Path -LiteralPath $candidate) {
    $RscriptPath = $candidate
  } else {
    $command = Get-Command Rscript -ErrorAction SilentlyContinue
    if ($null -ne $command) {
      $RscriptPath = $command.Source
    }
  }
}

if ([string]::IsNullOrWhiteSpace($RscriptPath) -or -not (Test-Path -LiteralPath $RscriptPath)) {
  throw "Rscript was not found. Set GEN5_RSCRIPT or pass -RscriptPath with the full path to Rscript.exe."
}

Write-Host "Using Rscript: $RscriptPath"
& $RscriptPath "scripts/test/run_tests.R"
exit $LASTEXITCODE
