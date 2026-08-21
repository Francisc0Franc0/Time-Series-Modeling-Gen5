# LIT-MOM-01.3 SPY Horizon-Surface Predictor Hypothesis Card

Status: `FROZEN_OUTCOMES_NOT_OPEN`

Pre-outcome amendment: the initial fixed-`250/25` draft was widened on
`2026-08-21`, at the operator's request, before any `01.3` data or outcome was
read. The amended 28-cell surface below is the sole governing card.

## Place in the research progression

`LIT-MOM-01.3` returns to the smallest predictive proposition behind Ernest
P. Chan's Chapter 6 time-series-momentum example: does one asset's own past
return contain information about its own causally attainable future return?

This is a substantive diagnostic variant of `LIT-MOM-01.1` and `01.2`, not a
rescue or reinterpretation of either stopped implementation. It removes the
49-cell trading selector, rolling sleeves, long/short or long/cash policy,
full-capital compounding, costs, portfolio accounting, and production gates.
It fixes one instrument and a compact, confirmable predictor-target surface
before outcomes.

The visible output of a later execution slice would be a predictor-target
evidence packet, not a backtest.

## Research question

Across a frozen Chan-style horizon surface, does `SPY` exhibit more positive
own-return predictive structure than expected under time-misaligned controls,
and can one deterministically selected sandbox cell transport to locked
confirmation?

## Mechanism and scope

The source proposition is time-series momentum: persistence in an asset's own
return, distinct from ranking assets against peers. `SPY` is frozen because it
is a liquid, diversified, Alpaca-tradable ETF with long adjusted-daily history
and no point-in-time constituent reconstruction requirement.

This is an equity-index ETF calibration exercise. It does not reproduce the
roll, margin, financing, leverage, or maturity economics of Chan's `TU`
Treasury future. Positive equity drift is an explicit confound to measure,
not evidence of momentum by itself.

Chan's `250/25` worked specification remains a named literature anchor. It is
not imposed as the SPY primary cell because doing so would assume that a
horizon selected for `TU` transports unchanged to an equity ETF.

## Frozen variables

Freeze the source lookback set:

\[
L \in \{1,5,10,25,60,120,250\}
\]

and the confirmable swing-target set:

\[
H \in \{5,10,25,60\}.
\]

The resulting 28 cells are the complete admissible search surface. Horizons
`H=1`, `120`, and `250` are excluded: one session is outside the agreed swing
boundary, while the longer targets would leave too little independent timing
content and fewer than 400 eligible anchors in the locked two-year
confirmation zone.

All cells use one common anchor panel. An anchor is admitted only when it has
all 250 prior adjusted closes and all 60 future open-to-open intervals required
by the widest cell. Shorter `L` and `H` cells do not recover additional dates.
This prevents cell ranking from being driven by different calendar samples.

At the adjusted close of eligible session `t`, define each predictor:

\[
X_{t,L} = \log(C_t / C_{t-L}).
\]

The predictor is known only after session `t` closes. Define each causal
target from the next session's adjusted open through an exit open `H`
trading-session intervals later:

\[
Y_{t,H} = \log(O_{t+1+H} / O_{t+1}).
\]

For every frozen cell `(L,H)`, estimate:

\[
Y_{t,H} = \alpha_{L,H} + \beta_{L,H} X_{t,L} + \epsilon_{t,L,H}.
\]

- Unit of observation: one eligible daily signal anchor.
- Cell estimand: the continuous slope `beta[L,H]`.
- Cell null: `beta[L,H] <= 0`.
- Directional alternative: `beta[L,H] > 0`.
- Search score: the scale-free Pearson correlation `rho[L,H]` between the
  same predictor and causal target rows.
- Literature anchor: exactly `(L=250,H=25)`.
- Instrument: exactly `SPY`.
- Bar type: Alpaca adjusted daily OHLCV.
- Explicit design as-of timestamp:
  `2026-08-21 17:30:00 America/New_York`.

No sign threshold or position rule enters any estimand. Each intercept
absorbs the unconditional average future return, so a positive market drift
alone does not establish a positive slope. Correlation is used only to compare
cells on a common scale during the frozen search; `beta` remains the reported
effect-size estimand.

## Evidence zones

### Research sandbox

- Eligible signal anchors begin no earlier than `2017-01-03`.
- Target exit opens must be on or before `2023-12-29`.
- Required prior warm-up may begin on `2016-01-04`.
- This period has already been inspected by the parent Chan lanes and cannot
  become fresh confirmation.

The first execution slice may read only this sandbox. Its purpose is to verify
the implementation, map all 28 cells, and apply the frozen global search test
and nomination rule without changing the card. Failure of the global surface
test stops before confirmation. Passage identifies one nominee but only
permits an operator decision about whether the information gain justifies
consuming confirmation; it does not open confirmation automatically.

### Locked confirmation

- Signal anchors begin no earlier than `2024-01-02`.
- Target exit opens must be on or before `2025-12-31`.
- No confirmation outcome may be read until the sandbox packet is complete,
  the implementation is frozen, and the operator explicitly opens the replay.
- Confirmation receives exactly one sandbox nominee. It cannot select the
  instrument, another cell, estimator, uncertainty method, direction, or
  decision criterion.

### Forward evidence

All targets whose entry or exit enters 2026 remain outside this hypothesis
card's confirmation surface. No paper-trading or live behavior is opened.

## Sandbox surface test and nomination

The sandbox first estimates all 28 `rho[L,H]` values. Define the observed
global statistic:

\[
M_{obs}=\max_{L,H}\rho_{L,H}.
\]

Build a search-aware null by circularly shifting each target series relative
to its predictor while preserving both series' internal ordering. For every
admissible shift, recompute all 28 cells and retain that shift's maximum
correlation. Exclude shifts whose shortest circular displacement is less than
250 sessions. Apply the same displacement jointly to all four target-horizon
columns so their cross-horizon calendar relationship is preserved. Enumerate
every remaining unique sandbox shift rather than sampling a favorable subset.

The single sandbox surface-opening criterion is:

> `M_obs > 0` and `M_obs` is strictly above the 90th percentile of the
> circular-shift maximum-statistic distribution.

If it fails, record
`STOP_LIT_MOM_01_3_SANDBOX_NO_SEARCH_ADJUSTED_PREDICTIVE_SURFACE`, preserve
confirmation, and do not nominate a cell.

If it passes, nominate the cell with the largest positive `rho[L,H]`. Break an
exact numerical tie toward the shorter `H`, then the shorter `L`. The nominee
is frozen before any confirmation row is read. Neighborhood smoothness,
effect-size magnitude, and the location of `250/25` remain diagnostics and
cannot replace this rule.

## Cell uncertainty and locked-confirmation criterion

Daily multi-session targets overlap, so ordinary independent-row Pearson or
OLS uncertainty is not admissible as primary evidence.

Freeze a seeded stationary-block bootstrap of the ordered daily
predictor-target rows:

- 10,000 resamples;
- expected block length: 60 sessions, matching the longest admissible target;
- deterministic seed: `20260821`;
- percentile 90% interval for each sandbox `beta[L,H]` and for the single
  locked-confirmation nominee;
- complete eligible rows only, with no imputation.

The single principal locked-confirmation criterion is:

> the nominee's `beta > 0` and the 90% stationary-block-bootstrap lower bound
> for that `beta` is strictly greater than zero.

All data-integrity checks must also pass for the result to be interpretable.
They are validity requirements, not additional evidence gates.

## Required diagnostics

Diagnostics explain the primary estimate and do not form a conjunctive
promotion ladder:

1. A complete 28-cell table and `rho[L,H]`/`beta[L,H]` heatmaps.
2. The observed maximum statistic against the complete admissible
   circular-shift maximum distribution.
3. Scatter and fitted line for the deterministic nominee.
4. Equal-count nominee predictor-quintile conditional means with support and
   uncertainty.
5. Nominee top-minus-bottom predictor-quintile target contrast.
6. Nominee past-sign/future-sign confusion matrix and directional accuracy.
7. Unconditional target mean and positive-target frequency by `H`.
8. Calendar-year nominee slope, support, and contribution concentration.
9. `H` phase-offset views for the nominee using nonoverlapping target windows
   within each phase, reported as sensitivity rather than independent
   replications.
10. Neighbor-cell continuity around the nominee on the ordered source grid.
11. The canonical `250/25` row beside the nominee without promotion authority.

The ordinary OLS slope and nominal p-value may be shown as teaching
statistics, clearly labeled non-authoritative.

## Hard validity checks

Stop without interpreting prediction if any of the following occurs:

- missing or duplicate sessions inside a requested interval that are not
  explained by the exchange calendar;
- nonpositive or nonfinite required adjusted prices;
- a common anchor lacking all 250 prior sessions or all 60 future open
  intervals;
- target endpoints outside the declared evidence zone;
- rows dated after the explicit as-of timestamp;
- predictor or target values that disagree with an independently recomputed
  fixture;
- bootstrap replay that is not deterministic under the frozen seed;
- fewer than 400 eligible daily common anchors in locked confirmation;
- a missing or duplicated cell in the frozen 28-cell surface; or
- a circular-shift distribution that omits an admissible unique shift.

## Interpretation map

- **Search-adjusted sandbox evidence:** the global surface criterion passes and
  one cell is nominated. This is discovery evidence, not confirmation.
- **No search-adjusted surface:** the global criterion fails. Preserve locked
  confirmation and stop without selecting an attractive cell.
- **Positive predictive evidence:** the single locked-confirmation criterion
  passes.
  This may open discussion of a separate monetization contract; it does not
  establish tradability.
- **Positive but uncertain:** `beta > 0`, but its lower bound is not above
  zero. Record the estimated magnitude and uncertainty; do not construct a
  strategy from the same sample.
- **Null:** the slope is economically small and uncertainty includes zero.
- **Reversal-shaped:** `beta < 0`. Record evidence against the directional
  momentum alternative; do not reverse the strategy without a new hypothesis.
- **Sandbox nominee, confirmation null:** record failed temporal transport and
  stop the lane without returning to the surface.
- **Drift or alignment explained:** positive conditional returns without a
  positive slope, monotone conditional curve, or unusual circular-shift
  placement are not incremental momentum evidence.
- **Concentrated or unstable:** retain the primary result but label its
  dependence on a small number of dates, years, or phase offsets. Diagnostics
  explain evidence; they do not silently replace the frozen criterion.

## Explicitly closed work

This card authorizes no data query or outcome calculation by itself. It also
does not authorize:

- any horizon outside the frozen 28-cell surface;
- changing the global statistic, shift exclusions, percentile, or nomination
  rule after sandbox outcomes;
- replacing `SPY` after outcomes;
- long/cash, long/short, sleeve, or full-capital execution;
- entry thresholds, exits, stops, sizing, or allocation;
- costs, turnover, P&L, Sharpe, drawdown, or portfolio comparison;
- cross-asset breadth or asset selection;
- regime, sector, volatility, beta, or machine-learning filters;
- 2024-2025 confirmation access without a later explicit operator gate; or
- advice, leverage, live execution, or production behavior.

## Change log from the parent lanes

- `01.1`: removes TRAIN horizon selection and rolling long/short sleeves.
- `01.2`: removes the long-only full-capital policy and cross-asset atlases.
- preserves Chan's canonical `250/25` as a named literature anchor while
  replacing forced horizon transport with a frozen 28-cell SPY search;
- changes the primary target from close-to-close screening return to a
  causally attainable next-open-to-exit-open return;
- changes the primary question from strategy performance to a continuous
  predictor-target slope; and
- uses one search-adjusted global sandbox criterion, one deterministic nominee,
  and one locked-confirmation criterion instead of a strategy-promotion
  conjunction.
