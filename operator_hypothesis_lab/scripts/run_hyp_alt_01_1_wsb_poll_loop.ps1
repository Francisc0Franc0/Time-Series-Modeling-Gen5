param(
  [string]$RscriptPath = $env:GEN5_RSCRIPT,
  [int]$PollSeconds = 120,
  [int]$ReconcileEveryIterations = 30,
  [int]$MaxIterations = 0
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
    if ($null -ne $command) { $RscriptPath = $command.Source }
  }
}
if ([string]::IsNullOrWhiteSpace($RscriptPath) -or -not (Test-Path -LiteralPath $RscriptPath)) {
  throw "Rscript was not found. Set GEN5_RSCRIPT or pass -RscriptPath."
}
if ($PollSeconds -lt 60) { throw "PollSeconds must be at least 60." }
if ($ReconcileEveryIterations -lt 1) { throw "ReconcileEveryIterations must be at least 1." }
if ($MaxIterations -lt 0) { throw "MaxIterations cannot be negative." }

$iteration = 0
while ($MaxIterations -eq 0 -or $iteration -lt $MaxIterations) {
  $iteration += 1
  Write-Host "WSB collection iteration $iteration at $([DateTime]::UtcNow.ToString('o'))"
  & $RscriptPath "operator_hypothesis_lab/scripts/run_hyp_alt_01_1_wsb_collection.R"
  if ($LASTEXITCODE -ne 0) { throw "WSB collection failed with exit code $LASTEXITCODE." }

  if (($iteration % $ReconcileEveryIterations) -eq 0) {
    & $RscriptPath "operator_hypothesis_lab/scripts/run_hyp_alt_01_1_reddit_reconciliation.R"
    if ($LASTEXITCODE -ne 0) { throw "Reddit deletion reconciliation failed with exit code $LASTEXITCODE." }
  }

  if ($MaxIterations -eq 0 -or $iteration -lt $MaxIterations) {
    Start-Sleep -Seconds $PollSeconds
  }
}
