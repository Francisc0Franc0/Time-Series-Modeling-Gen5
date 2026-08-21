# LIT-MOM-01.3 Minimal SPY Predictor Hypothesis Card

Status: `FROZEN_OUTCOMES_NOT_OPEN`

## Place in the research progression

`LIT-MOM-01.3` returns to the smallest predictive proposition behind Ernest
P. Chan's Chapter 6 time-series-momentum example: does one asset's own past
return contain information about its own causally attainable future return?

This is a substantive diagnostic variant of `LIT-MOM-01.1` and `01.2`, not a
rescue or reinterpretation of either stopped implementation. It removes the
49-cell horizon search, rolling sleeves, long/short or long/cash policy,
full-capital compounding, costs, portfolio accounting, and production gates.
It fixes one instrument and one literature horizon before outcomes.

The visible output of a later execution slice would be a predictor-target
evidence packet, not a backtest.

## Research question

For `SPY`, does its trailing 250-session log return positively predict its
next causally attainable 25-session open-to-open log return?

## Mechanism and scope

The source proposition is time-series momentum: persistence in an asset's own
return, distinct from ranking assets against peers. `SPY` is frozen because it
is a liquid, diversified, Alpaca-tradable ETF with long adjusted-daily history
and no point-in-time constituent reconstruction requirement.

This is an equity-index ETF calibration exercise. It does not reproduce the
roll, margin, financing, leverage, or maturity economics of Chan's `TU`
Treasury future. Positive equity drift is an explicit confound to measure,
not evidence of momentum by itself.

## Frozen variables

At the adjusted close of eligible session `t`, define the predictor:

\[
X_t = \log(C_t / C_{t-250}).
\]

The signal is known only after session `t` closes. Define the causal target
from the next session's adjusted open through an exit open 25 trading-session
intervals later:

\[
Y_{t,25} = \log(O_{t+1+25} / O_{t+1}).
\]

The primary model is:

\[
Y_{t,25} = \alpha + \beta X_t + \epsilon_t.
\]

- Unit of observation: one eligible daily signal anchor.
- Primary estimand: the continuous slope `beta`.
- Null: `beta <= 0`.
- Directional alternative: `beta > 0`.
- Predictor horizon: exactly 250 trading sessions.
- Target horizon: exactly 25 open-to-open trading-session intervals.
- Instrument: exactly `SPY`.
- Bar type: Alpaca adjusted daily OHLCV.
- Explicit design as-of timestamp:
  `2026-08-21 17:30:00 America/New_York`.

No sign threshold or position rule enters the primary estimand. The intercept
absorbs the unconditional average future return, so a positive market drift
alone does not establish a positive slope.

## Evidence zones

### Research sandbox

- Eligible signal anchors begin no earlier than `2017-01-03`.
- Target exit opens must be on or before `2023-12-29`.
- Required prior warm-up may begin on `2016-01-04`.
- This period has already been inspected by the parent Chan lanes and cannot
  become fresh confirmation.

The first execution slice may read only this sandbox. Its purpose is to verify
the implementation and map the fixed relationship without changing the card.
A null or negative sandbox result should normally stop before confirmation.
A positive or uncertain sandbox result permits an operator decision about
whether the information gain justifies consuming confirmation; it does not
open confirmation automatically.

### Locked confirmation

- Signal anchors begin no earlier than `2024-01-02`.
- Target exit opens must be on or before `2025-12-31`.
- No confirmation outcome may be read until the sandbox packet is complete,
  the implementation is frozen, and the operator explicitly opens the replay.
- Confirmation cannot select the instrument, horizons, estimator, uncertainty
  method, direction, or decision criterion.

### Forward evidence

All targets whose entry or exit enters 2026 remain outside this hypothesis
card's confirmation surface. No paper-trading or live behavior is opened.

## Primary uncertainty and confirmation criterion

Daily 25-session targets overlap, so ordinary independent-row Pearson or OLS
uncertainty is not admissible as primary evidence.

Freeze a seeded stationary-block bootstrap of the ordered daily
predictor-target rows:

- 10,000 resamples;
- expected block length: 50 sessions;
- deterministic seed: `20260821`;
- percentile 90% interval for `beta`;
- complete eligible rows only, with no imputation.

The single principal locked-confirmation criterion is:

> `beta > 0` and the 90% stationary-block-bootstrap lower bound for `beta` is
> strictly greater than zero.

All data-integrity checks must also pass for the result to be interpretable.
They are validity requirements, not additional evidence gates.

## Required diagnostics

Diagnostics explain the primary estimate and do not form a conjunctive
promotion ladder:

1. Scatter and fitted line for `X_t` versus `Y_t,25`.
2. Equal-count predictor-quintile conditional means with support and
   uncertainty.
3. Top-minus-bottom predictor-quintile target contrast.
4. Past-sign/future-sign confusion matrix and directional accuracy.
5. Unconditional target mean and positive-target frequency.
6. Calendar-year slope, support, and contribution concentration.
7. Twenty-five phase-offset views using nonoverlapping target windows within
   each phase, reported as sensitivity rather than independent replications.
8. Two thousand seeded circular-shift controls that preserve each series'
   internal order while breaking contemporaneous predictor-target alignment;
   shifts shorter than 250 sessions are excluded.
9. A fixed horizon-decay diagnostic at future horizons `5`, `10`, `25`, and
   `60`, with `25` remaining the sole primary target and no alternate horizon
   eligible for promotion under `01.3`.

The ordinary OLS slope and nominal p-value may be shown as teaching
statistics, clearly labeled non-authoritative.

## Hard validity checks

Stop without interpreting prediction if any of the following occurs:

- missing or duplicate sessions inside a requested interval that are not
  explained by the exchange calendar;
- nonpositive or nonfinite required adjusted prices;
- an anchor lacking exactly 250 prior sessions or 25 future open intervals;
- target endpoints outside the declared evidence zone;
- rows dated after the explicit as-of timestamp;
- predictor or target values that disagree with an independently recomputed
  fixture;
- bootstrap replay that is not deterministic under the frozen seed; or
- fewer than 400 eligible daily anchors in the locked confirmation zone.

## Interpretation map

- **Positive predictive evidence:** the locked confirmation criterion passes.
  This may open discussion of a separate monetization contract; it does not
  establish tradability.
- **Positive but uncertain:** `beta > 0`, but its lower bound is not above
  zero. Record the estimated magnitude and uncertainty; do not construct a
  strategy from the same sample.
- **Null:** the slope is economically small and uncertainty includes zero.
- **Reversal-shaped:** `beta < 0`. Record evidence against the directional
  momentum alternative; do not reverse the strategy without a new hypothesis.
- **Sandbox positive, confirmation null:** record failed temporal transport
  and stop the lane.
- **Drift or alignment explained:** positive conditional returns without a
  positive slope, monotone conditional curve, or unusual circular-shift
  placement are not incremental momentum evidence.
- **Concentrated or unstable:** retain the primary result but label its
  dependence on a small number of dates, years, or phase offsets. Diagnostics
  explain evidence; they do not silently replace the frozen criterion.

## Explicitly closed work

This card authorizes no data query or outcome calculation by itself. It also
does not authorize:

- a 49-cell or other horizon search;
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
- fixes Chan's canonical `250/25` horizon before outcomes;
- changes the primary target from close-to-close screening return to a
  causally attainable next-open-to-exit-open return;
- changes the primary question from strategy performance to a continuous
  predictor-target slope; and
- replaces a multi-gate promotion surface with one confirmation criterion and
  an interpretation-oriented diagnostic map.
