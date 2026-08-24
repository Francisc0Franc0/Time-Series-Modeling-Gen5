# HYP-MOM-08.1 QQQ / SPY Relative-Strength Persistence Contract

Status: `STOP_HYP_MOM_08_1_NO_SEARCH_ADJUSTED_TRAIN_SURFACE`

Date frozen: `2026-08-22`, after a return-blind source/calendar inventory and
before any QQQ-minus-SPY predictor, target, correlation, slope, or forecast
loss was calculated for this hypothesis.

## Place in the research progression

`HYP-MOM-08.1` formalizes planning label `QQQ-S3` from the
[QQQ minimal-hypothesis slate](../../literature_studies/docs/GEN5_QQQ_MINIMAL_HYPOTHESIS_SLATE.md).

The stopped `HYP-MOM-07.1` asked whether QQQ leadership over an equal-weight
version of the same Nasdaq-100 universe persisted. The stopped
`HYP-IMOM-03.1` asked whether first-hour semiconductor leadership reached QQQ
later in the same session. This test instead asks whether Nasdaq-100 style
leadership over the broad US market persists across daily horizons.

It is predictor-only. It does not open a trading policy, costs, P&L, Sharpe,
drawdown, portfolio construction, allocation, leverage, advice, or live
behavior.

## Narrative hypothesis

> When QQQ has recently outperformed SPY, that relative style leadership will
> continue over a short forward horizon because investor and institutional
> allocations between large-cap growth and the broad US equity market adjust
> gradually rather than instantaneously.

The falsifying null is that trailing QQQ-minus-SPY log return has no positive
search-adjusted association with forward QQQ-minus-SPY log return, or that a
TRAIN-selected relationship fails to improve held-out prediction beyond
intercept-only relative drift and the separate QQQ and SPY return legs.

## Source and return-blind inventory

- Provider: Alpaca adjusted daily OHLCV cache.
- Symbols: `QQQ` and `SPY` only.
- Timeframe: `1D`.
- Explicit as-of timestamp: `2026-08-22 17:30:00 America/New_York`.
- Query start: `2016-01-04`.
- Hard maximum readable date in this contract: `2025-12-31`.
- All 2026 observations are prohibited.

Before returns were read, the cached schemas and calendars were inventoried.
Both series contain finite-looking canonical fields, unique dates, and exact
common session counts in every year from 2016 through 2025: `252`, `251`,
`251`, `252`, `253`, `252`, `251`, `250`, `252`, and `250`. There were zero
QQQ-only or SPY-only dates through `2025-12-31`.

The inventory authorizes construction checks, not return interpretation.

## Evidence zones

### TRAIN discovery

- Warm-up begins: `2016-01-04`.
- Signal anchors begin no earlier than: `2017-01-03`.
- Every target exit open must be on or before: `2020-12-31`.
- Only the frozen nine-cell surface and its family-wise control may be read.

### DEVELOPMENT transport

- Signal anchors begin no earlier than: `2021-01-04`.
- Every target exit open must be on or before: `2023-12-29`.
- DEVELOPMENT remains unread unless the complete TRAIN surface gate passes.
- Exactly one deterministic TRAIN nominee may enter DEVELOPMENT.

### Locked confirmation

- Signal anchors begin no earlier than: `2024-01-02`.
- Every target exit open must be on or before: `2025-12-31`.
- Confirmation remains unread in this slice regardless of TRAIN or
  DEVELOPMENT results.
- A later explicit operator gate is required after DEVELOPMENT review.

## Frozen measurements

Freeze trailing lookbacks

`L in {5, 20, 60}`

and forward targets

`H in {1, 5, 20}`.

All nine cells use the common anchors eligible for the widest `L=60`, `H=20`
cell inside an evidence zone.

At the adjusted close of session `t`, define:

`X_Q(t,L) = log(C_QQQ(t) / C_QQQ(t-L))`

`X_S(t,L) = log(C_SPY(t) / C_SPY(t-L))`

`X_R(t,L) = X_Q(t,L) - X_S(t,L)`.

The signal is known after the close of `t`. The attainable forward target
begins at the next session's open:

`Y_Q(t,H) = log(O_QQQ(t+1+H) / O_QQQ(t+1))`

`Y_S(t,H) = log(O_SPY(t+1+H) / O_SPY(t+1))`

`Y_R(t,H) = Y_Q(t,H) - Y_S(t,H)`.

The primary cell model is:

`Y_R(t,H) = alpha(L,H) + beta(L,H) * X_R(t,L) + error(t,L,H)`.

- Primary estimand: continuous `beta(L,H)`.
- Directional alternative: `beta(L,H) > 0`.
- TRAIN search score: Pearson correlation on common anchors.
- Supporting readouts: slope, Spearman correlation, and predictor-quintile
  target means.
- Arithmetic: log returns only.
- No position, sign threshold, or P&L is constructed.

## TRAIN multiplicity control and nomination

The observed global statistic is the largest of the nine TRAIN correlations.
Construct a search-aware null by jointly circularly shifting all three
forward-relative target columns against all predictor columns. The shift
preserves the target sequence and cross-horizon calendar relationship while
breaking the proposed predictor/target alignment.

- Enumerate every unique shift whose shortest circular displacement is at
  least `60` common anchors.
- Retain the maximum correlation across all nine cells for each shift.
- Frozen threshold: strict exceedance of the 90th percentile of the complete
  shift-maximum distribution.

TRAIN passes only if:

1. at least `900` common TRAIN anchors exist;
2. the observed maximum correlation is strictly positive; and
3. the observed maximum strictly exceeds the shift-maximum p90 threshold.

Failure records
`STOP_HYP_MOM_08_1_NO_SEARCH_ADJUSTED_TRAIN_SURFACE`, leaves DEVELOPMENT and
confirmation unread, and prohibits selecting a wrong-sign or nearby cell.

If TRAIN passes, nominate the cell with the largest positive correlation.
Break exact ties toward shorter `H`, then shorter `L`. No alternative return
definition, beta residualization, target, date range, or attractive leg may
replace the nominee.

## Frozen DEVELOPMENT models and uncertainty

For the nominated cell, fit these models once on TRAIN and apply their
coefficients unchanged to DEVELOPMENT:

1. `DRIFT`: intercept-only future-relative mean;
2. `RELATIVE`: intercept plus trailing QQQ-minus-SPY return;
3. `QQQ_LEG`: intercept plus trailing QQQ return;
4. `SPY_LEG`: intercept plus trailing SPY return;
5. `TWO_LEG`: intercept plus both trailing legs, diagnostic only.

Mean squared error is the primary forecast loss. Mean absolute error is a
robustness diagnostic. `TWO_LEG` has an additional degree of freedom and
cannot replace the stated relative-strength mechanism.

For DEVELOPMENT slope uncertainty, use a deterministic stationary bootstrap:

- `10,000` resamples;
- expected block length `20` sessions;
- seed `803101`;
- percentile 90% interval for the DEVELOPMENT relative-strength slope.

No beta-residualized QQQ target is included. Estimating a changing market beta
would define a different hypothesis. The frozen SPY leg and two-leg model are
the controls for general market-return contamination here.

## Frozen DEVELOPMENT gates

All six gates must pass:

1. **Integrity:** exact adjusted-daily common sessions, unique ordered dates,
   finite positive prices, causal endpoints, and all evidence seals.
2. **Directional transport:** DEVELOPMENT relative-strength slope is positive
   and its 90% stationary-bootstrap lower bound is strictly above zero.
3. **Rank transport:** DEVELOPMENT Spearman correlation is positive.
4. **Relative drift value-add:** frozen TRAIN `RELATIVE` MSE is strictly below
   frozen TRAIN `DRIFT` MSE on DEVELOPMENT.
5. **Leg specificity:** `RELATIVE` MSE is strictly below both `QQQ_LEG` and
   `SPY_LEG` MSE on DEVELOPMENT.
6. **Temporal stability:** at least two of the three calendar years have a
   positive slope, and a strict majority of admissible non-overlapping `H`
   phase offsets have a positive slope.

Failure records
`STOP_HYP_MOM_08_1_DEVELOPMENT_RELATIVE_STRENGTH_GATES_FAILED` and leaves
confirmation sealed. Passage records
`DEVELOPMENT_PASS_HYP_MOM_08_1_CONFIRMATION_REVIEW_REQUIRED`; it does not open
confirmation automatically.

## Required artifacts and diagnostics

- source coverage and integrity tables;
- complete TRAIN correlation and slope surfaces;
- observed TRAIN maximum against the complete shift-maximum distribution;
- nominee scatter and equal-count predictor-quintile target means if TRAIN
  passes;
- frozen-model DEVELOPMENT MSE and MAE, coefficient, calendar-year, and phase
  tables if DEVELOPMENT opens;
- QQQ and SPY individual legs beside the relative predictor; and
- clear `DEVELOPMENT_NOT_READ` and `CONFIRMATION_NOT_READ` markers when gated.

Diagnostics explain the frozen result. They may not select another cell,
sign, horizon, estimator, market proxy, or evidence interval.

## Explicitly closed work

This contract does not authorize:

- 2024-2025 confirmation;
- other equity indexes, QQQ variants, sector ETFs, constituents, breadth,
  volume, volatility, regime, macro, or machine-learning interactions;
- another lookback, target horizon, return definition, beta estimate,
  residualized target, threshold, sign, or overlap rule;
- long QQQ/short SPY trading, QQQ timing, costs, turnover, P&L, Sharpe,
  drawdown, allocation, leverage, or monetization claims; or
- advice, live execution, production, or deployment behavior.

## Final readout

Execution stopped at TRAIN under
`STOP_HYP_MOM_08_1_NO_SEARCH_ADJUSTED_TRAIN_SURFACE`. The best observed cell
was `L60_H20`, with correlation `0.075240` and slope `0.044426`, versus the
complete circular-shift maximum-statistic p90 of `0.151402`; the empirical
upper-tail probability was `0.321429`. Eight of nine cells had the wrong sign.
No cell was nominated, DEVELOPMENT was not queried or calculated, and
2024-2025 confirmation remains sealed. See the
[results](HYP_MOM_08_1_QQQ_SPY_RELATIVE_STRENGTH_RESULTS.md).
