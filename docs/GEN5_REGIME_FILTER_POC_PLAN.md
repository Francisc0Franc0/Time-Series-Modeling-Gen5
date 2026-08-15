# Gen5 Regime Filter POC Plan

Status: PCA quantile-grid, PCA k-means, and PCA-routed WFA Option A POCs implemented; `HYP-REG-01.1` passed as an asset-relative ATR% diagnostic, while its separately frozen `HYP-REG-01.2` low-state momentum overlay failed DEVELOPMENT gates and did not open confirmation; remaining regime methods are planning memory.

This note preserves the current regime/state-model brainstorm so the operator and Codex can return to it across separate POC branches.

## Where This Fits

Gen5.1 currently has a working WFA POC with data loading, charting, multi-fold stitched OOS reporting, a modest signal-family ecosystem, close-based exit stacks, and an inert `no_trade` competitor.

The next regime layer should not replace WFA. WFA remains the anti-leakage authority boundary:

- Each TRAIN fold fits or freezes the regime labeling method.
- Each TRAIN fold evaluates strategy specs within the regime framework.
- Each OOS fold assigns states using only information available through each session close.
- OOS execution uses the fold-frozen state assignment rules and state-conditioned strategy/spec choices.

In other words, folds decide what is known and frozen; states decide which fold-approved behavior is active on a given OOS date.

## Core Design Questions

- What feature panel defines market state?
- Is the state model asset-specific, market-level, or both?
- Which assets should contribute to state context, versus which assets are allowed to be researched, traded, or actively allocated?
- Are states hard labels, probabilities, or both?
- Does WFA choose one strategy spec per state, or does a state only gate risk/no-trade?
- How many states are useful before overfitting and interpretability break down?
- How do we show state labels on charts so the operator can audit them visually?

## Universe Vocabulary

Regime POCs now use these names to keep data expansion separate from trading authority:

- **Regime Context Universe**: assets whose feature panels are allowed to inform state detection. Example: `AMD,NVDA,TSLA`.
- **Research Candidate Universe**: assets whose signal models and strategy specs are evaluated by WFA. Current PCA-routed POC: one symbol only.
- **Tradeable Universe**: assets the system is allowed to place trades in. Current PCA-routed POC: one symbol only.
- **Active Allocation Set**: assets actually held or allocated to at a given point in the replay. Current PCA-routed POC: one symbol only, all-in/flat accounting.

This lets Gen5 test whether broader market/context data improves regime labels without silently becoming pooled optimization, cross-asset parameter selection, or portfolio allocation.

## PCA Panel Modes

Gen5.1 now names two distinct ways to turn a multi-asset Regime Context Universe into PCA training data:

### `date_aligned_context`

This is the first Gen5.1 context design. It creates one row per `session_date` and widens each context asset's features into separate columns, such as `AMD__vol_20`, `NVDA__vol_20`, and `TSLA__vol_20`.

What it means:

- each row is a synchronized market snapshot;
- assets act as same-day regime sensors;
- PCA can learn cross-asset context available on that date;
- OOS routing is naturally one state per traded asset date.

Tradeoff: row count is limited by the number of shared dates, and feature count grows quickly as the context universe expands.

### `pooled_asset_day`

This is the Gen4-style comparison design. It stacks asset-days into one long table with common feature names, such as `vol_20`, `rsi_14`, and `dist_anchor_200`, while keeping `symbol` as row identity.

What it means:

- each row is one asset on one date;
- PCA trains on a larger pool of asset-day observations;
- states describe cross-sectional asset behavior rather than one synchronized market snapshot;
- after PCA scoring, the current WFA POC filters scored states back to the target `-Symbol` before route selection, so OOS trades remain single-asset and date lookup stays unambiguous.

Tradeoff: it increases sample size and mirrors the Gen4 mechanics, but it can blur asset identity if feature normalization is not carefully audited. It also answers a different question than date-aligned context: "what kind of asset-day is this?" rather than "what is the synchronized market context today?"

## PCA Router Workbench Toggles

The operator-facing wrapper `scripts/inspect/run_pca_router_workbench.ps1` keeps the working POCs intact while exposing two clean experiment axes:

- `-PanelMode contextual_snapshot`: same as `date_aligned_context`; asks what same-day multi-asset context surrounds the traded asset.
- `-PanelMode behavioral_pool`: same as `pooled_asset_day`; asks what recurring asset-day behavior type the traded asset resembles.
- `-StateMap quantile_grid`: PC1/PC2 quantile bins; `-StateCount 3` means a 3x3 grid.
- `-StateMap kmeans`: k-means clustering on TRAIN PC1/PC2; `-StateCount 9` means nine clusters.

This creates four direct comparison families without changing the downstream WFA replay contract:

| PanelMode | StateMap | Internal panel | Internal state engine |
|---|---|---|---|
| `contextual_snapshot` | `quantile_grid` | `date_aligned_context` | `quantile_grid` |
| `contextual_snapshot` | `kmeans` | `date_aligned_context` | `pca_kmeans` |
| `behavioral_pool` | `quantile_grid` | `pooled_asset_day` | `quantile_grid` |
| `behavioral_pool` | `kmeans` | `pooled_asset_day` | `pca_kmeans` |

The wrapper is an operator convenience layer only. It delegates to `run_pca_wfa_router_poc.ps1`, which remains the stable implementation runner for the current POC.

## State-Routed Trade Ownership Policies

When a regime/state layer is allowed to route strategy specs, open trades need an explicit ownership policy. Two policies are currently worth preserving:

### Option A: Entry-State Ownership

The state active on the entry signal date selects the complete `strategy_spec_id`. Once the trade opens, that same spec owns native exits and exit-stack management until the trade closes, even if the PCA state changes before exit.

Why this is the first Gen5 POC policy:

- attribution is clean: each trade belongs to one entry state and one complete spec;
- TRAIN evaluation can select specs using trades whose entry signals occurred in that TRAIN state;
- OOS replay is simple to audit because state changes cannot silently replace the trade manager mid-trade;
- it is the conservative baseline before testing more flexible state-adaptive exits.

Risk: it may be slower to react when the market state changes sharply after entry.

### Option B: State-Adaptive Exit Management

The entry state chooses the entry spec, but once a trade is open, the current state can apply its own selected exit/risk authority. This is closer to the Gen4 behavior where open trades were carried through state changes but could be closed by the strategy active in the new state.

Why it remains a later POC:

- it can be a valid institutional design if entry alpha and risk management are intentionally separate layers;
- however, attribution becomes harder because a trade can be entered by one state/spec and exited by another;
- TRAIN evaluation must prove the same handoff behavior without hindsight or post-hoc exit cherry-picking;
- it is easier to overfit because state switching creates a more flexible trade-management surface.

Gen5 should not blend these policies implicitly. Each regime-aware WFA run should report which ownership policy it used.

## Candidate POCs

### 1. Simple Volatility Regime Baseline

Purpose: establish a boring, interpretable benchmark before more clever models.

Possible features:

- trailing realized volatility;
- ATR or normalized true range;
- drawdown from recent high;
- trend slope;
- rolling correlation/breadth proxy if using multiple assets or benchmarks.

Possible state rule:

- TRAIN-period percentile thresholds such as low, medium, and high volatility;
- frozen thresholds applied to OOS;
- optional `no_trade` routing in hostile states.

Why it matters: if a simple frozen percentile rule works about as well as a complex model, it may be preferable.

Implemented diagnostic: [HYP-REG-01.1](GEN5_HYP_REG_01_1_ATR_PERCENT_VOLATILITY_POC_CONTRACT.md)
freezes Wilder ATR(14) as a percentage of close, ranks it against the preceding
252 completed observations, and applies 30/40 and 60/70 hysteresis to create
causal low/medium/high labels. Across 26 assets in 2018-2023, every asset had
higher future normalized range in `HIGH` than `LOW` at 1-, 5-, and 20-session
horizons. Median non-overlapping Spearman association rose from `0.409` at H1
to `0.514` at H20, stronger than both fixed diagnostic comparators. The result
records `DIAGNOSTIC_COMPLETE_STOP_BEFORE_STRATEGY_OVERLAY`: no return, P&L,
Sharpe, drawdown, hit-rate, entry, exit, sizing, leverage, allocation, or
strategy-switching result was calculated, and 2024+ remained sealed. See the
[results](../operator_hypothesis_lab/docs/HYP_REG_01_1_ATR_PERCENT_VOLATILITY_RESULTS.md)
and [evidence deck](../operator_hypothesis_lab/presentations/hyp_reg_01_1_atr_percent_volatility_evidence.pptx).

The separately frozen [HYP-REG-01.2 overlay](GEN5_HYP_REG_01_2_ATR_PERCENT_STRATEGY_OVERLAY_CONTRACT.md)
then applied that accepted state to one unchanged, well-characterized strategy:
fresh daily SMA8/SMA14 entries were skipped only when the causal signal-close
state was `LOW`. Across 144 stock asset-years, median annual return fell from
`8.95%` to `4.44%`; median drawdown improved from `-14.59%` to `-11.85%`, but
median Sharpe fell from `0.642` to `0.485`. Only `9 / 24` stocks improved
six-year compounded return, `0 / 6` years had positive panel-median excess,
and the actual gate ranked at only the `37.5th` percentile of exposure-near
circular-state controls. Record
`STOP_DEVELOPMENT_OVERLAY_GATES_FAILED_CONFIRMATION_NOT_RUN`. The sensor remains
valid; the proposition that `LOW` volatility is a bad entry state for this
strategy does not. See the
[results](../operator_hypothesis_lab/docs/HYP_REG_01_2_ATR_PERCENT_STRATEGY_OVERLAY_RESULTS.md)
and [evidence deck](../operator_hypothesis_lab/presentations/hyp_reg_01_2_atr_percent_strategy_overlay_evidence.pptx).

### 2. PCA Quantile Grid

Purpose: recreate the familiar Gen4 idea in cleaner Gen5 form.

Current Gen5.1 POC: `R/regime_pca_poc.R` and `scripts/inspect/run_pca_regime_poc.ps1` implement a diagnostic-only 3x3 PCA quantile grid. The POC fits PCA center/scale/loadings and PC1/PC2 bin breaks on TRAIN rows only, scores TRAIN and OOS rows with the frozen TRAIN model, extends outer OOS scoring bins to `-Inf/+Inf`, and writes a model contract so the state assignment can be audited. It does not route strategy selection, exits, allocation, leverage, or live advice.

Gen4-style approach:

- compute PCA on a curated feature panel;
- take the first two principal components;
- split PC1 and PC2 into equal-width or quantile-like bins;
- combine the bins into a grid such as 3x3, 4x4, or 5x5 states.

This is worth revisiting as a baseline because it is familiar, visual, and operator-auditable. It is also somewhat crude:

- grid cells can be sparse;
- adjacent cells may not represent meaningfully different regimes;
- PCA signs and rotations can shift across folds;
- bin boundaries are operator choices even if PCA itself is data-driven;
- too many cells can create state-specific overfitting.

Gen5 improvement ideas:

- fit PCA only inside TRAIN and freeze center/scale/loadings for OOS;
- start with 3x3 only, then test 4x4 later if state counts are healthy;
- report per-state sample counts, OOS coverage, return/vol/drawdown, and selected strategy specs;
- plot PC1/PC2 scatter with state colors and OOS points marked separately;
- show state backgrounds on price/equity charts.

Implemented operator artifacts:

- PCA scatter plot with TRAIN/OOS marker differences, state colors, and TRAIN-derived grid lines;
- price chart with colored state bands and dashed TRAIN/OOS boundary;
- scores CSV, model-contract CSV, diagnostics CSV, state-coverage CSV, run-length CSV, and markdown report;
- refreshed-cache smoke command documented in the README.

### 2A. PCA-Routed WFA Option A

Purpose: prove state-aware WFA integration with conservative trade ownership before attempting state-adaptive exits or alternative regime methods.

Current Gen5.1 POC: `R/regime_pca_wfa_poc.R` and `scripts/inspect/run_pca_wfa_router_poc.ps1` implement one-or-more-fold AMD PCA-routed WFA proof runs. Each fold fits a TRAIN-only PCA state engine, selects one complete `strategy_spec_id` per TRAIN state using trades whose entry signals occurred in that state, and replays those frozen fold-local state/spec choices in stitched OOS. Supported state engines are the 3x3 quantile grid and PCA k-means.

The routed WFA POC can now accept `-RegimeContextSymbols`, so state detection can use a wider multi-asset feature panel while WFA still researches and trades only the requested `-Symbol`. Example: `-Symbol AMD -RegimeContextSymbols "AMD,NVDA,TSLA"` builds PCA features from all three assets but emits AMD-only trades and AMD-only stitched OOS charts. Use `-PcaPanelMode date_aligned_context` for the default synchronized wide panel or `-PcaPanelMode pooled_asset_day` for the Gen4-style long panel.

Current policy:

- ownership policy is Option A: `entry_state_owns_trade_until_exit`;
- Regime Context Universe can be multi-asset, but Research Candidate Universe, Tradeable Universe, and Active Allocation Set remain the single target symbol in this POC;
- PCA panel mode is explicit and reported in each run;
- current OOS state can select entries only while flat;
- once a trade opens, the entry-state spec owns native exits and exit-stack management until the trade closes;
- a trade may carry across OOS fold boundaries, but its manager does not change;
- sparse TRAIN states are allowed to route to `no_trade`.

Implemented operator artifacts:

- selected fold/state/spec CSV;
- TRAIN state performance CSV;
- PCA scores and model-contract CSVs;
- stitched OOS trades, equity, and metrics CSVs;
- markdown report;
- state-banded OOS strategy chart with dashed fold boundaries;
- stitched OOS equity curve.

Next unimplemented escalation steps:

- Option B state-adaptive exit management as a separate POC, not a silent change to Option A.
- compare PCA quantile-grid, PCA k-means, a simple volatility percentile baseline, and HMMs as separate isolated POCs before canonizing a regime method.

### 3. PCA Plus Clustering

Purpose: keep PCA as the feature-compression step, but let clustering find state shapes rather than forcing rectangular PC bins.

Implemented Gen5.1 k-means POC:

- `R/regime_pca_poc.R` includes `g5_pca_regime_fit_kmeans()`.
- `scripts/inspect/run_pca_kmeans_regime_poc.ps1` writes a diagnostic-only AMD k-means packet.
- The WFA router can use `-StateEngine pca_kmeans` with `-GridN` interpreted as cluster count.

Possible future clustering methods:

- Gaussian mixture models;
- hierarchical clustering for inspection, not necessarily production.

Advantages over a rectangular grid:

- clusters can follow the data geometry better;
- fewer empty states;
- state count can be selected more deliberately;
- clusters may be more stable than many small PC bins.

Risks:

- cluster labels can permute between folds;
- state meaning may be less transparent than a simple PC1/PC2 grid;
- model selection can become a distraction if we over-tune it.

### 4. Hidden Markov Model

Purpose: model regimes as latent states with transition probabilities.

The model assumes observed features are generated by an unobserved state process. Each state has its own distributional behavior, and the system learns probabilities of moving from one state to another.

For live-like use, Gen5 should prefer filtered state probabilities: given data through today's close, what state are we probably in? Avoid smoothed or full-sample hindsight labels for trading authority because those can use future information.

Potential advantages:

- natural treatment of persistence and regime transition;
- probabilistic labels instead of brittle hard labels;
- can express uncertainty and mixed regimes.

Risks:

- local optima and unstable fits;
- arbitrary state names and label switching across folds;
- too many states can overfit quickly;
- HMMs can look sophisticated while being fragile on short/noisy financial samples.

## Recommended POC Order

1. PCA quantile grid first, because it is the closest Gen4 bridge and the operator already has practical intuition for it.
2. PCA plus clustering second, using the same feature panel and charts, so we compare state geometry without changing every variable at once.
3. Simple volatility percentile baseline either before or alongside PCA, as a reality check.
4. HMM after the feature/reporting surface is stable, because HMM interpretation and validation are more delicate.

This order can change, but each POC should produce concrete operator-facing artifacts before becoming WFA authority.

## Minimum Operator-Facing Artifacts

Each regime POC should produce:

- state-labeled price chart;
- state-labeled equity or benchmark chart;
- state coverage table;
- per-state summary metrics;
- feature/PCA scatter or equivalent state map;
- frozen TRAIN configuration summary;
- explicit statement of whether the output is only diagnostic or is allowed to route WFA strategy selection.

## Stop Gates

Do not wire a regime method into WFA selection until:

- state assignment is frozen from TRAIN and replayed OOS without leakage;
- state labels are visually auditable;
- sparse states are detected and reported;
- state labels are stable enough across folds to interpret;
- the operator accepts the state semantics as useful enough for the next POC.
