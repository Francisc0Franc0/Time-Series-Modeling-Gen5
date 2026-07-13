# Gen5.4 ML Decision Engine Plan

## Purpose

Gen5.4 is a research fork that keeps the Gen5 data, WFA, accounting, charting, and reporting surfaces, but replaces the PCA-state-plus-strategy-routing decision engine with a supervised daily decision engine.

The immediate question is not whether this is a final live trading system. It is whether a supervised model can learn a cleaner daily long/flat policy than the current PCA-routed strategy stack, especially for high-beta bullish participation and risk-off separation.

## Why This Fork Exists

Gen5.3 made useful progress, but it exposed a structural tension:

- PCA states can contain useful exposure information.
- Strategy routing can avoid some downside.
- State-only exposure improves bullish participation.
- The current PCA feature/state surface still overparticipates in some drawdown windows and underparticipates in some explosive rebound windows.

That suggests the next clean question is supervised: given only information available after today's close, should the system want exposure over the next few sessions?

## What Stays Unchanged

- Alpaca adjusted daily OHLCV remains the canonical market-data surface.
- Every run must use explicit `as_of_timestamp` discipline.
- TRAIN/OOS walk-forward boundaries remain leakage-safe.
- The default research cadence remains 8 quarters of TRAIN and 1 quarter of OOS authority.
- Annual assessment windows may stitch consecutive quarterly authorities, with open trades carried until flat, to answer "what would a year of operating this quarterly system have looked like?"
- Portfolio accounting remains an inspection layer, not allocation acceptance.
- Live advice bridge semantics remain frozen and out of scope unless explicitly opened.

## What Changes

The current PCA path is:

```text
OHLCV -> engineered features -> PCA state -> state-local strategy/parameter selection -> OOS replay
```

The Gen5.4 ML path is:

```text
OHLCV -> engineered features -> supervised model -> daily long/flat probability or score -> OOS replay
```

The first ML proof should not remove PCA artifacts from the repo. It should create a parallel research lane so PCA and ML can be compared under the same WFA/accounting standards.

## OHLCV Versus Close-To-Close

OHLCV should be the primary ML surface. Close-to-close returns are a useful baseline or negative control, but they throw away information that matters for daily execution.

Important OHLCV information:

- `open`: aligns next-open execution and labels with how the system actually trades.
- `high` and `low`: support range, wick, intraday stress, ATR, compression/expansion, and adverse/favorable excursion features.
- `close`: captures the final daily mark available when after-close advice is generated.
- `volume`: adds participation, liquidity, and attention information.

For an after-close system, the cleanest feature convention is: features at session `t` may use OHLCV through the close of `t`; any entry/exit action is executed at the next open.

## Starting Feature Surface

The existing PCA feature sets are good enough for a minimal POC because they already encode trend, volatility, stretch, range location, drawdown, recovery, chop, efficiency, and return-shape concepts:

- `workhorse_enriched`
- `momentum_participation`
- `momentum_plus_stress`
- `market_relative_momentum`
- `reversion_breakout_context`

However, they were designed for unsupervised PCA, not supervised prediction. Gen5.4 should start with those ideas, then add explicit OHLCV and execution-aligned features.

Recommended first ML feature set:

- recent returns: `ret_1`, `ret_3`, `ret_5`, `ret_10`, `ret_20`, `ret_60`;
- trend: EMA gaps, trend slopes, price distance from 50/200-day anchors;
- range and candle structure: high-low range, open-close body, upper/lower wick fractions, close location in daily and rolling range;
- volatility and compression: ATR percent, rolling volatility, Bollinger width, range compression/expansion;
- participation: volume z-score, relative volume, dollar-volume proxy;
- drawdown/recovery: rolling drawdown, recovery from rolling low;
- market-relative context: asset return minus SPY/QQQ/SMH or another declared context proxy over selected horizons.

## Labels And Execution Alignment

The first labels should be simple and explicitly tied to next-open tradability.

Default first label:

```text
fwd_ret_h3 = close[t + 3] / open[t + 1] - 1
label_up_h3 = fwd_ret_h3 > threshold
```

Why `h3` first:

- one-day labels are very noisy;
- three-session labels still represent short tactical behavior;
- the label naturally matches "enter next open, reassess every day";
- it gives the model a small amount of smoothing without becoming a slow swing model.

Useful later comparators:

- `h1`: next-open to next-close;
- `h5`: next-open to five sessions later;
- thresholded or cost-buffered labels;
- triple-barrier labels using profit target, stop threshold, and max holding period.

Rows near fold ends that cannot support the forward label must be dropped or marked unusable. No OOS row may influence TRAIN labels, model fitting, threshold selection, scaling, imputation, or feature ranking.

## First Model Lanes

Start with a no-new-dependency lane:

- `glm_logit_h3`: logistic regression baseline for plumbing, leakage audits, and interpretability.

Then add the first approved dependency lane:

- `xgboost_h3`: gradient-boosted trees for nonlinear interactions, threshold effects, and feature interactions.

The GLM lane is not expected to be the best final trader. It is the sanity-check instrument: if GLM plumbing, labels, and replay are wrong, XGBoost will only make the mistake harder to see.

## Daily Policy

The first daily policy should be deliberately boring:

```text
At close t:
  compute features using data through t
  predict probability of positive h3 forward return

At next open t + 1:
  if flat and p_up >= enter_threshold: enter long
  if long and p_up < exit_threshold: exit long
  otherwise: hold current state
```

Use hysteresis by default: `enter_threshold` should be higher than `exit_threshold`. This reduces churn and avoids treating tiny probability changes as tradeable information.

For the first POC, thresholds should either be fixed before the run or selected only inside TRAIN with an explicit rule. Never tune thresholds on OOS performance.

## Leakage Guardrails

- All features at date `t` use only bars through date `t`.
- All labels use future prices only for label construction inside the appropriate TRAIN window.
- Feature scaling, imputation, filtering, model fitting, and threshold selection are fit on TRAIN only.
- OOS predictions use frozen TRAIN transforms and frozen TRAIN model objects.
- Annual summaries stitch quarterly OOS replays but do not refit using prior OOS outcomes.
- Context-symbol features must be date-aligned and available as of the same session close.
- Any row with insufficient future data for the label is not eligible for model fitting.
- Performance remains research/inspection evidence only.

## Artifact Contract

The first Gen5.4 packets should produce:

- run spec;
- feature schema and feature taxonomy;
- feature/label table sample;
- label distribution by symbol, fold, and window;
- leakage audit;
- model training summary;
- OOS prediction table;
- daily action table;
- portfolio/accounting packet;
- benchmark comparison summary;
- representative trade tapes with prediction/state overlays where practical;
- compact report or slide-deck section explaining the question, setup, and readout.

## Staged Plan

### ML-P0: Feature/Label Proof

Build the feature-label table and audit it. Do not fit a model yet.

Default minimal scope:

- live basket: `AMD,NVDA,TSLA,MSTR,AVGO`;
- context proxies: risk-aware high-beta plus market/sector proxies already used in Gen5.3;
- windows: `2020` and `2022` first;
- label: `h3` next-open to close three sessions later;
- output: schema, label distributions, leakage audit, feature coverage, and a compact report.

Pass condition: the feature/label table is deterministic, date-aligned, and leakage-safe.

### ML-P1: GLM Daily Replay

Fit `glm_logit_h3` per fold, generate OOS predictions, apply a fixed or TRAIN-selected threshold, and replay long/flat decisions through the existing accounting surface.

Pass condition: the no-dependency model lane produces interpretable OOS predictions, actions, equity, and trade tapes under the same benchmark discipline as Gen5.3.

### ML-P2: XGBoost Challenger

Install and add `xgboost` after ML-P0/ML-P1 prove the data and replay surface. Compare the nonlinear model against GLM and equal-weight basket hold.

Pass condition: XGBoost improves decision quality without requiring OOS threshold tuning or opaque leakage-prone feature handling.

### ML-P3: Annual Continuity Screen

Run the best GLM/XGBoost settings over several annual assessment windows using quarterly authorities and continuity replay.

Pass condition: the model is evaluated across different market conditions, not just one favorable high-beta rally.

## First Implementation Step

The first implementation step is ML-P0: create a feature/label proof wrapper.

This should avoid new package installation until the data surface is proven. It should answer:

- Can we build the supervised feature table from adjusted daily OHLCV?
- Are labels aligned to next-open execution?
- Do the labels have enough positive and negative examples by symbol/window?
- Are the current PCA-inspired features sufficient to start, and where do OHLCV-specific additions help?

Only after ML-P0 passes should we add model-fitting dependencies.

## ML-P0 Packet

The first ML-P0 packet is:

`runs/research_workbench/gen54_ml_decision_engine/g54_ml_p0_20260713p0/`

The companion deck is:

`presentations/gen5_4_ml_decision_engine_incremental_build.pptx`

Readout:

- The wrapper produced `22,440` usable labeled fold rows over `AMD,NVDA,TSLA,MSTR,AVGO`.
- It used `40` selected features seeded by the PCA feature surface and supplemented with OHLCV/execution-aligned features.
- All leakage checks passed: feature date precedes execution date, execution precedes label endpoint, TRAIN labels end inside TRAIN, and OOS labels end inside OOS.
- Usable rows had `100%` finite selected-feature coverage after eligibility filters.
- The deck now documents the incremental build process and the visuals that demonstrate table quality: fold calendar, feature coverage, label balance, forward-return distributions, alignment example, feature behavior strips, and univariate decile audit.

This is not model evidence yet. It only proves that the supervised table is coherent enough to support ML-P1.

## STOP Decisions

The operator owns these decisions before promotion beyond POC:

- whether Gen5.4 becomes a primary research branch or stays a side experiment;
- whether the first production-style ML model should be per-symbol, pooled across symbols, or hybrid;
- whether labels should target `h1`, `h3`, `h5`, or triple-barrier outcomes;
- whether thresholds should be fixed, TRAIN-selected, or calibrated by symbol;
- whether ML should eventually replace PCA routing or coexist as another lane;
- whether any future ML output may influence live advice.
