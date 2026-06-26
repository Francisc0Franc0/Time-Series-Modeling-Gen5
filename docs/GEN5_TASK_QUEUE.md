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

### E. Codify chart aesthetic language

Status: done

Branch: `codex/Gen5.1-chart-aesthetic-language`

Goal: Give Gen5.1 charts a consistent visual language before strategy overlays exist.

Validation:

- Focused chart tests passed.
- Multi-symbol report smoke passed from cache and generated a visually inspected chart.
- Final local test wrapper passed.
- Final credentialed refresh smoke was attempted because chart/cache workflows should refresh on final smoke unless blocked.

Notes:

- Added `docs/GEN5_1_CHART_AESTHETIC.md`.
- Added `g5_chart_aesthetic()` with standard candlestick colors, future native entry/exit markers, non-native exit markers, and win/loss round-trip connector colors.
- Updated single and multi-symbol candlestick charts to use warm backgrounds, teal/coral candles, muted ink axes/text, 45-degree date labels, and softer grids.
- Multi-symbol charts now use shared outer x/y axis labels instead of repeating axis labels in every pane.
- The workflow remains visual inspection only: no indicators, returns, strategy signals, WFA folds, allocation, execution, live advice, or performance claims.

### F. Green-day hold diagnostic strategy proof

Status: done

Branch: `codex/Gen5.1-green-day-hold-strategy-proof`

Goal: Prove Gen5 can program, chart, and account for a simple next-open strategy before attempting a minimal WFA POC.

Validation:

- Focused green-day hold strategy tests passed.
- `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.
- Final one-symbol AMD operator smoke passed with `-Refresh`.

Notes:

- Added a diagnostic strategy where `close > open` produces an entry signal on that bar, entry occurs at the next open, the position holds for a fixed number of trading sessions, exit signal occurs at the close after the hold window, and exit execution occurs at the next open.
- The implementation assumes one position at a time, no leverage, all-in sizing, and full round trips. Open trades are marked to the latest close for chart tracing and marked accounting.
- Added separate chart symbols for signal bars and execution bars.
- Added standard trade-history metrics: trade counts, closed/open split, win/loss/flat counts, win rate, compounded closed/marked return, average/median/best/worst return, average win/loss, gross profit/loss, profit factor, expectancy, exposure, average holding sessions, and closed-trade drawdown.
- The workflow remains a diagnostic strategy proof only: it is not WFA evidence, live advice, allocation logic, or a deployable strategy.

### G. Equity metrics and leverage diagnostic proof

Status: done

Branch: `codex/Gen5.1-green-day-hold-equity-metrics`

Goal: Extend the green-day hold proof with equity-path metrics, a buy-and-hold baseline, and a 1.8x leverage diagnostic run before WFA work.

Validation:

- Focused green-day hold strategy tests passed, including 1.8x leverage expectations.
- `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.
- Final one-symbol AMD operator smokes passed with `-Refresh` for 1.0x and 1.8x.

Notes:

- Added daily strategy equity curves, buy-and-hold baseline curves, CAGR, max drawdown, time underwater, and max underwater streak.
- Added equity curve PNG output with a solid black buy-and-hold baseline and soft red shading when strategy equity is underwater.
- Added `-Leverage` to the operator launcher. Leverage is modeled as simple linear return exposure with no financing-cost model for this diagnostic slice.
- Trade history now keeps underlying returns and leveraged returns so leverage effects are auditable.
- The workflow remains a diagnostic accounting proof only: it is not WFA evidence, live advice, margin policy, allocation logic, or a deployable strategy.

### H. EMA cross in-sample backtest proof

Status: done

Branch: `codex/Gen5.1-ema-cross-backtest-proof`

Goal: Replace the toy green-day signal with a simple EMA crossover strategy, evaluate a modest parameter grid inside one two-year trading window, select the highest-Sharpe parameter set, and emit the same style of operator-facing charts, accounting, metrics, and sortable parameter table.

Validation:

- Focused EMA cross strategy tests passed.
- `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.
- Final one-symbol AMD operator smokes passed with `-Refresh` for 1.0x and 1.8x.

Notes:

- Entry signals occur when the fast EMA crosses above the slow EMA at close; entry execution is modeled at the next session open.
- Exit signals occur when the fast EMA crosses below the slow EMA at close; exit execution is modeled at the next session open.
- The runner fetches extra warmup bars before the trading window so EMA state can initialize without pretending warmup dates are tradable experiment dates.
- Parameter performance is written as a CSV sorted by Sharpe then return, with the selected parameter set written to separate trade, event, indicator, equity, metrics, strategy-chart, and equity-chart outputs.
- Leverage is modeled as simple linear return exposure with no financing-cost model for this diagnostic slice.
- The workflow remains a pure in-sample backtest proof only: it is not train/OOS validation, WFA evidence, live advice, allocation logic, or a deployable strategy.

### I. EMA cross one-fold WFA POC

Status: done

Branch: `codex/Gen5.1-ema-cross-wfa-poc`

Goal: Prove the smallest train/OOS boundary on top of the EMA cross backtest: one earliest possible fold, 8 train quarters, 1 OOS quarter, train-selected EMA parameters, frozen OOS execution, OOS charting, and OOS metrics.

Validation:

- Focused one-fold EMA WFA tests passed.
- `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.
- Final one-symbol AMD operator smoke passed with `-Refresh`.

Notes:

- The POC fails loudly when the data window cannot support one train/OOS fold.
- The default operator launcher pulls about 2.9 years of requested data and extra EMA warmup history.
- Train selection uses the existing EMA parameter grid and ranks by train-window Sharpe, then return.
- OOS starts flat except that a final train-session close signal may execute at the first OOS open.
- OOS outputs include fold spec, train parameter table, train-selected metrics, OOS trades/events/equity/metrics, OOS strategy chart, and OOS equity curve.
- The workflow remains one-fold methodology plumbing only: it is not multi-fold WFA evidence, live advice, allocation logic, or a deployable strategy.

### J. Multi-signal three-fold stitched WFA POC

Status: done

Branch: `codex/Gen5.1-ema-cross-three-fold-wfa`

Goal: Extend the one-fold WFA POC to three rolling train/OOS folds, stitch all OOS periods into one live-like simulation, and make fold transitions visually auditable.

Validation:

- Focused multi-fold EMA WFA tests passed.
- `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.
- Final one-symbol AMD operator smoke passed with `-Refresh`.
- Generated stitched OOS strategy and equity charts were visually inspected.

Notes:

- Standard language now distinguishes `strategy_family` such as `ema_cross` from `model_instance_id` such as `ema_cross_fast12_slow30`.
- The original three-fold slice selected one model instance from the EMA grid using train-window Sharpe, then return; the current POC has since expanded this to multi-signal candidate competition.
- Open positions are carried across fold boundaries; future exit signals are governed by the current fold-selected model instance.
- Final-bar fold signals may execute at the next open if that next session is inside the stitched OOS span.
- Outputs include fold specs, selected model instances, train parameter performance by fold, model stability, fold-level OOS summaries, stitched trades/equity/metrics, and stitched OOS charts.
- Stitched strategy and equity charts alternate fold backgrounds between white and light gray so fold transitions and model-instance changes are auditable.
- The workflow remains three-fold WFA plumbing only: it is not final research evidence, live advice, allocation logic, or a deployable strategy.

### C4. Multi-signal WFA candidate competition and report

Status: done

Branch: `codex/Gen5.1-multi-signal-wfa-report`

Goal: Add a second basic signal family, let `ema_cross` and `bollinger_touch` model instances compete inside each TRAIN fold, and expand the stitched metrics markdown into a transparent run report.

Validation:

- Focused Bollinger touch strategy tests passed.
- Focused multi-fold WFA tests passed with EMA-only and mixed-candidate paths.
- Final one-symbol AMD operator smoke passed with `-Refresh`.
- Generated stitched OOS strategy and equity charts were visually inspected.

Notes:

- `strategy_family` now includes `ema_cross` and `bollinger_touch`.
- `model_instance_id` names the concrete family plus params, such as `bollinger_touch_n20_sd2p5`.
- Each TRAIN fold selects the best candidate model instance across all enabled families using train-window Sharpe, then return.
- New operator-facing runner: `scripts/inspect/run_multi_signal_wfa_poc.ps1`.
- Old EMA-named runner files remain as compatibility wrappers only.
- New generated run folders/files use the `multi_wfa_...` artifact prefix instead of `ema_wfa3_...`.
- The markdown report now includes run context, data/query window, WFA settings, fold calendar, candidate signal models, fold winners, fold OOS summaries, stitched OOS metrics, buy-and-hold baseline, model stability, and audit notes.
- Stitched charts plot EMA overlays only in EMA-selected folds and Bollinger bands only in Bollinger-selected folds.

### C5. Multi-signal WFA naming cleanup

Status: done

Branch: `codex/Gen5.1-multi-signal-naming-cleanup`

Goal: Rename the current POC's outward-facing script and generated artifact prefix so they no longer imply EMA-only testing.

Notes:

- Preferred operator runner is `scripts/inspect/run_multi_signal_wfa_poc.ps1`.
- `scripts/inspect/run_ema_cross_wfa_multi.ps1` and `.R` remain thin compatibility wrappers.
- Generated packet prefixes now start with `multi_wfa_`.

### C6. Exit stack WFA POC

Status: done

Branch: `codex/Gen5.1-exit-stack-wfa-poc`

Goal: Add a narrow close-based exit-stack layer on top of the current multi-signal WFA POC. Compose `model_instance_id` plus `exit_stack_id` into a complete `strategy_spec_id`, evaluate complete strategy specs in TRAIN, and run selected specs in stitched OOS.

Implemented architecture:

- Entry/native signal families remain upstream: currently `ema_cross` and `bollinger_touch`.
- Exit stacks are additive trade-policy candidates, not post-hoc portfolio transformations.
- WFA selection authority should rank complete `strategy_spec_id`s rather than only entry model instances.
- Reporting and charting consume selected specs and emit stitched trades, equity, charts, and run reports.

Initial exit stacks:

- `native_only`
- `max_hold_n_sessions`
- `close_below_stop_pct`
- `close_above_take_profit_pct`
- combined stop/take-profit/max-hold stacks.

POC guardrails:

- Keep exits close-based with next-open execution to avoid intraday fill assumptions.
- Use deterministic "earliest valid exit wins" behavior.
- If multiple exit reasons trigger on the same signal bar, use risk-first attribution for reporting.
- Preserve the current one-position-at-a-time, all-in, no-leverage assumptions unless the operator opens a sizing/leverage slice.
- Record `model_instance_id`, `exit_stack_id`, `strategy_spec_id`, `primary_exit_reason`, triggered exit rules, and native-versus-stack exit attribution.
- Keep grids modest.
- Do not add portfolio allocation, state/regime filters, live advice, or intraday execution in this slice.

Visible output:

- WFA markdown report naming candidate strategy specs and fold-selected specs.
- Stitched OOS strategy chart with native versus exit-stack markers when both appear in selected OOS trades.
- Stitched OOS equity chart and metrics.
- CSV trade ledger with exit attribution.

Validation:

- Focused multi-fold WFA tests passed.
- Full local runner passed.
- Final AMD three-fold smoke passed with `-Refresh`.

Notes:

- Default exit-stack grid uses `native_only`, native plus max-hold sessions, native plus close-based stop loss, native plus close-based take profit, and combined native/stop/take/max-hold stacks.
- The final AMD smoke selected `native_only` in fold 1 and `native_maxhold40` in folds 2-3.
- In that AMD OOS path, both closed trades exited by native signal before the selected max-hold stack fired; the stack marker path is implemented but was not visually exercised by this specific selected OOS path.

### C7. Multi-asset independent WFA batch diagnostic

Status: done

Branch: `codex/Gen5.1-multi-asset-wfa-batch`

Goal: Run the existing multi-signal/exit-stack WFA POC independently across a small asset basket and emit a cross-asset report without pooling TRAIN data or introducing portfolio allocation.

Implemented architecture:

- Each symbol gets its own data query, TRAIN folds, selected `strategy_spec_id`s, OOS trades, equity curve, charts, and run report.
- Batch-level outputs summarize already-generated per-symbol packets only.
- No global parameter selection, pooled training, cross-asset ranking authority, capital allocation, or portfolio construction is introduced.

Visible output:

- `scripts/inspect/run_multi_asset_wfa_batch.ps1`
- Batch asset summary CSV.
- Batch selected specs by fold CSV.
- Batch path index CSV.
- Batch Markdown report.
- Per-symbol stitched strategy/equity charts under the batch output folder.

Validation:

- Focused multi-fold WFA tests passed after adding coverage for mixed selected strategy families.
- Six-symbol refreshed batch passed for `AMD,NVDA,TSLA,META,QQQ,SPY`.

Observed six-symbol smoke result:

- QQQ: 16.68% return, Sharpe 1.917, 2 exit-stack exits.
- SPY: 6.64% return, Sharpe 1.601, 1 exit-stack exit.
- AMD: 16.08% return, Sharpe 1.269, 2 native exits.
- NVDA: 12.00% return, Sharpe 0.930, 1 native exit and 1 exit-stack exit.
- TSLA: 3.26% return, Sharpe 0.394, 1 exit-stack exit.
- META: -11.75% return, Sharpe -0.512, 4 native exits and 1 exit-stack exit.

### C8. Multi-asset WFA chart contact sheets

Status: done

Branch: `codex/Gen5.1-wfa-chart-contact-sheets`

Goal: Make multi-asset WFA visual inspection less click-heavy by chunking strategy and equity charts into contact-sheet images with at most six facets per image by default.

Implemented architecture:

- The batch runner keeps the detailed per-symbol WFA packets unchanged.
- It additionally renders compact strategy contact sheets and equity contact sheets directly from the in-memory stitched OOS data.
- Contact-sheet pages are indexed in a CSV and linked from the batch Markdown report.
- `-MaxFacetsPerImage` controls the chunk size from the PowerShell wrapper.

Visible output:

- Strategy contact-sheet PNGs under the batch output folder.
- Equity contact-sheet PNGs under the batch output folder.
- Batch contact-sheet index CSV.
- Batch report contact-sheet table.

### C9. Gen4-inspired strategy family ports

Status: done

Branch: `codex/Gen5.1-gen4-strategy-ports`

Goal: Recreate the useful essence of the active Gen4 signal families in the Gen5 WFA POC without importing Gen4's registry complexity or expanding into unrelated research layers.

Implemented candidate families:

- `ema_cross`: fast EMA crosses above/below slow EMA.
- `ema_trend`: fast EMA above slow EMA with positive fast-EMA slope.
- `bollinger_touch`: lower-band entry and upper-band native exit.
- `bollinger_mid_reversion`: Gen4-style lower-band entry and middle-band native exit.
- `rsi_mr`: RSI mean-reversion entry/exit thresholds.
- `zret_mr`: one-bar return z-score shock and normalization.
- `breakout`: close above a rolling breakout level, exiting below a rolling midline.
- `pullback_in_uptrend`: pullback entries while a slow EMA trend filter remains positive.
- `vol_expansion_breakout`: breakout entry only when normalized Bollinger width expands enough.
- `donchian_breakout_vol_expand`: Donchian-style breakout after prior Bollinger-width compression and current expansion.
- `no_trade`: inert cash/no-position competitor with zero exposure and one `no_exit` pseudo stack.

Notes:

- SMA variants are intentionally deferred.
- The two Bollinger families are kept separate because their native exit semantics differ.
- State-gated variants remain future slices.
- The expanded family set can be passed through `-CandidateFamilies`; the existing smaller default remains available for focused smoke tests.

### C10. Volatility-expansion breakout family ports

Status: done

Branch: `codex/Gen5.1-vol-expansion-breakouts`

Goal: Add the two raw Gen4 volatility-expansion breakout candidates as focused Gen5 WFA POC families, keeping them testable independently from the larger candidate library.

Implemented candidate families:

- `vol_expansion_breakout`: close above the prior rolling close-high plus buffer, with normalized Bollinger width expanding by at least the threshold; native exit below the rolling midline.
- `donchian_breakout_vol_expand`: the same close-based breakout/expansion confirmation, but only after prior normalized Bollinger width is below its own rolling mean, approximating the Gen4 intent of post-compression expansion; native exit below the rolling midline.

Notes:

- Both families remain close-signal, next-open-execution strategies.
- No new dependencies were added.
- The focused smoke should run only these two families first before adding them to broad candidate runs.
- The state-gated volatility-expansion variant remains deferred until a regime/state layer is opened.

### C11. No-trade WFA competitor

Status: done

Branch: `codex/Gen5.1-no-trade-competitor`

Goal: Add no-trade/cash as an inert TRAIN competitor so the WFA selector can choose not to trade when all active strategy specs are unattractive.

Implemented behavior:

- `no_trade` emits no entry or exit signals.
- It uses one `no_exit` pseudo exit stack instead of multiplying across stop, take-profit, or max-hold combinations.
- TRAIN metrics use zero return, zero exposure, and Sharpe `0`, so no-trade can beat negative active specs without being ranked as missing data.
- Stitched OOS behavior remains ordinary cash/no-position accounting when selected.

### D. Later POC backlog discussion

Status: deferred

Goal: Decide conversationally whether the next independent POC after exit stacks should be portfolio construction, universe inspection, volatility ranking, state/regime filtering, or something else.

Visible output:

- A short written experiment contract naming inputs, outputs, allowed calculations, and stop gates.

### E. Regime/state filter POC roadmap

Status: PCA quantile-grid diagnostic POC and one-fold PCA-routed WFA Option A POC implemented; remaining regime methods and multi-fold state routing are planned.

Planning memory: `docs/GEN5_REGIME_FILTER_POC_PLAN.md`

Current state:

- `R/regime_pca_poc.R` and `scripts/inspect/run_pca_regime_poc.ps1` implement a diagnostic-only PCA 3x3 state-labeling POC.
- The POC writes state scores, model contract, diagnostics, state coverage, run lengths, markdown report, PC1/PC2 scatter, and price/state chart under ignored `runs/research_workbench/regime_pocs/`.
- `R/regime_pca_wfa_poc.R` and `scripts/inspect/run_pca_wfa_router_poc.ps1` implement a one-fold AMD PCA-routed WFA POC.
- The routed POC selects one complete `strategy_spec_id` per TRAIN PCA state and replays those state selections in OOS using Option A: entry state owns the trade until exit.
- Routed POC outputs are written under ignored `runs/research_workbench/regime_wfa_pocs/` with short `pcawfa` filenames to avoid Windows path-length issues.
- It does not yet implement multi-fold state-routed WFA, state-adaptive exits, portfolio allocation, leverage, live advice, or execution.
- Then compare PCA plus clustering, a simple volatility percentile baseline, and HMMs as separate isolated POCs.
- Do not let any regime method route WFA strategy selection until its state labels, coverage, and leakage controls are auditable.
