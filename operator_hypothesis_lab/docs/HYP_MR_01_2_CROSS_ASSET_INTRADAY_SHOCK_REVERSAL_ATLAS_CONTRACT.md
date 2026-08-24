# HYP-MR-01.2 Cross-Asset Intraday-Shock Reversal Atlas Contract

Status: `STOP_HYP_MR_01_2_ATLAS_TRAIN_BREADTH_GATES_FAILED_DEVELOPMENT_NOT_RUN`

Date frozen: `2026-08-23`

## Identity and relationship to HYP-MR-01.1

`HYP-MR-01.2` is the breadth follow-up to the QQQ-only `HYP-MR-01.1` test.
It does not alter or rescue the parent predictor. It asks whether the same
strictly prior-normalized cash-session reversal relationship appears broadly
across a fixed, diverse asset atlas and whether any breadth transports into
untouched later years.

No strategy, threshold, position rule, P&L, Sharpe, drawdown, allocation,
leverage policy, confirmation read, or live behavior is authorized.

## Narrative hypothesis

Temporary cash-session pressure is not unique to QQQ. Across diverse liquid
US-listed assets, a larger signed open-to-close move relative to volatility
known before that session should predict a modest opposite-signed next-session
open-to-close return.

The registered direction remains negative for every asset:

`Y[i,t+1] = alpha[i] + beta[i] * X[i,t] + error[i,t+1]`, with `beta[i] < 0`.

The study does not pool coefficients across unlike assets. It fits the same
one-variable model separately for every fixed atlas member, then aggregates
scale-free forecast improvement across assets and categories.

## Frozen atlas

Registry:
`operator_hypothesis_lab/registries/hyp_mr_01_2_cross_asset_atlas_registry.csv`

The atlas contains 36 assets: the first four instruments by source order in
each of nine categories from the pre-existing, outcome-independent
`gen5_lit_mom_02_1_opening_gap_atlas_registry.csv` registry. No HYP-MR result
was used to choose or order them.

Categories:

- broad US equity;
- US sectors;
- US industries;
- international equity;
- fixed income;
- commodities;
- currencies;
- leveraged or inverse ETFs;
- individual-stock challengers.

Each category contains exactly four assets. QQQ is one of 36 members and has
no special weight. Missing assets are not replaced. The complete fixed atlas
is required for a formal pass; any incomplete asset remains visible in the
coverage audit and forces a source-feasibility STOP.

## Source and evidence partitions

- Provider: canonical Gen5 Alpaca adjusted-daily cache.
- Bars: adjusted daily OHLCV only.
- Explicit as-of timestamp: `2026-08-23 17:30:00 America/New_York`.
- Warm-up query start: `2016-01-04`.
- TRAIN anchors and next-session targets: `2017-01-03` through `2020-12-31`.
- Conditional DEVELOPMENT anchors and targets: `2021-01-04` through
  `2023-12-29`.
- Sealed confirmation: `2024-01-02` through `2025-12-31`.
- No 2024 or later observation may enter TRAIN or DEVELOPMENT.

The runner queries only through TRAIN first. DEVELOPMENT is queried only if all
atlas-wide TRAIN gates pass. Confirmation remains unread even after a
DEVELOPMENT pass.

## Unchanged causal predictor and target

For asset `i` and session `t`:

`TR[i,t] = max(high-low, abs(high-close[t-1]), abs(low-close[t-1]))`

`ATR20_prior[i,t] = mean(TR[i,t-20], ..., TR[i,t-1])`

`ATRpct20_prior[i,t] = ATR20_prior[i,t] / close[i,t-1]`

`X[i,t] = log(close[i,t] / open[i,t]) / ATRpct20_prior[i,t]`

`Y[i,t+1] = log(close[i,t+1] / open[i,t+1])`

The current session never enters its own ATR normalization. Every target is the
exact next listed session for that asset. Asset panels are restricted to the
common `(anchor_date, target_date)` intersection before atlas statistics are
computed, so every asset faces the same calendar rows and timing shifts.

## Per-asset model and benchmark

For every asset independently:

- `REVERSAL`: univariate OLS with intercept and `X`;
- `DRIFT`: intercept-only mean target return;
- expanding folds: fit through 2017 and score 2018; fit through 2018 and score
  2019; fit through 2019 and score 2020;
- influence sensitivity: remove the largest 1% by `abs(X)` and refit the sign.

The scale-free primary asset statistic is relative MSE improvement:

`relative_improvement = (MSE_DRIFT - MSE_REVERSAL) / MSE_DRIFT`.

Positive values favor the registered regressor. Raw MSE differences remain
available but cannot determine cross-asset rankings because asset volatility
differs materially.

## Atlas-wide timing and multiplicity control

The null uses every circular target shift whose minimum displacement is at
least 60 common rows. A single shift is applied to every asset, preserving
cross-asset contemporaneous dependence while breaking predictor-target timing.

For every shift, rerun all three folds for all 36 assets and record:

- median per-asset relative MSE improvement;
- fraction of assets with positive relative MSE improvement.

The observed atlas must clear the type-7 90th percentile for both statistics.
The plus-one empirical upper-tail probabilities are reported. Asset-level
shift percentiles and category summaries are descriptive; they cannot replace
the family-wide gate or nominate assets.

## TRAIN gates

TRAIN passes only if all seven gates hold:

1. all 36 assets and all nine categories pass source, construction, and common
   calendar alignment with at least 900 anchors per asset;
2. median full-TRAIN beta is negative and at least 60% of assets have beta
   below zero;
3. median full-TRAIN Spearman is negative and at least 60% of assets have
   negative Spearman correlation;
4. median relative expanding-fold MSE improvement is positive and at least 50%
   of assets improve on drift;
5. the median positive-fold count is at least two and at least 50% of assets
   improve in at least two of three folds;
6. observed median improvement and positive-asset fraction both strictly exceed
   their complete common-shift p90 values;
7. at least 60% of influence-excluded slopes remain negative.

If any gate fails, record
`STOP_HYP_MR_01_2_ATLAS_TRAIN_BREADTH_GATES_FAILED_DEVELOPMENT_NOT_RUN`.
Do not query DEVELOPMENT or confirmation.

## Conditional DEVELOPMENT gates

After a complete TRAIN pass, freeze every asset's full-TRAIN intercept, slope,
and drift. Score the unchanged models on common 2021-2023 rows.

DEVELOPMENT passes only if all six gates hold:

1. all 36 assets retain at least 600 common rows;
2. median DEVELOPMENT Spearman is negative and at least 60% of assets are
   negative;
3. median relative MSE improvement is positive and at least 50% of assets beat
   drift;
4. at least five of nine category-median relative improvements are positive;
5. at least two of three calendar-year median relative improvements are
   positive;
6. a 10,000-replicate bootstrap of the nine category medians, seed `110102`,
   assigns at least 90% probability to a positive median improvement.

A pass records
`DEVELOPMENT_PASS_HYP_MR_01_2_CONFIRMATION_REVIEW_REQUIRED`; it does not open
confirmation. A failure records
`STOP_HYP_MR_01_2_ATLAS_DEVELOPMENT_BREADTH_GATES_FAILED_CONFIRMATION_NOT_RUN`.

## Required outputs

- frozen atlas registry and contract;
- source, coverage, integrity, construction, and common-calendar audits;
- per-asset and per-fold TRAIN results;
- category and atlas TRAIN summaries;
- complete common-shift null and asset-level shift percentiles;
- conditional DEVELOPMENT asset, category, and year summaries or an explicit
  unread marker;
- representative cross-asset plots and a QQQ-versus-atlas comparison;
- explicit confirmation-unread marker;
- results report, progress-log entry, and updated evidence deck.

## STOP discipline

Do not select winners, drop weak categories, weight by observed performance,
change ATR or horizon, add thresholds or nonlinearities, refit in DEVELOPMENT,
invert continuation-shaped assets, or inspect confirmation. Any refinement is
a separately registered hypothesis, not a rescue of this atlas.

## Recorded outcome

The formal run preserved the frozen atlas and reached a TRAIN STOP. Direction
was broad—`31 / 36` slopes and `33 / 36` rank correlations were negative—but
forecast value was not: median relative MSE improvement was `-0.000255`, only
`12 / 36` assets beat drift, and only `16 / 36` improved in at least two folds.
The common-shift positive-asset fraction also failed to strictly clear its p90.

TRAIN passed `4 / 7` gates. DEVELOPMENT was not queried and 2024-2025
confirmation remains sealed. The complete result is recorded in
`HYP_MR_01_2_CROSS_ASSET_INTRADAY_SHOCK_REVERSAL_ATLAS_RESULTS.md`.
