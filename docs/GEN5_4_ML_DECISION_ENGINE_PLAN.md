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

## ML-P1 Packet

The first ML-P1 packet is:

`runs/research_workbench/gen54_ml_decision_engine/g54_ml_p1_20260713p1/`

The companion deck remains:

`presentations/gen5_4_ml_decision_engine_incremental_build.pptx`

Readout:

- The wrapper fit `glm_logit_h3_fixed_threshold` models fold-by-fold using TRAIN rows only.
- The replay used fixed thresholds: enter long at `p >= 0.55`, exit long at `p < 0.50`.
- All ML-P1 guardrail checks passed: TRAIN-only fitting, OOS-only prediction/replay, fixed thresholds, and no live bridge change.
- The GLM replay returned `8.0%` in `2020Y` versus `214.0%` equal-weight basket hold, with `27.6%` mean exposure.
- The GLM replay returned `-42.4%` in `2022Y` versus `-54.2%` equal-weight basket hold, with `59.9%` mean exposure.
- Interpretation: ML-P1 proves the model/replay plumbing and creates useful probability/action/trade-tape diagnostics, but the fixed-threshold GLM is defensive/selective rather than a rally-participation solution.

The next narrow slice should improve the decision policy before adding model complexity: compare fixed thresholds against TRAIN-only threshold selection or calibration, while keeping GLM interpretability and probability trade tapes.

## ML-P1b Packet

The first ML-P1b packet is:

`runs/research_workbench/gen54_ml_decision_engine/g54_ml_p1b_20260713p1b/`

The companion deck remains:

`presentations/gen5_4_ml_decision_engine_incremental_build.pptx`

Readout:

- The wrapper kept the ML-P1 GLM model contract fixed and compared three threshold policies: fixed `0.55 / 0.50`, TRAIN prediction quantiles `p60 / p45`, and a TRAIN forward-return grid.
- All ML-P1b guardrail checks passed: TRAIN-only fitting, TRAIN-only policy selection, OOS-only replay, no OOS threshold tuning, and no live bridge change.
- The fixed policy exactly reproduced ML-P1: `8.0%` in `2020Y` versus `214.0%` basket hold, and `-42.4%` in `2022Y` versus `-54.2%` basket hold.
- The TRAIN quantile policy was more defensive: `5.3%` in `2020Y` and `-39.5%` in `2022Y`.
- The TRAIN forward-return grid improved 2020 participation and return: `30.0%` in `2020Y` with `34.8%` mean exposure, versus fixed-policy `8.0%` with `27.6%` exposure. It still lagged basket hold by `-184.0 pp`.
- The same grid weakened 2022 defense: `-48.4%` with `67.4%` exposure, versus fixed-policy `-42.4%` with `59.9%` exposure.
- Interpretation: threshold policy matters, but lowering or selecting thresholds does not solve the main alpha gap. The model's probability ranking still misses too much early rally participation.

The next narrow slice should test probability quality rather than simply increasing exposure. Good candidates are label-horizon comparison, probability calibration, or a small nonlinear challenger judged against the same continuous replay and probability-tape surface.

## ML-P1c Packet

The first ML-P1c packet is:

`runs/research_workbench/gen54_ml_decision_engine/g54_ml_p1c_20260713p1c/`

The companion deck remains:

`presentations/gen5_4_ml_decision_engine_incremental_build.pptx`

Readout:

- The wrapper kept the ML-P1b GLM, feature set, TRAIN-only policy selection surface, and continuous annual replay fixed while comparing `h1`, `h3`, and `h5` next-open labels.
- All ML-P1c guardrail checks passed: TRAIN-only fitting, TRAIN-only threshold selection, OOS-only replay, no OOS threshold tuning, and no live bridge change.
- Under the TRAIN forward-return grid, `h1` was the strongest 2020 label: `54.0%` active return versus `225.2%` basket hold, with `43.0%` mean exposure.
- The same policy returned `30.0%` for `h3` versus `214.0%` basket hold, and `9.6%` for `h5` versus `205.2%` basket hold.
- In `2022Y`, all three horizons beat the falling basket modestly in absolute terms, but still had large losses: `h1` returned `-49.7%` versus `-53.3%`, `h3` returned `-48.4%` versus `-54.2%`, and `h5` returned `-42.4%` versus `-51.9%`.
- The ranking audit was weak. The best AUC was only `0.520` for `2020Y h1`; the other horizon/window pairs were below `0.50` or close to random. Top-minus-bottom decile forward-return separation was inconsistent.
- Interpretation: `h1` is the best GLM label horizon so far, and it improves participation, but the remaining obstacle is probability ranking quality. This is no longer mainly a threshold or label-horizon problem.

## GLM Optimization Boundary Before XGBoost

The useful GLM stage has now answered the plumbing questions it was meant to answer:

- `ML-P0`: adjusted daily OHLCV features and labels can be built deterministically and leakage-safely.
- `ML-P1`: fold-local GLM prediction and continuous OOS replay work.
- `ML-P1b`: TRAIN-only threshold selection matters, but more permissive thresholds do not close the rally-participation gap.
- `ML-P1c`: `h1` is the strongest GLM label horizon so far, but probability ranking remains weak.

Do not keep broadening GLM-only knobs from here. One narrow calibration sanity check is acceptable only if it answers a specific diagnostic question. Otherwise, the next learning step should be `ML-P2`: an XGBoost challenger using the same leakage-safe feature table, `h1` label, continuous annual replay, threshold-policy audit, equity-versus-basket benchmark, ranking diagnostics, and probability trade tapes.

If XGBoost cannot materially improve probability ranking, timing, or benchmark-relative replay behavior, backtrack to feature design rather than adding more model knobs.

## ML-P2 Packet

The first ML-P2 packet is:

`runs/research_workbench/gen54_ml_decision_engine/g54_ml_p2_20260713p2/`

The companion deck remains:

`presentations/gen5_4_ml_decision_engine_incremental_build.pptx`

Readout:

- The wrapper kept the `h1` label, feature table, annual continuous replay, TRAIN-only threshold-policy audit, equity-versus-basket benchmark, ranking diagnostics, and probability tapes fixed.
- The only decision-engine change was model class: `glm_logit_h1_train_grid` versus a conservative predeclared `xgboost_h1_fixed_params`.
- XGBoost parameters were fixed before OOS replay: `nrounds=80`, `max_depth=3`, `eta=0.05`, `subsample=0.80`, `colsample_bytree=0.80`, and `min_child_weight=10`.
- All ML-P2 guardrail checks passed: TRAIN-only fitting, predeclared XGBoost parameters, TRAIN-only policy selection, OOS-only replay, label-horizon boundary filtering, and no live bridge change.
- Under the TRAIN forward-return grid, seeded XGBoost improved `2020Y` active return to `108.9%` versus GLM `54.0%`, with similar mean exposure (`42.3%` versus `43.0%`). Basket hold was still much higher at `225.2%`.
- In `2022Y`, seeded XGBoost improved defense to `-37.8%` versus GLM `-49.7%`; basket hold was `-53.3%`.
- The ranking audit remained mixed. XGBoost's `2020Y` AUC was `0.510` versus GLM `0.520`, and `2022Y` AUC was `0.478`. Replay improvement may come from threshold-crossing timing, drawdown behavior, or localized pockets rather than cleaner global probability ranking.
- XGBoost feature importance highlighted OHLCV structure and context features, including `intraday_oc_ret`, `gap_open_pct`, `ret1`, `atr_compression_20`, `lower_wick_pct`, `ret_3`, `efficiency_ratio_20`, `volume_z20`, and market-relative returns. Treat this as a diagnostic, not causal evidence.
- Interpretation: ML-P2 earned one cautious follow-up because replay improved in both tested windows without OOS parameter tuning. It did not earn a broad XGBoost search. The next slice should be a small TRAIN-only parameter diagnostic, keeping labels, features, replay, thresholds, benchmarks, and probability tapes fixed.

## ML-P2b Packet

The first ML-P2b packet is:

`runs/research_workbench/gen54_ml_decision_engine/g54_ml_p2b_20260713p2b/`

The companion deck remains:

`presentations/gen5_4_ml_decision_engine_incremental_build.pptx`

Readout:

- The wrapper kept the ML-P2 surface fixed: `h1` label, current OHLCV/context feature table, annual continuous replay, TRAIN-only threshold-policy audit, equal-weight basket benchmark, ranking diagnostics, and probability tapes.
- It compared the fixed ML-P2 XGBoost control against a small TRAIN-only grid over `max_depth = 2,3,4`, `nrounds = 60,100`, and `min_child_weight = 5,10,20`.
- Parameters were selected only from TRAIN proxy evidence inside each fold; OOS rows were used only for frozen-model prediction and replay inspection.
- All guardrail checks passed: TRAIN-only fitting, TRAIN-only parameter selection, TRAIN-only threshold-policy selection, OOS-only replay, label-boundary filtering, and no live bridge change.
- The TRAIN selector chose the same aggressive candidate in every tested fold: `max_depth=4`, `nrounds=100`, `min_child_weight=5`.
- Under the TRAIN forward-return grid, fixed seeded XGBoost returned `108.9%` in `2020Y` and `-37.8%` in `2022Y`. The TRAIN-selected parameter grid returned `78.1%` in `2020Y` and `-41.7%` in `2022Y`.
- Ranking quality did not improve enough to justify the extra tuning surface: selected-grid `2020Y` AUC was `0.489` versus fixed XGBoost `0.510`; selected-grid `2022Y` AUC was `0.481`, but top-minus-bottom forward-return separation remained negative.
- Interpretation: ML-P2b answers the narrow tuning question. The current bottleneck is unlikely to be that fixed XGBoost was too constrained. The next high-signal slice should target feature/label design or a specific calibration question, not broader model-knob search.

## STOP Decisions

The operator owns these decisions before promotion beyond POC:

- whether Gen5.4 becomes a primary research branch or stays a side experiment;
- whether the first production-style ML model should be per-symbol, pooled across symbols, or hybrid;
- whether labels should target `h1`, `h3`, `h5`, or triple-barrier outcomes;
- whether thresholds should be fixed, TRAIN-selected, or calibrated by symbol;
- whether ML should eventually replace PCA routing or coexist as another lane;
- whether any future ML output may influence live advice.
