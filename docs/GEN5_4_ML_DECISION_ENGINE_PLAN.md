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

## ML-P3 Packet

The first ML-P3 packet is:

`runs/research_workbench/gen54_ml_decision_engine/g54_ml_p3_features_20260713p3features/`

The companion deck remains:

`presentations/gen5_4_ml_decision_engine_incremental_build.pptx`

Readout:

- The wrapper kept the seeded XGBoost model, `h1` label, annual continuous replay, TRAIN-only threshold-policy audit, equal-weight basket benchmark, ranking diagnostics, and probability tapes fixed.
- The experimental axis was feature-set membership: `asset_only_control`, `asset_plus_market_context`, `asset_plus_relative_strength`, and `full_context_compact`.
- `asset_only_control` used `37` asset-tape features. `asset_plus_market_context` used `73` features by adding compact SPY/QQQ/SMH context trend, volatility, drawdown, range-location, and breadth features. `asset_plus_relative_strength` used `40` features by adding the existing asset-minus-context relative-return features. `full_context_compact` used `76` features by combining direct context and relative strength.
- All guardrail checks passed: TRAIN-only fitting, fixed seeded XGBoost parameters, TRAIN-only threshold-policy selection, OOS-only replay, label-boundary filtering, fixed feature-set experimental axis, and no live bridge change.
- Under the TRAIN forward-return grid, `asset_plus_relative_strength` led `2020Y` replay at `108.9%` versus `225.2%` basket hold. `asset_only_control` returned `81.1%`, `asset_plus_market_context` returned `49.3%`, and `full_context_compact` returned `51.9%`.
- In `2022Y`, `asset_only_control` was the best defender at `-33.2%` versus `-53.3%` basket hold. `asset_plus_relative_strength` returned `-37.8%`, `full_context_compact` returned `-41.6%`, and `asset_plus_market_context` returned `-43.2%`.
- Ranking was nuanced. Direct/full context improved `2020Y` AUC modestly (`full_context_compact` `0.530`; `asset_plus_market_context` `0.525`) versus relative strength (`0.510`), but did not improve replay. In `2022Y`, every feature set had AUC below `0.50`, and top-minus-bottom decile forward-return separation remained negative.
- Interpretation: more context columns are not automatically better. Relative strength remains the strongest replay control, while asset-only is the best defensive control in this first slice. The next feature-engineering slice should test context components one family at a time or investigate calibration/threshold behavior, rather than broadening the feature surface further.

## ML-P4 Packet

The first ML-P4 packet is:

`runs/research_workbench/gen54_ml_decision_engine/g54_ml_p4_horizons_20260713p4horizons/`

The companion deck remains:

`presentations/gen5_4_ml_decision_engine_incremental_build.pptx`

Readout:

- The wrapper reran the validated ML-P3 feature-set surface for `h1`, `h5`, and `h10` labels, then stitched the child packets into one parent report.
- The replay policy intentionally stayed as daily rescore. This isolates the label-horizon effect before testing a minimum-hold rule.
- All parent guardrails passed: child guardrails all passed, label horizon was the parent experimental axis, daily rescore policy stayed fixed, and live bridge behavior was untouched.
- In `2020Y`, the best replay remained `h1 + asset_plus_relative_strength`: `108.9%` active return versus `225.2%` basket hold. `h5 + asset_plus_relative_strength` returned `61.9%`; `h10 + asset_plus_relative_strength` returned `50.8%`.
- In `2022Y`, `h10 + asset_only_control` defended best in active-return terms at `-28.6%` versus `-48.0%` basket hold. `h1 + asset_only_control` returned `-33.2%` versus `-53.3%` basket hold.
- Longer horizons improved some 2022 ranking diagnostics: `h10 + asset_plus_relative_strength` AUC was `0.552`, and `h10 + asset_only_control` AUC was `0.551`. But in `2020Y`, `h10` ranking was poor for the asset-only and relative-strength lanes, and longer labels did not improve the main upside-capture replay.
- Interpretation: longer labels are not simply higher-conviction versions of `h1`; they change the question. They may help risk-off/defensive separation, but under daily rescore replay they do not solve high-beta bull-window participation. Keep `h1 + asset_plus_relative_strength` as the bullish control. If longer labels are revisited, pair `h5`/`h10` with an explicit minimum-hold replay rule or test benchmark-relative forward-return labels.

## ML-P5 Packet

The first ML-P5 packet is:

`runs/research_workbench/gen54_ml_decision_engine/g54_ml_p5_universe_20260714p5universe/`

The companion deck remains:

`presentations/gen5_4_ml_decision_engine_incremental_build.pptx`

Readout:

- The wrapper held the seeded XGBoost model class, `h1` label, daily-rescore replay, TRAIN-only threshold-policy selection, annual stitched windows, equal-weight basket benchmarks, ranking diagnostics, and probability tapes fixed.
- The experimental axis was universe architecture: live basket archetype, research pool size, and context breadth. Conditions included high-beta, market/ETF, defensive-quality, SPY-only, broad-pool-transfer, and broad-pool-traded variants.
- A smoke-test fix made the shared XGBoost helper support single-symbol research/replay matrices, so `spy_single` conditions can run without a dummy symbol factor.
- The wrapper also added declared-context aggregate features for broader context universes, so `core_risk_context` and `broad_diverse_context` are represented by more than the fixed SPY/QQQ/SMH proxy columns.
- All leakage checks passed: TRAIN-only fitting, TRAIN-only threshold-policy selection, OOS replay restricted to the declared live basket, label-horizon boundary filtering, universe-axis isolation, and no live bridge change.
- Across the primary TRAIN forward-return policy, the system still looked more like a risk-off timing filter than a high-beta alpha engine. Mean excess return was positive in `2022Y` (`+4.8 pp`) but negative in `2020Y` (`-40.5 pp`), `2021Y` (`-10.0 pp`), `2023Y` (`-32.5 pp`), and `2024Y` (`-19.7 pp`).
- Broad-pool transfer was the most interesting universe mode, especially for 2022 defense and SPY/ETF timing pockets. The strongest row was `2022Y high_beta_5__broad_pool_transfer asset_plus_relative_strength`, which lost less than the high-beta basket (`-27.1%` active versus `-58.7%` benchmark; `+31.6 pp` excess).
- Trading the broad pool itself did not solve the alpha problem. `broad_pool_traded__broad_pool_traded` averaged `-15.3 pp` excess return across windows and feature sets.
- Feature-set averages did not produce a global winner: `asset_only_control` was least negative on mean excess, while context and relative-strength variants had useful pockets but did not rescue the screen globally.
- Interpretation: universe architecture matters, but simply adding symbols or context is not sufficient. The next high-signal slice should target the objective itself: benchmark-relative labels, upside-capture labels, or a similarly explicit alpha objective, while keeping `h1 + asset_plus_relative_strength` as the bullish control.

## ML-P6 Swing-Trade Target and Feature Audit

The first ML-P6 packet is:

`runs/research_workbench/gen54_ml_decision_engine/g54_ml_p6_swing_20260714p6swing/`

The companion deck remains:

`presentations/gen5_4_ml_decision_engine_incremental_build.pptx`

Readout:

- ML-P6 is a research-only diagnostic packet. It does not fit, optimize, select, or replay a model.
- It keeps the Gen5.4 data contract intact: adjusted daily OHLCV, after-close feature observation, hypothetical next-open entry, eight-quarter TRAIN, independent quarterly authorities, annual windows, and no live-bridge interaction.
- The primary target candidate is `relative_context_return_h10`: asset next-open to h10 return minus the equal-weight h10 return of `SPY,QQQ,SMH`. Supporting diagnostics are absolute h10 return, an upside-minus-adverse-excursion quality score, and a `+8% before -5%` path label.
- The audit covered `AMD,NVDA,TSLA,MSTR,AVGO` against a 17-symbol risk-aware context universe over `2020Y` through `2024Y`, with 34 declared finite features in four families: leadership, trend health, constructive pullback, and risk-on confirmation.
- All guardrails passed: feature date before next-open execution, label horizon within TRAIN/OOS boundaries, finite label rows, complete declared features, fold-local TRAIN-only feature diagnostics, and live bridge unchanged.
- Individual univariate relationships are modest, as expected for a noisy swing-trading problem. The strongest median TRAIN-fold relationship to relative h10 return was 21-day semiconductor-relative strength (`swing_rs_smh_21`, Spearman `0.063`). Semiconductor-relative leadership, breakout posture, controlled range compression, and trend consistency are plausible ingredients, not promoted features.
- The appropriate next slice is a predeclared compact-feature model comparison: absolute `h1` remains the existing bullish-participation control, while relative `h10` is the alpha-objective challenger. Keep seeded XGBoost, TRAIN-only policy selection, annual continuity replay, benchmark comparisons, calibration/ranking diagnostics, and probability/trade tapes fixed.

## ML-P7 Compact Swing Target x Feature Screen

The merged packet is `runs/research_workbench/gen54_ml_decision_engine/g54_ml_p7_swing_2020_2024_merged/`.

ML-P7 held the seeded XGBoost/replay/policy surface fixed and compared a predeclared 2x2: absolute `h1` versus benchmark-relative `h10`, crossed with the established relative-control feature set versus a 12-feature compact swing set. The result does not support promotion: all four lanes had negative mean OOS excess return. The least negative was `relative_h10 + existing_relative_control` (`-6.2 pp` mean excess); the other lanes ranged from `-6.6 pp` to `-9.4 pp`.

The window pattern matters. Every lane defended the falling 2022 basket, with `relative_h10 + existing_relative_control` best at `+9.1 pp` excess, but all missed substantial upside in 2020, 2021, 2023, and 2024. Ranking was weak: the two absolute-h1 lanes averaged AUC near `0.51`, while relative-h10 existing-control averaged `0.491` with negative top-minus-bottom target separation. This is diagnostic evidence, not allocation evidence. The next action is a qualitative/quantitative audit of exposure, calibration, selection, and representative trade tapes, not another target or model-parameter search.

## Cross-Sectional Asset-Selection Pivot

The theory-first discussion opened a different research question from the
earlier narrow-basket exposure studies: at a historical close, can a diverse,
point-in-time eligible panel rank which assets are more likely to outperform
their contemporaneous opportunity set?

The accepted minimal architecture separates broad exposure permission from
cross-sectional asset ranking. Relative leadership is not automatically a long
entry because the best-ranked asset may still lose money in a falling market.

The frozen X0/X1 panel contains 24 stocks across six economic groups and six
context-only ETFs. Features use close-t adjusted daily OHLCV, hypothetical
execution is next open, and the primary h5 target is relative to the same-date
equal-weight eligible candidate universe. Candidate identities are fixed for
this POC, while daily price, trailing-liquidity, completeness, and
minimum-cross-section eligibility are point-in-time. The fixed panel has an
explicit survivor limitation and cannot support prospective universe-discovery
claims.

The gated sequence is:

1. X0 universe and timestamp integrity;
2. X1 no-model primitive measurement;
3. X2 pooled regularized linear ranker;
4. X3 constrained nonlinear challenger;
5. X4 exposure, top-K, cost, and concentration policy;
6. X5 untouched forward confirmation.

X0 passed. X1 stopped before model fitting because only group-relative
20-session momentum cleared every frozen IC, ordering, fold-stability, and
concentration gate. Sixty-session momentum showed stronger raw ordering but
failed the 50% economic-group concentration cap. The other primitives did not
provide stable independent positive ordering. The ladder requires at least two
economically distinct primitives before X2, so model fitting remains closed.

The detailed contract and evidence are in
`docs/GEN5_4_CROSS_SECTIONAL_ASSET_SELECTION_POC_PLAN.md` and
`runs/research_workbench/gen54_ml_decision_engine/g54_xs_20260719x0x1/`.

The next information-family gate now favors point-in-time earnings and filed
fundamentals. SEC EDGAR submissions and XBRL facts are the recommended authority
for a research-only five-company feasibility sample because filing accessions
and acceptance metadata permit an as-known reconstruction. The operator opened
that narrow provider gate, but the first official SEC request and a direct
header check both returned Akamai HTTP 403 from the execution environment. No
payload entered research authority. This remains a provider-access problem, not
a model gate: F0 must not compute outcomes or predictive relationships. See
`docs/GEN5_4_POINT_IN_TIME_FUNDAMENTALS_ADMISSION_GATE.md`.

## OHLCV X1b And C0 Readout

While SEC access remained blocked, a bounded OHLCV-only extension tested a
second ranking surface and the separately required exposure-permission layer.
It did not fit a model or construct a selection policy.

X1b used rolling 126-session market and leave-one-out group regressions to
produce one-step residual returns, then tested residual momentum, residual
reversal, signed trend efficiency, and intraday-minus-overnight structure. Each
candidate also had to remain below `0.70` median absolute daily rank correlation
with the earlier group-relative momentum primitive.

Intraday-minus-overnight 20-session structure passed every frozen gate: pooled
rank IC `0.0056`, positive IC and top-bottom ordering in `12 / 20` folds,
`+8.2 bp` pooled top-minus-bottom relative h5 outcome, `47.6%` maximum group
share, and `0.22` redundancy correlation. Signed efficiency was stronger in raw
IC and ordering but failed the group-concentration cap at `51.2%`.

C0 used fold-local TRAIN medians to test higher breadth, higher group
participation, lower average correlation, and lower cross-sectional dispersion
against absolute equal-weight h5 outcomes. All four failed. The first three had
large negative pooled separation and only `2-3 / 20` positive folds; low
dispersion remained negative with `9 / 20`.

Overall status is `STOP_BEFORE_TWO_STAGE_RULES_DESIGN`. The ranking surface now
has two distinct research primitives when group-relative momentum is included,
but no accepted price-only exposure-permission condition. Do not drop C0 or
reinterpret ranking quality as permission to hold long risk.

## C1 Risk-Forecasting Readout

C1 separated alpha from risk. Rather than asking OHLCV internals to forecast the
sign of the next basket return, it tested whether four stress measurements could
order the forward realized volatility of an executable equal-weight reference
basket over both `h5` and `h20` open-to-open horizons.

Every fold froze its high-stress threshold at the preceding eight-quarter TRAIN
median. A feature had to show positive mean rank correlation and high-minus-low
risk separation, at least `12 / 20` positive-correlation folds, at least
`12 / 20` positive-separation folds, and a nondegenerate high-state share at
both horizons. No model, scaler, return replay, allocation, or live output was
created.

The first render exposed a definition mismatch: X1's 20-name minimum blanked
most of 2023Q3 even though 18-19 names were individually eligible. Before
interpretation, C1 froze a separate 18-of-24 minimum for the risk reference
basket. Only the corrected `g54_xs_c1_risk_20260719v2` packet is authority.

SPY drawdown from its trailing 126-session high passed `h5`: `18 / 20` positive
correlation folds, `12 / 20` positive separation folds, mean rank correlation
`0.244`, and annualized realized-volatility separation `+0.082`. It failed
`h20` with `9 / 20`, `7 / 20`, and mean correlation `0.002`. Trailing basket
volatility, SPY downside volatility, and average correlation did not pass either
horizon under the full gate.

Overall status is `STOP_BEFORE_RISK_SCALER_DESIGN`. The short-horizon drawdown
result is retained as theory evidence, but it does not authorize deleting the
agreed `h20` requirement, choosing a volatility target, or replaying a scaler.

## C2 Option-Implied Risk Readout

C2 tested one predeclared non-OHLCV input: the official Cboe VIX close. The
existing Alpaca stock-bars path returned no VIX rows in a live feasibility
check. It did return `VIXY`, but that futures-ETF product was rejected because
it changes the economic hypothesis. Cboe was therefore added only as an
isolated research provider; Alpaca remains canonical for adjusted daily OHLCV.

The accepted Cboe sample contained 1,780 observations from 2018-01-02 through
2024-12-31 and joined every evaluation session without filling. The audit reused
C1's executable basket labels, 20 quarterly OOS folds, eight-quarter TRAIN
windows, and h5/h20 horizons. A TRAIN median defined the frozen high-VIX state.
Partial rank correlation controlling for SPY drawdown was predeclared as the
incremental-information check.

VIX passed continuous ordering at both horizons. Mean direct correlation was
`0.272` at h5 and `0.131` at h20, with `15 / 20` and `12 / 20` positive folds.
Mean partial correlation was `0.155` and `0.220`, with `15 / 20` positive folds
at each horizon. VIX therefore contributes risk information beyond SPY
drawdown.

The TRAIN-median state failed: high-minus-low risk separation was positive in
only `10 / 20` h5 folds and `8 / 20` h20 folds. Overall status is
`STOP_THRESHOLD_INSTABILITY`. This is a measurement success but a policy-gate
failure. Do not search a threshold or monotone mapping on the same OOS folds.

## STOP Decisions

The operator owns these decisions before promotion beyond POC:

- whether Gen5.4 becomes a primary research branch or stays a side experiment;
- whether the first production-style ML model should be per-symbol, pooled across symbols, or hybrid;
- whether labels should target `h1`, `h3`, `h5`, or triple-barrier outcomes;
- whether thresholds should be fixed, TRAIN-selected, or calibrated by symbol;
- whether ML should eventually replace PCA routing or coexist as another lane;
- whether any future ML output may influence live advice.
- whether one genuinely distinct, retail-accessible, point-in-time information
  family should be opened before cross-sectional X2 is reconsidered.
- how official SEC data should be supplied to the already-opened five-company
  F0 after the current environment returned Akamai HTTP 403.
- whether exposure permission should use a different target or horizon, or wait
  for a distinct macro/credit information family, without retuning failed C0
  conditions on the inspected OOS evidence.
- whether a future risk controller should be deliberately h5-only, or whether
  multi-horizon stability remains mandatory and requires a distinct macro/credit
  information family; C1 must not answer this by dropping h20 after inspection.
- whether C2's multi-horizon continuous VIX evidence merits one predeclared
  monotone calibration tested only on untouched post-2024 data, or whether the
  risk-policy lane should stop; do not tune that mapping on C2's inspected folds.
