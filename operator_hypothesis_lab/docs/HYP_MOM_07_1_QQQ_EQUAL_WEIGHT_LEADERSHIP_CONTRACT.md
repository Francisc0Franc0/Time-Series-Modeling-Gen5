# HYP-MOM-07.1 QQQ / Equal-Weight Leadership-Persistence Contract

Status: `STOP_HYP_MOM_07_1_NO_SEARCH_ADJUSTED_TRAIN_SURFACE`

Frozen: `2026-08-22`, before any `QQQ-QQEW` return spread or forward outcome
was calculated for this hypothesis.

Executed TRAIN readout: all nine frozen correlations were negative. The least
negative cell was `L20_H1` at `-0.038244`, versus the complete 867-shift
maximum-statistic p90 of `+0.166329`. No cell was nominated; DEVELOPMENT and
confirmation remain unread. See the [results](HYP_MOM_07_1_QQQ_EQUAL_WEIGHT_LEADERSHIP_RESULTS.md).

## Place in the research progression

`HYP-MOM-07.1` is the first formal test from planning label `QQQ-S1` in the
[QQQ minimal-hypothesis slate](../../literature_studies/docs/GEN5_QQQ_MINIMAL_HYPOTHESIS_SLATE.md).

The stopped `LIT-MOM-01.x` tests asked whether an asset's own trailing return
forecast its own future return. This test asks a different question: whether
leadership by the modified-cap-weighted Nasdaq-100 exposure over the same
universe under equal weighting persists. Broad market drift is removed from
both predictor and target.

This is a predictor-only experiment. It does not open a trading policy,
portfolio, costs, Sharpe, drawdown, allocation, leverage, or live behavior.

## Narrative hypothesis

> When modified-cap-weighted Nasdaq-100 exposure has recently outperformed the
> same Nasdaq-100 universe under equal weighting, that mega-cap leadership will
> continue over a short forward horizon because benchmarked positioning and
> institutional allocation adjust gradually.

The falsifying null is that trailing QQQ-minus-equal-weight return has no
positive search-adjusted association with its future spread, or that a
TRAIN-selected relationship does not improve held-out prediction beyond
intercept-only spread drift and the individual return legs.

## Instruments and source boundary

- Modified-cap-weighted exposure: `QQQ`.
- Historical equal-weight proxy: `QQEW`.
- Provider: Alpaca SIP adjusted daily OHLCV only.
- Explicit design and query as-of timestamp:
  `2026-08-22 17:30:00 America/New_York`.

Nasdaq states that `NDXE` contains the same Nasdaq-100 securities and initially
sets each security to equal weight, with quarterly rebalancing. First Trust
states that `QQEW` began on `2006-04-19`; it tracked the Nasdaq-100 Equal
Weighted Index until its underlying index changed to the Nasdaq-100 Select
Equal Weight Index effective `2025-12-22`.

Accordingly:

- `QQEW` is an admissible investable proxy through `2025-12-19`;
- no observation on or after `2025-12-22` may enter this hypothesis;
- the newly launched `QEW` is not substituted because it lacks the required
  history; and
- this contract tests the QQQ-versus-QQEW investable spread, not exact NDX
  versus NDXE index values. Fund expenses, tracking difference, and market
  microstructure remain explicit proxy limitations.

Source references:

- Nasdaq, *Nasdaq-100 Equal Weighted Index (NDXE) Overview*:
  https://indexes.nasdaq.com/Index/Overview/NDXE
- Nasdaq, *Nasdaq-100 Equal Weighted Index Methodology*:
  https://indexes.nasdaq.com/docs/methodology_NDXE.pdf
- First Trust, *First Trust Nasdaq-100 Select Equal Weight ETF (QQEW)*:
  https://www.ftportfolios.com/retail/etf/etfsummary.aspx?Ticker=QQEW

## Evidence zones

### TRAIN discovery

- Required warm-up begins: `2016-01-04`.
- Signal anchors begin no earlier than: `2017-01-03`.
- Every target exit open must be on or before: `2020-12-31`.
- TRAIN is searched only through the frozen nine-cell surface.

### DEVELOPMENT transport

- Signal anchors begin no earlier than: `2021-01-04`.
- Every target exit open must be on or before: `2023-12-29`.
- DEVELOPMENT remains unread unless the TRAIN global surface gate passes.
- Exactly one deterministic TRAIN nominee may enter DEVELOPMENT.

### Locked confirmation

- Signal anchors begin no earlier than: `2024-01-02`.
- Every target exit open must be on or before: `2025-12-19`, the last regular
  session before the documented `QQEW` index change.
- Confirmation remains unread unless all DEVELOPMENT gates pass and the
  operator explicitly opens confirmation after reviewing the development
  packet.

All 2026 observations and all post-mandate-change `QQEW` observations are
prohibited.

## Frozen measurements

Freeze the trailing lookbacks:

\[
L \in \{5,20,60\}
\]

and forward targets:

\[
H \in \{1,5,20\}.
\]

All nine cells use the dates eligible for the widest `L=60`, `H=20` cell
inside each evidence zone.

At the adjusted close of session `t`, define the two causal trailing legs:

\[
X^{Q}_{t,L}=\log(C^{QQQ}_{t}/C^{QQQ}_{t-L}),
\]

\[
X^{E}_{t,L}=\log(C^{QQEW}_{t}/C^{QQEW}_{t-L}),
\]

and leadership:

\[
X^{S}_{t,L}=X^{Q}_{t,L}-X^{E}_{t,L}.
\]

Define the attainable next-open-to-exit-open target legs:

\[
Y^{Q}_{t,H}=\log(O^{QQQ}_{t+1+H}/O^{QQQ}_{t+1}),
\]

\[
Y^{E}_{t,H}=\log(O^{QQEW}_{t+1+H}/O^{QQEW}_{t+1}),
\]

and future leadership:

\[
Y^{S}_{t,H}=Y^{Q}_{t,H}-Y^{E}_{t,H}.
\]

The primary cell model is:

\[
Y^{S}_{t,H}=\alpha_{L,H}+\beta_{L,H}X^{S}_{t,L}+\epsilon_{t,L,H}.
\]

- Primary estimand: continuous `beta[L,H]`.
- Directional alternative: `beta[L,H] > 0`.
- TRAIN search score: Pearson correlation `rho[L,H]` on common anchors.
- Return arithmetic: log returns only.
- No sign rule, position, or P&L is constructed.

## TRAIN search control and nomination

Define the observed global statistic as the largest of the nine TRAIN
correlations. Construct the search-aware null by jointly circularly shifting
all three future-spread target columns against all predictor columns, while
preserving the internal sequence and cross-horizon calendar relationship.

- Enumerate every unique shift whose shortest circular displacement is at
  least `60` common anchors.
- For each shift, retain the maximum correlation across all nine cells.
- Frozen surface threshold: strict exceedance of the 90th percentile of the
  complete shift-maximum distribution.

TRAIN passes only if the observed maximum correlation is positive and strictly
above that threshold. If it fails, record
`STOP_HYP_MOM_07_1_NO_SEARCH_ADJUSTED_TRAIN_SURFACE`, do not calculate a
DEVELOPMENT return spread, and preserve confirmation.

If TRAIN passes, nominate the cell with the largest positive correlation.
Break exact ties toward shorter `H`, then shorter `L`. No neighboring window,
alternative proxy, or attractive individual leg may replace the nominee.

## DEVELOPMENT prediction and controls

The nominated TRAIN cell freezes five TRAIN-estimated prediction models:

1. `DRIFT`: intercept-only future-spread mean;
2. `SPREAD`: intercept plus trailing QQQ-minus-QQEW spread;
3. `QQQ_LEG`: intercept plus trailing QQQ return;
4. `QQEW_LEG`: intercept plus trailing QQEW return;
5. `TWO_LEG`: intercept plus both trailing legs, diagnostic only.

All coefficients are estimated on TRAIN and applied unchanged to DEVELOPMENT.
Mean squared forecast error is the primary loss because the models target a
conditional mean. Mean absolute error is reported as a robustness diagnostic.

For dependence-aware slope uncertainty, freeze a stationary bootstrap of the
ordered DEVELOPMENT rows:

- `10,000` resamples;
- expected block length `20`, matching the longest target;
- deterministic seed `20260822`;
- percentile 90% interval for the DEVELOPMENT spread slope.

## Frozen gates

TRAIN must pass before any DEVELOPMENT outcome is calculated. If it passes,
all six DEVELOPMENT gates must pass before confirmation can be discussed:

1. **Integrity:** both adjusted-daily series cover every required common
   session; prices are finite and positive; dates are unique and ordered;
   causal endpoints and all evidence seals hold.
2. **Directional transport:** DEVELOPMENT spread `beta > 0` and its 90%
   stationary-bootstrap lower bound is strictly above zero.
3. **Rank transport:** DEVELOPMENT Spearman correlation is positive.
4. **Drift value-add:** frozen TRAIN `SPREAD` MSE is strictly below frozen
   TRAIN `DRIFT` MSE on DEVELOPMENT.
5. **Leg specificity:** frozen TRAIN `SPREAD` MSE is strictly below both
   `QQQ_LEG` and `QQEW_LEG` MSE on DEVELOPMENT. `TWO_LEG` is descriptive and
   cannot replace the spread hypothesis.
6. **Temporal stability:** at least two of the three calendar years have a
   positive DEVELOPMENT spread slope, and a strict majority of admissible
   non-overlapping `H` phase offsets have a positive spread slope.

Failure records
`STOP_HYP_MOM_07_1_DEVELOPMENT_LEADERSHIP_PERSISTENCE_GATES_FAILED` and leaves
confirmation sealed. Passage records
`DEVELOPMENT_PASS_HYP_MOM_07_1_CONFIRMATION_REVIEW_REQUIRED`; it does not open
confirmation automatically.

## Required diagnostics

- Complete nine-cell TRAIN correlation and beta tables/heatmaps.
- Observed TRAIN maximum against the complete shift-maximum distribution.
- Nominee scatter and equal-count predictor-quintile target means.
- TRAIN and DEVELOPMENT coefficient/effect-size table if DEVELOPMENT opens.
- Frozen-model DEVELOPMENT MSE and MAE table.
- DEVELOPMENT calendar-year and non-overlapping phase-offset slopes.
- QQQ and QQEW individual predictor legs beside the spread.
- Data-source and mandate-change audit, including the hard `2025-12-19` end.

Diagnostics explain the frozen result. They do not select a different cell,
proxy, date, sign, estimator, or gate.

## Explicitly closed work

This contract does not authorize:

- 2024-2025 confirmation without a later explicit operator gate;
- `QEW`, reconstructed current constituents, NDX/NDXE vendor substitution, or
  post-`2025-12-19` `QQEW` observations;
- another lookback, target, return definition, rank threshold, or spread sign;
- a long/short pair trade, QQQ timing rule, costs, turnover, portfolio
  accounting, Sharpe, drawdown, or monetization claim;
- sector, breadth, volume, semiconductor, regime, volatility, macro, or machine
  learning interactions; or
- advice, allocation, leverage, live execution, or production behavior.
