param(
  [Parameter(Mandatory = $true)]
  [string]$Symbol,

  [Parameter(Mandatory = $true)]
  [string]$StartDate,

  [Parameter(Mandatory = $true)]
  [string]$EndDate,

  [Parameter(Mandatory = $true)]
  [string]$AsOfTimestamp,

  [switch]$Refresh,

  [string]$RscriptPath = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir "..\..")
$rScript = Join-Path $scriptDir "render_symbol_data_proof.R"

if (-not (Test-Path -LiteralPath $RscriptPath)) {
  $cmd = Get-Command Rscript -ErrorAction SilentlyContinue
  if ($null -eq $cmd) {
    throw "Rscript was not found at '$RscriptPath' and is not available on PATH."
  }
  $RscriptPath = $cmd.Source
}

$env:GEN5_DATA_PROOF_SYMBOL = $Symbol
$env:GEN5_DATA_PROOF_START_DATE = $StartDate
$env:GEN5_DATA_PROOF_END_DATE = $EndDate
$env:GEN5_AS_OF_TIMESTAMP = $AsOfTimestamp
$env:GEN5_DATA_PROOF_REFRESH = if ($Refresh.IsPresent) { "true" } else { "false" }

Push-Location $repoRoot
try {
  & $RscriptPath $rScript
  if ($LASTEXITCODE -ne 0) {
    throw "render_symbol_data_proof.R failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
