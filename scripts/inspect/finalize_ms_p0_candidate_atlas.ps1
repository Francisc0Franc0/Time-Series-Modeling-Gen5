$ErrorActionPreference = "Continue"
$repo = "C:\Users\Franc\OneDrive\Documents\Francis\Peltata Project\Time-Series-Modeling-Gen5"
$runRoot = Join-Path $repo "runs\research_workbench"
$done = Join-Path $runRoot "ms_p0_candidate_atlas.completed.txt"
$log = Join-Path $runRoot "ms_p0_candidate_atlas_finalize.log"
$marker = Join-Path $runRoot "ms_p0_candidate_atlas_finalize.completed.txt"
$rscript = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"
$node = "C:\Users\Franc\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"

Set-Content -LiteralPath $marker -Value "WAITING_FOR_ATLAS" -Encoding ASCII
for ($i = 0; $i -lt 420; $i += 1) {
  $state = if (Test-Path $done) { Get-Content -LiteralPath $done -Raw } else { "" }
  if ($state -like "Completed*") { break }
  Start-Sleep -Seconds 120
}

$state = if (Test-Path $done) { Get-Content -LiteralPath $done -Raw } else { "" }
if ($state -notlike "Completed*") {
  Set-Content -LiteralPath $marker -Value "ATLAS_DID_NOT_COMPLETE" -Encoding ASCII
  exit 1
}

try {
  Set-Location -LiteralPath $repo
  & $rscript (Join-Path $repo "scripts\inspect\assemble_ms_p0_candidate_atlas.R") *>> $log
  if ($LASTEXITCODE -ne 0) { throw "Atlas assembly failed with exit code $LASTEXITCODE" }
  & $node (Join-Path $repo "scripts\inspect\build_gen54_strategy_meta_label_candidate_atlas_presentation.mjs") *>> $log
  if ($LASTEXITCODE -ne 0) { throw "Atlas presentation export failed with exit code $LASTEXITCODE" }
  Set-Content -LiteralPath $marker -Value ("Completed " + (Get-Date -Format o)) -Encoding ASCII
} catch {
  $_ | Out-File -LiteralPath $log -Append -Encoding ASCII
  Set-Content -LiteralPath $marker -Value "FAILED" -Encoding ASCII
  exit 1
}
