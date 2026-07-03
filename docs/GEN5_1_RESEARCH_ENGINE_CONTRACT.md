# Gen5.1 Research Engine Contract

Status date: 2026-06-28

This contract canonizes the current Gen5.1 research-workbench engine. It describes the stable layers, run-spec vocabulary, artifact boundaries, and STOP rules for future experiment wrappers.

This is a **research and inspection engine**, not a production allocation engine, live advice engine, broker execution path, or final research-evidence authority.

## Purpose

Gen5.1 now has enough composable pieces that future work should treat the engine as a stable base. Experiment scripts should declare what to run, call the engine layers, and write inspectable artifacts. They should not re-explain or reimplement the full universe x PCA panel x state map x strategy grid x WFA x portfolio accounting stack.

Future prompts can say:

> Use the Gen5.1 research engine contract. Create a wrapper for experiment X.

The wrapper should then be a small experiment recipe around the shared engine.

## Engine Layers

### 1. Data Authority Layer

Inputs:

- explicit `as_of_timestamp`;
- bounded date range;
- Alpaca adjusted daily OHLCV symbols.

Responsibilities:

- resolve latest completed session from explicit timestamp;
- load/cache adjusted daily bars;
- write audit, manifest, health, refresh-plan, and coverage outputs;
- keep provider quirks inside provider modules.

Must not:

- call `Sys.Date()` from analytical modules;
- infer latest market session independently;
- change provider scope beyond Alpaca adjusted daily OHLCV without operator approval.

### 2. Universe Declaration Layer

Each experiment must make these roles explicit:

- **Regime Context Universe**: symbols used to build PCA state context.
- **Research Candidate Universe**: symbols whose strategy specs are evaluated.
- **Tradeable Universe**: symbols the replay may trade.
- **Active Allocation Set**: symbols allowed to receive portfolio capital.
- **Baseline Reference Symbols**: passive reference symbols such as `SPY`.

For single-symbol PCA WFA, the Research Candidate Universe, Tradeable Universe, and Active Allocation Set may be one symbol. For portfolio accounting, they may be a small declared set.

The engine must not choose these roles from OOS performance. Symbol selection is an experiment-design decision or later research gate.

### 3. PCA Regime Layer

Panel modes:

- `contextual_snapshot`: wide/date-aligned context; internal value `date_aligned_context`.
- `behavioral_pool`: long/pooled asset-day context; internal value `pooled_asset_day`.

State maps:

- `quantile_grid`: PC1/PC2 quantile bins, such as `3x3`.
- `kmeans`: TRAIN-fitted k-means clusters on PC1/PC2, such as `k9`.

Responsibilities:

- fit PCA/state assignment only from TRAIN-side information inside each fold;
- write PCA scores, model contracts, state coverage, and visual inspection charts;
- keep PCA mode and state map visible in run paths/reports.

Must not:

- use OOS observations to fit state models;
- select panel mode/state map from OOS outcomes without an explicit research gate.

### 4. Signal/Strategy Spec Layer

Responsibilities:

- house strategy families and parameter grids;
- include `no_trade` as a first-class competitor;
- produce strategy specs used by charts, TRAIN selection, and OOS routing.

Current strategy families include EMA, Bollinger, RSI/z-score mean reversion, breakout/pullback, volatility-expansion, Donchian volatility breakout, and `no_trade`.

Adding a new strategy family or materially changing the candidate grid is a STOP decision unless the operator has opened that slice.

### 5. WFA Router Layer

Current policy:

- `entry_state_owns_trade_until_exit`.

Responsibilities:

- define rolling folds;
- evaluate candidates on TRAIN only;
- select state-owned specs per fold/state;
- simulate stitched OOS using frozen TRAIN decisions;
- write folds, selected states, train state performance, OOS trades, OOS equity, OOS metrics, and reports.

Must not:

- recompute authority from OOS;
- use OOS metrics to choose specs, states, or parameters;
- imply accepted research evidence unless the operator explicitly opens that gate.

### 6. Portfolio Accounting Layer

Current default policy:

- dynamic equal-slot entry sizing;
- cash-capped entries;
- no scheduled rebalance;
- no leverage, margin, shorting, execution optimization, or live advice.

Responsibilities:

- consume declared single-symbol stitched OOS child artifacts;
- build a shared-account portfolio event ledger;
- write portfolio equity, passive baselines, symbol summary, child artifact index, and dashboard/report outputs.

Current passive baselines:

- full-capital `SPY` buy-and-hold;
- equal active-set buy-and-hold, total equity only.

Must not:

- choose assets from OOS performance;
- optimize allocations;
- change live-facing behavior;
- present accounting validation as accepted allocation evidence.

## Canonical Run Spec Vocabulary

Future wrappers should expose or construct a run spec with these fields where relevant:

```text
run_id
as_of_timestamp
end_date
refresh

regime_context_symbols
research_candidate_symbols
tradeable_symbols
active_allocation_symbols
baseline_symbols

pca_panel_mode
state_engine
state_count
kmeans_nstart
min_train_state_rows

train_quarters
oos_quarters
fold_count
warmup_days

candidate_families
strategy_grid_preset
fast_periods
slow_periods
bb_lookback_periods
bb_sd_multipliers

initial_capital
slot_count
sizing_policy
baseline_policy

skip_child_runs
output_dir
```

Not every wrapper needs every field, but fields that affect data authority, leakage safety, state construction, strategy selection, or accounting should be explicit in the command, settings object, or generated report.

## Artifact Contract

Generated artifacts live under ignored `runs/` folders and must not be committed.

### Child PCA WFA Packet

Each child packet should expose:

- `pcawfa_manifest.csv`
- `pcawfa_health.csv`
- `pcawfa_folds.csv`
- `pcawfa_selected_states.csv`
- `pcawfa_train_state_performance.csv`
- `pcawfa_state_coverage.csv`
- `pcawfa_pca_scores.csv`
- `pcawfa_pca_model_contract.csv`
- `pcawfa_oos_trades.csv`
- `pcawfa_oos_equity.csv`
- `pcawfa_oos_metrics.csv`
- `pcawfa_report.md`
- relevant PNG charts.

### Comparison Packet

Comparison packets should expose:

- summary CSV;
- path/index CSV;
- selected-family counts when applicable;
- contact sheets or overview graphics;
- report Markdown with STOP guardrails.

### Portfolio Packet

Portfolio packets should expose:

- `portfolio_poc_report.md`
- `portfolio_poc_equity.csv`
- `portfolio_poc_events.csv`
- `portfolio_poc_metrics.csv`
- `portfolio_poc_baselines.csv`
- `portfolio_poc_baseline_metrics.csv`
- `portfolio_poc_standalone_symbol_equity.csv`
- `portfolio_poc_symbol_summary.csv`
- `portfolio_poc_child_artifact_index.csv`
- `portfolio_poc_equity_curves.png`

The portfolio curve is the authoritative accounting output. Passive baseline and standalone symbol curves are inspection references.

## Wrapper Pattern

Experiment wrappers should be thin:

1. Parse operator-facing parameters.
2. Build a run spec.
3. Query data once for required symbols.
4. Run or resolve child artifacts.
5. Pass artifacts to comparison/accounting/reporting helpers.
6. Write a compact packet under `runs/`.
7. Print exact output paths and data-health status.

Wrappers may run one point in the design space or a grid. The grid is an experiment-design choice, not a new engine.

Examples:

- one symbol x one context x one panel mode x one state map;
- one symbol x three context universes x 2x2 `PanelMode x StateMap`;
- five active symbols x one context x one panel/state map x one portfolio accounting packet;
- future declared grids over active sets, context universes, panel modes, state maps, and strategy presets.

## STOP Boundaries

The operator must decide before:

- accepting or rejecting research hypotheses from OOS performance;
- using performance to choose symbols, PCA modes, state maps, strategy grids, or allocation policies;
- expanding beyond Alpaca adjusted daily OHLCV;
- adding strategy families, exit policies, allocation optimizers, leverage policies, dashboards, live advice, or execution behavior;
- treating portfolio accounting output as deployment evidence;
- accepting WARN/REVIEW_REQUIRED evidence when it affects research validity or deployment readiness.

Codex may decide routine helper names, output placement, focused tests, and wrapper plumbing when the requested slice stays inside this contract.

## Current Canonical Surfaces

Single-symbol PCA comparison:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/inspect/run_pca_comparison_report.ps1 `
  -Symbol AMD `
  -RegimeContextSymbols "AMD,NVDA,TSLA" `
  -EndDate 2026-06-24 `
  -AsOfTimestamp "2026-06-24 17:30:00" `
  -FoldCount 5 `
  -QuantileStateCount 3 `
  -KmeansStateCount 9 `
  -Refresh
```

Context-universe panels:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/inspect/run_pca_context_universe_panels.ps1 `
  -Symbol AMD `
  -EndDate 2026-06-24 `
  -AsOfTimestamp "2026-06-24 17:30:00" `
  -FoldCount 5 `
  -QuantileStateCount 3 `
  -KmeansStateCount 9 `
  -Refresh
```

Portfolio accounting:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/inspect/run_portfolio_strategy_poc.ps1 `
  -EndDate 2026-06-24 `
  -AsOfTimestamp "2026-06-24 17:30:00" `
  -Refresh
```

After child WFA packets exist, use `-SkipChildRuns` to rebuild the portfolio packet without rerunning all child simulations.

## Practical Prompt Template

```text
Please start on branch codex/<branch-name>. Read AGENTS.md, docs/GEN5_1_CURRENT_HANDOFF.md, and docs/GEN5_1_RESEARCH_ENGINE_CONTRACT.md first.

Use the Gen5.1 research engine contract. Create a wrapper for <experiment>, with:
- Regime Context Universe: <symbols>
- Research Candidate Universe: <symbols>
- Tradeable Universe: <symbols>
- Active Allocation Set: <symbols>
- PCA panel/state surface: <panel modes and state maps>
- Strategy grid preset: <gen4_daily_default/standard/modest_expanded>
- End date/as-of timestamp: <date/timestamp>

Keep this as research/inspection only. Produce concrete reports/charts, validate, commit, and push.
```
