# Gen5.1 Vertical Slice Plan

## Purpose

Gen5.1 is a working reset on top of the completed Gen5 v0/v0.1 data foundation. It keeps the useful market-data and research-workbench base, but stops treating the old post-data-layer roadmap as a rigid implementation sequence.

The point of Gen5.1 is to build the trading research pipeline through visible, inspectable slices. Each meaningful task should move the operator closer to something concrete: loaded data, a chart, a table, a small report, a runnable script, a validation result, or a clear decision surface.

## Current Stable Base

The branch keeps:

- Alpaca-only adjusted daily OHLCV loading.
- Explicit `as_of_timestamp` handling.
- Deterministic local cache planning, reads, writes, and merge behavior.
- Data audit and severity-labeled health outputs.
- Source-controlled universe registry scaffolding.
- Research workbench query scripts.
- Basic static chart rendering from canonical bars.
- Non-network local validation through `scripts/test/run_tests.ps1`.

The branch intentionally does not keep the large WFA/AMD EMA scaffold stack from later experimental branches.

## Core Values

- Make data authority explicit.
- Keep provider quirks inside provider modules.
- Preserve no-leakage discipline when research slices are opened.
- Prefer simple, boring, testable R.
- Produce human-facing evidence early and often.
- Keep no-trade, cash, and baseline comparisons available when strategy work is opened.
- Treat generated caches, plots, reports, and run artifacts as local outputs, not source.
- Avoid invisible architecture work unless it directly supports a visible slice.

## Working Rhythm

For each non-trivial task:

1. Orient briefly: where this task fits and what visible behavior it moves toward.
2. Create or use an appropriate `codex/` branch.
3. Read the relevant local files before editing.
4. Make a scoped change.
5. Produce a tangible output when practical.
6. Run focused checks and the local test wrapper when code, validation behavior, or operator docs change.
7. For operator-facing data/cache/chart workflows, run the final smoke with a credentialed refresh unless there is a specific reason not to; state the reason if refresh is skipped or blocked.
8. Review `git status` and avoid staging generated artifacts, caches, credentials, or local config.
9. Commit with a clear message.
10. Push Codex task branches when validation passes and the worktree is clean.
11. Summarize what changed, what was validated, and what decision or next slice remains.

## Flexible Capability Backlog

These are desired capability areas, not a required order:

- Better data inspection reports for selected symbols and date ranges.
- Basic chart/report generation from cached or refreshed Alpaca data.
- Feature construction from canonical bars.
- One-asset or small-basket strategy experiments.
- Walk-forward evaluation methodology.
- Baseline comparisons such as no-trade, cash, and buy-and-hold.
- Universe curation and asset taxonomy.
- State/regime modeling, possibly including PCA.
- Trade lifecycle and exit-policy modeling.
- Portfolio allocation and concentration controls.
- Leverage comparison reports.
- Frozen decision packs.
- Advice-only live review surfaces.

The operator may choose the next slice organically. Codex should help shape that slice into a disciplined, testable task without forcing the entire backlog into a fixed sequence.

## Stop Gates

Codex must stop and ask before:

- Adding dependencies.
- Expanding beyond Alpaca adjusted daily OHLCV.
- Adding strategy families, WFA methodology, allocation, leverage, live advice, dashboard, execution, or production behavior that the operator has not explicitly opened.
- Computing or interpreting performance metrics or performance claims without explicit authorization for the exact surface.
- Accepting data warnings when the acceptance changes research validity or deployment judgment.
- Deleting files, generated artifacts, caches, credentials, or heavyweight outputs.

## First Good Next Slices

The next task does not have to be a WFA or EMA task. Good first Gen5.1 slices include:

- Produce an AMD data proof report: load/read adjusted daily bars, render a chart, and write a compact data-health table.
- Produce a multi-symbol data inspection report for a hand-picked basket.
- Tighten the workbench chart command so it is easier for the operator to run repeatedly.
- Add a tiny report wrapper that turns one workbench query into a folder containing bars, health CSV, and PNG.

The best next slice is whichever gives the operator the clearest immediate feedback.
