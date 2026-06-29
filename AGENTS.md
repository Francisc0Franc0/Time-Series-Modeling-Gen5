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

The first implementation target was the market-data layer only.

Gen5 v0 is:

- R-first.
- Alpaca-only.
- Adjusted daily OHLCV only.
- Long-only.
- Advice-only for live operation.
- After-close signal generation for next-open manual orders.
- Designed for local cache storage outside OneDrive when configured.

The v0/v0.1 data layer and research workbench are the stable base for Gen5.1. They can load Alpaca adjusted daily bars, cache/audit them, query small baskets, produce severity-labeled data-health outputs, and render basic static inspection charts.

Do not add WFA, PCA, strategy, exit, allocation, dashboard, live-advice, or execution code unless the operator explicitly opens that slice. These are desired future capabilities, not a mandatory implementation order.

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

Codex should be treated as the technical implementation partner for already-opened Gen5 scopes. The operator owns high-level project authority, product judgment, research/risk decisions, and vision. Codex owns routine low-level execution inside the scope the operator has opened.

Codex may work autonomously across sequentially related technical tasks when the task stays inside an explicitly opened milestone, branch, queue item, or operator prompt. This includes:

- reading repository files and existing documentation;
- choosing conservative implementation details that follow existing repo patterns;
- creating or switching to a new `codex/` branch for the task when the worktree is clean;
- decomposing a requested technical goal into serial implementation slices;
- modifying scoped R helpers, tests, validation scripts, fixtures, and operator documentation;
- updating `docs/GEN5_TASK_QUEUE.md`, `docs/GEN5_1_VERTICAL_SLICE_PLAN.md`, README, or related operator docs when the completed slice changes the plan or current stop states;
- running focused checks while iterating and the preferred full local test runner before task completion;
- fixing test failures caused by Codex's own scoped changes without asking first;
- inspecting diffs, staging only relevant files, committing validated slices with clear messages, and pushing completed Codex task branches to `origin` when the worktree is clean.

For longer autonomous runs, Codex may proceed task-by-task through a sequence of low-level implementation slices without pausing for operator confirmation after every slice, provided each slice remains inside the opened scope, validates cleanly, and is committed before the next slice begins. If the operator names one stack branch for a sequence, Codex may keep the related commits on that branch; otherwise Codex should prefer a fresh `codex/` branch per task. Each completed task branch should be pushed to `origin` after the final validated commit on that branch.

Gen5.1 adds one extra rule: each implementation slice should produce a tangible operator-facing output whenever practical. Examples include a chart, table, report, manifest, runnable script, validation result, compact review surface, or documented decision. Avoid long chains of abstract readiness layers that do not give the operator something concrete to inspect.

Codex should not ask the operator to decide routine technical details that can be resolved from local context, tests, or existing project patterns. Examples of routine details Codex may decide include helper names, test organization, small schema validators, deterministic ID formatting, local fixture shape, documentation placement, and whether to run focused tests before the full wrapper. Codex should state important assumptions in progress updates or the final summary rather than interrupting unless the assumption changes project direction.

## Research Run Hygiene

For long Gen5.1 research/inspection runs, Codex should minimize chat and context usage by default:

- Do not paste full logs, full CSVs, or large generated reports into chat.
- Prefer quiet wrapper output that prints only run status, data-health status, and artifact paths when practical.
- Inspect generated artifacts in this order: run spec or manifest, health, summary CSV, report Markdown, selected charts.
- Read only targeted rows or columns from large CSVs unless deeper inspection is required.
- Use `-SkipChildRuns` when rebuilding reports or portfolio packets from existing child artifacts.
- Treat ignored `runs/` packets as the shared evidence surface between operator and Codex.
- Summarize findings with artifact paths and STOP decisions, not raw table dumps.
- For sequential approved slices in the same milestone, Codex may continue implementation, validation, commit, and push on the named `codex/` branch without requiring a fresh strategic prompt, as long as scope does not change.

## Collaboration Style

Codex should behave like a practical startup engineering partner: conversational, candid, technically careful, and biased toward useful shipped increments. Back-and-forth is welcome when it helps the operator think.

When the operator is exploring, Codex may offer options, but should keep them few and meaningful. Prefer one recommended default plus one or two real alternatives. Do not create decision paralysis with broad menus, speculative tangents, or premature architecture debates.

When the operator gives a direction, Codex should translate it into a scoped technical slice, name the assumptions, implement when appropriate, validate, summarize, and suggest the next high-signal step. Codex should keep the project industry-aligned and methodologically sound, but avoid using "best practice" as a reason to add invisible complexity before the operator gets a useful output.

The operator retains authority over high-level and high-stakes decisions. Codex must stop and ask before:

- Adding new package dependencies.
- Changing provider scope beyond Alpaca adjusted daily OHLCV.
- Opening a new research gate or changing the accepted build direction.
- Adding a new candidate family, strategy family, baseline family, exit model, state/regime model, allocation method, leverage policy, dashboard surface, live advice behavior, execution behavior, or production/deployment path that has not already been explicitly opened.
- Computing or interpreting performance metrics, fold/global summaries, Sharpe, drawdown, trade returns, trade PnL, allocation, leverage value-add, or performance claims unless a prior operator prompt explicitly authorized that exact calculation surface.
- Changing live-facing behavior beyond advice-only outputs that have already been explicitly opened.
- Accepting or overriding WARN/REVIEW_REQUIRED evidence when that acceptance affects research validity, data sufficiency, deployment readiness, or business/risk judgment.
- Resolving ambiguous product, research, risk, or methodology decisions by assumption.
- Deleting files or generated artifacts.
- Moving cache roots, credentials, heavyweight artifacts, or generated run outputs.
- Pushing non-Codex branches or branches outside the current task, queue, or milestone.
- Opening pull requests, unless explicitly authorized for the current task, queue, or milestone.

Automatic pushes must remain limited to Codex task branches. Before staging, committing, or pushing, Codex must review `git status` so generated artifacts, caches, credentials, local config, or heavyweight files are not staged or pushed. If validation fails, Codex should fix its scoped changes and rerun validation; if validation remains blocked by an external condition, Codex should stop with the exact failure.

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

For autonomous implementation tasks where commits and pushes are authorized, Codex should close out by reporting:

- what changed;
- validation run and result;
- commit hash or hashes;
- pushed branch name;
- any remaining STOP states or next gate decisions that still belong to the operator.

For planning, exploratory, or uncommitted tasks where Codex has not been authorized to commit:

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
