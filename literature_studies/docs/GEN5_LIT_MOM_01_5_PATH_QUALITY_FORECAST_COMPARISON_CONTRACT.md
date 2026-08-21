# LIT-MOM-01.5 Path-Quality Incremental Forecast Comparison Contract

Status: `FROZEN_IMPLEMENTATION_APPROVED_RESULTS_UNREAD`

Frozen on `2026-08-21` after the operator approved comparing an intercept-only
drift forecast, the stopped raw-return predictor, and a compact causal
path-quality extension. No `01.5` path-quality feature, forecast, loss, or
target association was computed before this contract.

## Place in the research progression

`LIT-MOM-01.4` found no false-discovery-controlled transport for a raw
trailing-log-return predictor across its 92-asset atlas. The result does not
show that trend states do not exist. It shows that trailing return alone did
not provide a stable linear measurement of future return.

`HYP-REG-05.1` previously stopped Kaufman efficiency ratio and ADX as
predictors of future path straightness. Its efficiency-ratio
direction-survival clue was descriptive only. `01.5` does not reopen or
rescue that test. It asks a different, incremental forecast question:

> Across the frozen daily atlas and horizon surface, does causal information
> about the coherence and shock concentration of a positive trailing move
> improve future-return forecasts beyond both constant drift and raw trailing
> return?

This is a forecast comparison, not a strategy. It may produce model-loss
tables, coefficient diagnostics, and candidate evidence only.

## Frozen universe and data boundary

Reuse every row of:

`literature_studies/registries/gen5_lit_mom_02_1_opening_gap_atlas_registry.csv`

The registry contains exactly 92 instruments under frozen SHA-256:

`69C481DCB8443AADC30D8BF10FC7FFB7EC23D193CE88A992E42F8529225E4737`

Preserve the `01.4` strata:

- `PLAIN_ETF`: 68 rows;
- `ENGINEERED_ETF`: six leveraged or inverse ETFs; and
- `STOCK_CHALLENGER`: 18 survivor-limited stocks.

`SPY` remains reproduction-only because related 2017-2023 outcomes have
already received direct inspection. Report it, but exclude it from candidate
false-discovery families.

- Provider: Alpaca only.
- Bars: adjusted daily OHLCV only.
- Explicit design as-of timestamp:
  `2026-08-21 17:30:00 America/New_York`.
- Query start: `2016-01-04`.
- Maximum query end: `2023-12-29`.
- TRAIN signal anchors: `2017-01-03` through targets ending no later than
  `2020-12-31`.
- DEVELOPMENT signal anchors: `2021-01-04` through targets ending no later
  than `2023-12-29`.
- Every asset/cell must have at least 600 common anchors in both periods.

The complete requested range must pass the same identity, duplicate,
positive-price, adjusted-daily, and bounded-future checks as `01.4`. No asset
may be substituted after coverage or outcomes.

## Frozen target and horizon surface

For adjusted close `C` and adjusted open `O`, define the future target:

\[
Y_{t,H}=\log(O_{t+1+H}/O_{t+1}).
\]

Freeze six nondegenerate path lookbacks:

\[
L \in \{5,10,25,60,120,250\}
\]

and the unchanged four target horizons:

\[
H \in \{5,10,25,60\}.
\]

All 24 cells are forecast and reported. No cell is selected, promoted,
dropped, or reweighted. `L=1` is excluded before outcomes because path
coherence and single-step shock concentration are identically one and cannot
distinguish the richer model from raw return.

Every cell uses a common anchor panel requiring all 250 prior closes and all
60 future open intervals. Thus model comparisons inside an asset/period use
identical observations.

## Frozen causal features

For the `L` close-to-close log steps ending at signal close `t`, define:

\[
r_j=\log(C_j/C_{j-1}), \qquad
X_{t,L}=\sum r_j=\log(C_t/C_{t-L}).
\]

Define path efficiency:

\[
ER_{t,L}=|X_{t,L}|/\sum |r_j|
\]

and shock concentration:

\[
SC_{t,L}=\max |r_j|/\sum |r_j|.
\]

Both are bounded in `[0,1]`. If every step is exactly zero, set `ER=0` and
`SC=0`.

The two incremental positive-move features are:

\[
Q_{t,L}=\max(X_{t,L},0)ER_{t,L}
\]

and:

\[
S_{t,L}=\max(X_{t,L},0)SC_{t,L}.
\]

`Q` distinguishes coherent net progress. `S` distinguishes a positive return
concentrated in one or a few shocks. All features use information available
at signal close only.

## Frozen forecast authorities

Fit every authority independently for each asset and cell on TRAIN only:

| ID | Forecast | Interpretation |
|---|---|---|
| `B0_DRIFT` | `Y = alpha + error` | Constant TRAIN mean; unconditional drift baseline |
| `B1_RAW` | `Y = alpha + beta X + error` | Raw trailing-return benchmark |
| `Q2_PATH` | `Y = alpha + beta X + gamma Q + delta S + error` | Path-quality extension |

Use unpenalized base-R ordinary least squares. Standardize non-intercept
features with TRAIN means and standard deviations, then apply those frozen
transformations to DEVELOPMENT. Require finite nonzero TRAIN standard
deviations and full-rank fits. An invalid cell makes the asset analytically
ineligible; it may not be silently reduced to another model or replaced.

The mechanism expectation is `gamma > 0` and `delta < 0`: coherent positive
movement should help, while shock-concentrated positive movement should hurt.
Coefficient signs are summarized across all 24 cells rather than selected
cell by cell.

## Primary out-of-sample comparison

For model `m`, asset `a`, cell `c`, and DEVELOPMENT anchor `t`, define the
TRAIN-variance-scaled squared loss:

\[
L_{m,a,c,t}=(Y_{a,c,t}-\widehat{Y}_{m,a,c,t})^2/
Var_{TRAIN}(Y_{a,c}).
\]

Average each model's scaled loss equally across the 24 cells at each anchor.
This prevents long target horizons or high-volatility assets from dominating
and prevents favorable horizon selection.

Freeze three paired anchor-level differentials, where positive favors the
model named second:

- `D10 = loss(B0_DRIFT) - loss(B1_RAW)`;
- `D21 = loss(B1_RAW) - loss(Q2_PATH)`; and
- `D20 = loss(B0_DRIFT) - loss(Q2_PATH)`.

`D21` is the primary incremental question. `D10` explains whether raw return
beats drift. `D20` ensures the richer model also clears the elementary drift
baseline. Report unscaled MSE, MAE, scaled loss, and out-of-sample skill
relative to `B0_DRIFT` for every asset, cell, and model.

## Dependence and multiplicity control

For each asset and contrast, apply a 10,000-draw stationary-block bootstrap
to the ordered DEVELOPMENT anchor-level differential with expected block
length 60. Use deterministic seed `2026082150 + 10 * registry_order +
contrast_order`, with `D10`, `D21`, and `D20` ordered 1, 2, and 3.

Report:

- the observed mean differential;
- the percentile 90% interval from the uncentered bootstrap; and
- a one-sided centered-null probability that the mean differential is no
  greater than zero.

Apply Benjamini-Hochberg `q=0.10` separately by contrast and by the three
frozen strata, using every analytically eligible non-SPY asset, including
negative and null outcomes.

An asset becomes a
`PATH_QUALITY_INCREMENTAL_DEVELOPMENT_CANDIDATE` only if:

1. `D21 > 0` and its within-stratum BH q-value is `<= 0.10`;
2. `D20 > 0` and its within-stratum BH q-value is `<= 0.10`;
3. both 90% bootstrap lower bounds are strictly positive; and
4. the median standardized `Q2_PATH` coefficient across its 24 cells has
   `gamma > 0` and `delta < 0`.

`B1_RAW` may be labeled a drift-controlled raw-return clue when `D10 > 0`,
its 90% lower bound is positive, and its within-stratum BH q-value is
`<= 0.10`. That label does not reopen `01.4`, select a horizon, or authorize a
strategy.

## Required evidence

1. Contract, registry checksum, coverage, and analytical-eligibility ledger.
2. All 92 assets and all 24 cells, including invalid reasons if any.
3. TRAIN feature moments, fit ranks, coefficients, and target variances.
4. DEVELOPMENT forecasts and cell-level MSE, MAE, scaled loss, and skill.
5. Asset-level `D10`, `D21`, and `D20` with bootstrap intervals,
   probabilities, and BH values.
6. Stratum/category summaries, sign breadth, and coefficient-direction
   summaries.
7. SPY reference diagnostics with an explicit noncandidate label.
8. Drift-versus-raw-versus-path loss plots, incremental-skill maps, and
   coefficient-mechanism plots.
9. Explicit confirmation lock and absence of strategy/performance fields.

## Decision map

- **No path-quality candidates:** record
  `STOP_LIT_MOM_01_5_NO_INCREMENTAL_PATH_QUALITY_FORECAST` and preserve
  confirmation.
- **Asset-specific candidate:** report it as a bounded discovery; do not claim
  a universal trend mechanism or open confirmation automatically.
- **Category breadth:** several candidates with aligned `gamma` and `delta`
  in one category strengthen the mechanism interpretation but still require
  a later explicit confirmation gate.
- **Raw beats drift but path quality fails:** record the raw-return clue
  without reopening horizon selection or `01.4`.
- **Path beats raw but not drift:** stop; the extension has not earned a useful
  forecast authority.

## Locked confirmation

- No bar on or after `2024-01-02` may enter initial execution.
- `2024-01-02` through `2025-12-31` remains a one-shot later confirmation
  period requiring explicit operator authorization.
- Only exact DEVELOPMENT candidates may enter with unchanged asset, 24-cell
  equal weighting, features, models, loss scaling, bootstrap, direction, and
  stratum.
- All targets entering or exiting during 2026 remain excluded.

## Explicitly closed work

This contract does not authorize:

- tuning features, signs, transformations, penalties, horizons, cell weights,
  bootstrap settings, or FDR families after outcomes;
- selecting favorable cells, years, categories, or assets;
- adding ADX, breadth, volume, ATR, regime, nonlinear, cross-sectional, or
  native-market features;
- thresholds, positions, trades, costs, turnover, P&L, Sharpe, drawdown,
  allocation, leverage, portfolio replay, advice, or live behavior;
- native futures, FX, crypto, options, or intraday data; or
- access to 2024-2025 during initial execution.
