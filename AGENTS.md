# AGENTS.md

## Purpose

This repository is the Gen5 rebuild of the Time-Series-Modeling WFA trading system.

Gen5 keeps the strongest Gen4 principles while discarding accidental complexity:

- WFA-first validation.
- No leakage from OOS into training, state assignment, parameter selection, or execution.
- Auditability over opaque performance claims.
- No-trade as a first-class competitor.
- Research-to-execution separation through frozen decision packs.
- Daily long-only advice-first operation before any automation.

## Gen5 v0 Contract

The first implementation target is the market-data layer only.

Gen5 v0 is:

- R-first.
- Alpaca-only.
- Adjusted daily OHLCV only.
- Long-only.
- Advice-only for live operation.
- After-close signal generation for next-open manual orders.
- Designed for local cache storage outside OneDrive when configured.

Do not add WFA, PCA, strategy, exit, allocation, or dashboard code until the data-layer contract and tests are stable.

## Objective

Build a long-only, rolling walk-forward, regime-conditioned tactical equity/ETF system targeting aggressive capital growth from volatile but structurally tradeable assets, with explicit controls for drawdown, concentration, leverage value-add, and out-of-sample robustness.

## Invariants

1. No analytical module may call `Sys.Date()` or independently infer the latest market session.
2. Every data pull must carry an explicit `as_of_timestamp`.
3. Adjusted daily bars are the canonical Gen5 v0 bar type.
4. Provider quirks must stay inside provider modules.
5. Cache reads and writes must be auditable and deterministic.
6. Live-facing outputs must eventually consume frozen WFA evidence, not recompute authority.
7. Heavy generated artifacts and data caches should not live in git.

## R Testing Instructions

For Gen5 R validation, Codex should first run the local test runner:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1
```

This is the preferred validation command because it selects the expected `Rscript` path, adds ignored `.codex_r_libs/` to `.libPaths()`, and runs the scaffold smoke test, data-layer validation, and non-network `testthat` tests.

If the local test runner cannot start, Codex must say so clearly, include the error, and then fall back to the explicit known-good commands:

```powershell
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' tests\smoke_test.R
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' scripts\validate\validate_data_layer.R
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' -e ".libPaths(c(normalizePath('.codex_r_libs', winslash='/'), .libPaths())); testthat::test_dir('tests/testthat')"
```

Do not rely on bare `Rscript` unless `Get-Command Rscript` confirms it is available.

R startup locale warnings on Windows are non-fatal unless tests fail.

## Codex Autonomy Policy

Within the Gen5 v0 market-data-layer milestone, Codex may work autonomously across sequentially related tasks when the scope remains limited to:

- Alpaca adjusted daily OHLCV market-data modules.
- Cache, audit, and deterministic data-layer behavior.
- Validation scripts and non-network tests.
- Operator documentation, README cleanup, and freeze-evidence documentation.

Codex may read repository files, modify scoped files, run the preferred local test runner, inspect git diffs, create branches with the `codex/` prefix, stage relevant files, and prepare commits when validation passes.

When the operator authorizes an autonomous queue or milestone to push, Codex may push each completed task branch to `origin` after the task commit succeeds and the worktree is clean. Automatic pushes must remain limited to the relevant task branch or explicitly authorized queue branches, and Codex must still review `git status` so generated artifacts, caches, credentials, or heavyweight files are not staged or pushed.

Codex must stop and ask before:

- Adding new package dependencies.
- Changing provider scope beyond Alpaca adjusted daily OHLCV.
- Adding WFA, PCA, strategy, exit, allocation, dashboard, or execution logic.
- Changing live-facing behavior beyond advice-only market-data-layer outputs.
- Deleting files or generated artifacts.
- Pushing branches, unless explicitly authorized for the current task, queue, or milestone.
- Opening pull requests, unless explicitly authorized for the current task, queue, or milestone.

For larger autonomous runs, Codex should proceed task-by-task, validate each completed slice, summarize the result, and then continue only within the authorized Gen5 v0 market-data-layer scope.

## Planning Requirement

At the start of each new non-trivial Codex task, before the implementation plan, provide a brief plain-language context note that says:

- where this sub-task sits inside the current larger task or milestone;
- where that milestone sits in the overall Gen5 progression;
- what kind of visible system behavior this work moves us closer to, without implying that out-of-scope modules already exist.

Keep this context short and practical. It should orient the operator, not restate the whole project charter.

For non-trivial changes, present a short plan before modifying files. Include:

- files likely to change
- invariants to preserve
- side effects or downstream implications
- validation or smoke checks

## Response Closeout Protocol

When warranted at the end of a completed task:

- Recommend the script or scripts the operator should run next, then await confirmation that the task was accomplished.
- After the operator confirms completion, provide a suggested commit message for the task that is being closed out.
- Then suggest next steps aligned with the current plan, including a proposed new branch name, next Codex prompt, and recommended reasoning level.
- When suggesting a next Codex prompt for a new task, embed the proposed branch name directly in the prompt so the next task starts on the intended branch.

## Coding Style

- Prefer explicit, boring, testable R over clever abstractions.
- Keep base-R paths available where practical.
- Add dependencies only when they clearly earn their keep.
- Fail loudly on ambiguous dates, missing required columns, duplicate bars, or future data.
- Keep generated plots rare and purposeful.
