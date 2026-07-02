# Gen5.1 Selection Policy Hypothesis

Status date: 2026-07-02

This note records a methodology fork discovered while comparing the temporary Gen5.1 live advice bridge against the Gen4 `2026Q2` Phase50 freeze map. The issue is subtle but important: Gen4 and current Gen5.1 can use the same basket, context universe, PCA mode, state grid, and strategy parameter grid, yet still produce materially different state-to-strategy maps because they select winners differently.

This is research/inspection planning only. It is not allocation evidence and it does not approve a live advice change.

## The Hypothesis

Gen4-style pooled family selection may produce more stable state behavior by first choosing the best strategy family for each state from pooled evidence, then choosing asset-specific parameters within that family.

Current Gen5.1 asset-state direct selection may produce more asset-specific edge by choosing the best full strategy spec directly for each asset and state.

The next research question is not "which one made more money once?" It is:

> Under identical data, universe, PCA, state-map, strategy-grid, and replay conditions, does pooled-family-then-asset-variant selection improve robustness versus direct asset-state spec selection?

## Two Competing Selection Policies

### `asset_state_direct_spec`

This is the current Gen5.1 PCA-routed WFA and temporary live bridge policy.

For each asset and state:

1. Fit PCA/state labels on TRAIN only.
2. Simulate every candidate strategy spec for that asset on TRAIN.
3. Assign TRAIN trades to the PCA state active on each entry date.
4. Rank full strategy specs inside the asset/state by TRAIN Sharpe, then TRAIN total return.
5. Select the top full spec, including family, parameters, and exit stack.
6. Force `no_trade` when the TRAIN state has too few rows.

Strengths:

- Allows each asset to express genuinely different behavior in the same state.
- Simple to audit because the selected row is the full executable spec.
- Avoids assuming that one pooled family is best for every asset in a state.

Risks:

- More flexible selection surface can overfit sparse asset/state samples.
- Different assets may disagree on what the same state means.
- State maps can be harder to interpret because family choice and parameter choice are entangled.

### `pooled_family_asset_variant`

This is the Gen4 Phase50 style observed in `phase50_asset_variant_map.csv`.

For each state:

1. Use pooled evidence to choose a strategy family for the state.
2. For each asset, choose the best parameter variant inside that selected family.
3. Freeze the asset/state/family/variant mapping for live use.

Strengths:

- Constrains the model so state labels carry more shared meaning.
- May reduce overfit by pooling the family decision before asset-level calibration.
- Easier to describe: "this state wants mean reversion" or "this state wants trend."

Risks:

- Pooled family choice can wash out real asset-specific differences.
- A weak pooled family decision can force the wrong family onto an asset.
- Requires careful implementation so family selection uses TRAIN-only evidence and does not leak OOS.

## What Triggered This Note

The temporary Gen5.1 bridge was intentionally configured to look Gen4-like:

- Live basket: `AMD,NVDA,PLTR,TSLA,SOFI`
- Context universe: Gen4 `RESEARCH_ASSETS`
- PCA mode: long/pooled asset-day PCA
- State map: `5x5` quantile grid
- Strategy grid: Gen4 `daily_default` implemented subset

Even under those matching surfaces, the selected state maps diverged sharply from Gen4's `2026Q2` freeze map.

Across the five live symbols and 25 states each:

- Exact model matches were only `AMD S5_3 no_trade`, `SOFI S5_3 no_trade`, and `TSLA S5_3 no_trade`.
- Family matched but parameters differed only for `PLTR S2_1`, `SOFI S2_1`, and `TSLA S3_1`.
- Gen4's file explicitly records `selection_mode = pooled_family_asset_variant`.
- Gen5.1 bridge selected full asset/state specs directly.

This difference is enough to explain divergent live signals without implying either architecture is wrong.

## First Paired Screen Result

Implemented and ran the smallest paired screen:

- Screen packet: `runs/research_workbench/selection_policy_screens/selection_policy_screen_A5_Q2Q3_20260702/`
- Script: `scripts/inspect/run_selection_policy_screen.R`
- Visual summary script: `scripts/inspect/run_selection_policy_visual_summary.R`
- Visual summary packet: `runs/research_workbench/selection_policy_screens/selection_policy_screen_A5_Q2Q3_20260702/visual_summary/`
- Replayed windows: `2026Q2_asof_20260630` and `2026Q3_asof_20260701`
- Required authority packets: `2026Q1`, `2026Q2`, and `2026Q3`

Held constant:

- Basket: `AMD,NVDA,PLTR,TSLA,SOFI`
- Context universe: Gen4 `RESEARCH_ASSETS`
- PCA mode: `behavioral_pool` / `pooled_asset_day`
- State map: `5x5` quantile grid
- Strategy grid: Gen4 `daily_default` implemented subset
- Exit policy: current native-only bridge-compatible exits
- Trade ownership: entry-state owns trade until exit
- Replay policy: adjacent-quarter continuity, where previous-quarter authority owns any open prior-quarter trade until flat
- Accounting surface: compact replay/trade inspection only; not allocation evidence

Vary only:

- `asset_state_direct_spec`
- `pooled_family_asset_variant`

Readout:

- Across `2026Q1`, `2026Q2`, and `2026Q3` authority maps, direct and pooled-family policies matched on `321 / 375` asset-state rows, or `85.6%`.
- Match rates by quarter were `85.6%`, `84.0%`, and `87.2%`.
- Even with high map agreement, replay behavior still diverged in visible places because a small number of state-policy changes can alter entries, exits, and quarter-continuity handoff.
- The compact trace-return proxy favored direct selection in the Q2-as-of replay and pooled-family selection in the Q3-as-of replay, with Q3 pooled heavily influenced by AMD's replayed path. Treat this as a follow-up prompt, not a verdict.
- The visual summary makes that concentration visible: Q3 pooled-family's advantage is dominated by AMD, while NVDA and TSLA favored direct in both windows and PLTR was unchanged in this paired screen.

Updated interpretation:

The paired screen reduced the fear that the two policies are radically different under identical Gen5.1 bridge conditions, but it did not eliminate the policy question. The next useful step is a broader paired screen over more quarters/windows, using a fuller portfolio-accounting packet per policy if the operator wants to decide whether `pooled_family_asset_variant` should become a first-class Gen5.1 contender.

## Recommended Next Screen

Run a medium paired screen before changing the live bridge or rerunning large context/state-map batches.

Start with:

- Medium run: add several adjacent quarters from the recent history that the current cache supports cleanly
- Full research rerun only if the paired screen shows a meaningful stability or robustness difference

## Broader Robustness Wrapper

A resumable broader-screen wrapper now exists:

- Script: `scripts/inspect/run_selection_policy_robustness_screen.R`
- Default output root: `runs/research_workbench/selection_policy_screens/selpol_robust_20260702/`
- Optional screen filter: set `GEN5_SELECTION_POLICY_ONLY=A_live` or `GEN5_SELECTION_POLICY_ONLY=B_hist`

It declares two evidence lanes:

1. `A_live`: current live basket `AMD,NVDA,PLTR,TSLA,SOFI` with the Gen4 `RESEARCH_ASSETS` context universe. This is the true live-basket comparison, limited by SOFI/PLTR and newer context-symbol history.
2. `B_hist`: historical substitute basket `AMD,NVDA,TSLA,AAPL,MSTR` with a long-history active-plus-risk context. This is robustness evidence only; it is not a literal live-basket replication.

The wrapper reuses completed authority packets when present and can reuse matching 2026 live-bridge authorities for Screen A. It writes each screen's run spec, taxonomy, authority index, selected-state maps, agreement summary, replay packet index, trade summaries, visual summary graphics, and report.

Interactive compute note:

- A new five-symbol Gen4-like bridge authority evaluates `172` candidate specs per asset before state routing.
- The first new `A_live` authority (`2025Q3`) remained compute-bound for an interactive chat run and was stopped before completion.
- Treat the wrapper as implemented scaffolding, but do not treat the broader robustness result as completed until the authority packets finish and the reports/visual summaries exist.

Recommended operational path:

1. Run `A_live` as a standalone resumable job, preferably when the machine can run for a while.
2. Inspect the completed `A_live` report before starting `B_hist`.
3. Run `B_hist` as a second standalone job only if the live-basket evidence still leaves the policy decision ambiguous.
4. If the broad wrapper remains too slow, add lower-level checkpointing inside per-symbol authority fitting before expanding more windows.

## Outputs To Produce

The comparison wrapper should write:

- Run spec declaring selection policies as the only intended variable.
- Selection-policy taxonomy table.
- Side-by-side selected-state maps.
- State/family coverage and sparsity summary.
- Replay trade ledger per policy.
- Portfolio accounting packet per policy.
- Compact chart/contact-sheet outputs.
- Top-level report with interpretation guardrails.

The report must separate:

- Selection-map agreement and disagreement.
- Stability and coverage evidence.
- Trade behavior and drawdown behavior.
- Portfolio accounting inspection metrics.
- Any live bridge implication.

## Leakage Guardrails

- Pooled family selection must use TRAIN-only evidence.
- Asset parameter selection inside the chosen family must use TRAIN-only evidence.
- OOS replay must consume frozen selected mappings only.
- Portfolio accounting remains a downstream inspection surface, not accepted allocation evidence.
- Do not choose a policy from one quarter's return alone.

## STOP Decisions

The operator should decide:

- Whether Gen5.1 should keep `asset_state_direct_spec` as the default research policy if it performs comparably.
- Whether `pooled_family_asset_variant` should become a first-class Gen5.1 selection policy if it is more stable.
- Whether the temporary live bridge should prioritize Gen4 fidelity or current Gen5.1 research architecture.
- Whether any prior context-universe/state-map results need rerunning under a different selection policy.
