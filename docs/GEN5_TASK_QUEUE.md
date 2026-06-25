# Gen5.1 Task Queue

## Current Posture

This queue supersedes the old post-data-layer task queue on the `codex/Gen5.1-vertical-slice-reset` branch.

The completed base is the Gen5 v0/v0.1 market-data and research-workbench layer:

- Alpaca adjusted daily OHLCV only.
- Explicit `as_of_timestamp` handling.
- Deterministic local cache behavior.
- Data audit and severity-labeled health outputs.
- Source-controlled universe registry scaffolding.
- Research query and static chart inspection scripts.
- Non-network validation through `scripts/test/run_tests.ps1`.

The old rigid progression after the data layer is no longer the active task queue. WFA, universe creation, PCA/state modeling, strategy research, exits, allocation, leverage reports, dashboards, decision packs, and live advice remain desired capability areas, but their execution order is operator-directed and organic.

## Queue Rules

Codex may work autonomously inside an explicitly opened Gen5.1 slice, following `AGENTS.md` and `docs/GEN5_1_VERTICAL_SLICE_PLAN.md`.

For each task, Codex should:

- keep the change scoped to the opened slice;
- preserve the data-layer invariants;
- produce a tangible operator-facing output whenever practical;
- avoid stale roadmap pressure from older branches;
- run focused checks while iterating;
- run `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` when code, validation behavior, operator commands, or meaningful operator docs change;
- review `git status` before staging so generated artifacts, caches, credentials, local config, and heavyweight outputs stay out of git;
- commit validated slices with clear messages;
- push completed Codex task branches to `origin` when validation passes and the worktree is clean.

Codex must stop and ask before:

- adding package dependencies;
- changing provider scope beyond Alpaca adjusted daily OHLCV;
- making destructive file operations;
- moving cache roots, credentials, generated run outputs, or heavyweight artifacts;
- opening WFA methodology, strategy families, baseline families, state/regime models, exit models, allocation, leverage, dashboards, live advice, execution, or production behavior not explicitly authorized by the operator;
- computing or interpreting returns, Sharpe, drawdown, trade PnL, allocation, leverage value-add, fold/global summaries, or performance claims without explicit authorization for the exact calculation surface;
- resolving ambiguous product, research, risk, or methodology decisions by assumption.

## Status Legend

- `done`: completed, validated when warranted, and committed.
- `pending`: ready to be picked up.
- `blocked`: requires operator input or an external condition.
- `deferred`: intentionally later than the current slice.

## Completed Foundation

### 1. Gen5 v0/v0.1 data layer and workbench

Status: done

Branch base: `codex/gen5-v0-1-workbench-closeout`

Base commit for Gen5.1 reset: `a15f5e9`

Validation on Gen5.1 branch:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1
```

Result: passed.

Notes:

- The branch can load/read Alpaca adjusted daily data through the existing provider/cache/workbench modules.
- The branch can render a basic static chart from canonical bars.
- The large later WFA/AMD EMA scaffold stack is not present on this branch.

## Active Gen5.1 Reset

### 2. Restore autonomy and supersede the old queue

Status: done

Goal: Restore the stronger Codex autonomy policy, add the Gen5.1 visible-output working rhythm, and replace the old rigid post-data-layer queue with this flexible vertical-slice queue.

Branch: `codex/Gen5.1-vertical-slice-reset`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Restored the broader delegated Codex autonomy policy.
- Added Gen5.1 collaboration guidance for conversational, partner-like planning without broad tangent menus.
- Added the visible-output-per-slice rule.
- Superseded the old post-data-layer queue with an organic vertical-slice queue.
- Converted the system design build order into a flexible capability map.

Likely files:

- `AGENTS.md`
- `docs/GEN5_1_VERTICAL_SLICE_PLAN.md`
- `docs/GEN5_TASK_QUEUE.md`
- possibly `docs/GEN5_SYSTEM_DESIGN.md`

Validation:

- Run the local test wrapper because operator docs and working instructions changed.

Stop conditions:

- Any attempt to reintroduce a rigid implementation sequence beyond the completed data foundation.
- Any attempt to authorize WFA, strategy, allocation, leverage, live advice, dashboard, or execution logic inside this planning-only task.

### 3. Audit data-layer complexity posture

Status: done

Branch: `codex/Gen5.1-candidate-bc-inspection-reports`

Goal: Decide whether the completed v0/v0.1 data layer needs broad refactoring because it was built under the older Codex workflow.

Recommendation:

- Keep the data layer as the active foundation.
- Do not perform a broad refactor now.
- Continue making targeted ergonomic improvements when real operator workflows expose friction.

Notes:

- The data layer remains focused on Alpaca adjusted daily OHLCV, explicit `as_of_timestamp`, cache/audit behavior, and inspection artifacts.
- No WFA, strategy, PCA, allocation, dashboard, live advice, execution, or performance logic was found in the active `R/` modules.
- `R/data_audit.R` is the largest data-layer file, but its size is mostly audit/health surface consolidation rather than downstream research creep.
- Candidate B/C add operator ergonomics and inspection reports without changing provider scope or research methodology.

## Candidate Next Slices

These are suggestions, not a required order.

### A. AMD data proof report

Status: done

Goal: Load/read AMD adjusted daily bars through the workbench, render a chart, and write a compact data-health table under ignored `runs/`.

Branch: `codex/Gen5.1-candidate-a-data-proof`

Validation:

- `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.
- Operator launcher smoke passed with cached `NVDA` data because `AMD` was not present in the local ignored cache during implementation.

Notes:

- Added `scripts/inspect/render_symbol_data_proof.ps1` as the PowerShell-first operator launcher.
- Added `scripts/inspect/render_symbol_data_proof.R` and `R/workbench_data_proof.R` for the reusable implementation.
- Data proof packets write under ignored `runs/research_workbench/data_proofs/`.
- Each packet includes bars, manifest, audit, symbol coverage, refresh plan, health, candlestick PNG, and summary CSV/Markdown outputs.
- The workflow remains data-inspection only: no indicators, returns, strategy signals, WFA folds, allocation, execution, live advice, or performance claims.

Visible output:

- PNG chart.
- Small CSV or Markdown health summary.
- Console summary of requested range, observed range, row count, and warning status.

### B. Reusable one-symbol inspection command

Status: done

Goal: Make repeated one-symbol inspection easier for the operator without adding strategy logic.

Branch: `codex/Gen5.1-candidate-bc-inspection-reports`

Validation:

- Focused chart/data-proof tests passed.
- `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.
- Operator smoke passed with cached `NVDA` data using `-LookbackDays`.

Notes:

- `scripts/inspect/render_symbol_data_proof.ps1` now accepts either `-StartDate` or `-LookbackDays`.
- Missing/empty symbol requests now fail with a friendlier message recommending `-Refresh` or a cached symbol.

Visible output:

- One command that produces a predictable output folder containing bars, health, manifest, and chart.

### C. Multi-symbol workbench report

Status: done

Goal: Produce a small-basket inspection report for selected symbols and dates.

Branch: `codex/Gen5.1-candidate-bc-inspection-reports`

Validation:

- Focused chart/data-proof tests passed.
- `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.
- Operator smoke passed with cached `NVDA,SPY,QQQ,TSLA` data.
- Generated multi-pane chart was visually inspected.

Notes:

- Added `scripts/inspect/render_multi_symbol_report.ps1` as the PowerShell-first launcher.
- Added `scripts/inspect/render_multi_symbol_report.R` as the implementation script.
- Added multi-symbol report helpers in `R/workbench_data_proof.R`.
- Added reusable multi-pane candlestick rendering in `R/workbench_chart.R`.
- Packets write under ignored `runs/research_workbench/multi_symbol_reports/`.
- The workflow remains data-inspection only: no indicators, returns, strategy signals, WFA folds, allocation, execution, live advice, or performance claims.

Visible output:

- Per-symbol coverage table.
- Per-symbol chart paths or a compact chart set.

### D. First research experiment design discussion

Status: pending

Goal: Decide conversationally whether the first post-data experiment should be EMA long/cash, buy-and-hold/no-trade baselines, universe inspection, volatility ranking, or something else.

Visible output:

- A short written experiment contract naming inputs, outputs, allowed calculations, and stop gates.
