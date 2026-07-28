# LIT-MR-02.1 Adaptive Spread Bollinger POC Contract

Status: `FROZEN_APPROVED_FOR_IMPLEMENTATION`

## Source proposition

Chan's *Algorithmic Trading*, Example 3.2, applies Bollinger thresholds to the
adaptive price spread from Example 3.1 rather than to either asset alone:

`spread_t = USO_close_t - beta_t * GLD_close_t`

where `beta_t` is the slope from a trailing 20-session OLS regression:

`USO_close ~ intercept + beta * GLD_close`

The strategy standardizes that evolving spread over 20 sessions, enters at
`|z| > 1`, and exits at the rolling mean (`z = 0`).

## Price versus log price

`LIT-MR-02.1` uses adjusted price levels, not log prices.

This is both source-faithful and a substantive frozen choice. Example 3.1
tests raw-price spread, log-price spread, and ratio separately; Example 3.2
explicitly reuses the raw-price-spread program. A log-price or ratio strategy
would be a new concept or substantive variant, not an implementation detail.

Adjusted prices are required because USO has undergone corporate actions. The
signal uses adjusted closes and execution uses adjusted opens from the same
Alpaca adjusted-daily bar contract.

## Frozen question

On post-publication-era daily data, does the exact adaptive GLD-USO spread
produce sufficiently frequent, stable, cost-surviving Bollinger convergence
on TRAIN to justify opening later outcomes and portfolio evidence?

## Data and evidence partitions

- Provider: Alpaca.
- Bars: adjusted daily OHLCV.
- Explicit as-of: `2026-07-24 17:30:00 America/New_York`.
- Query window: `2016-01-04` through `2026-07-24`.
- Warm-up: the first 39 common sessions form the nested rolling estimates and
  cannot generate a trade.
- TRAIN: `2016-01-04` through `2020-12-31`.
- DEVELOPMENT: `2021-01-01` through `2023-12-31`.
- CONFIRMATION: `2024-01-01` through `2026-07-24`.

Only TRAIN is opened initially. If any TRAIN gate fails, later prices are not
joined to the strategy state and no DEVELOPMENT or CONFIRMATION result exists.

Coverage note: an initial request for September-December 2015 warm-up returned
no bars from the operator's Alpaca historical path and remained
`partial_history` after refresh. Moving the query boundary to the first
available common session changes no observed bar, signal, trade, or evidence
partition; it removes only the unfulfillable request.

## Frozen signal mechanics

For each completed session `t`:

1. Fit OLS on the trailing 20 adjusted closes, including `t`.
2. Record intercept and slope; require a finite positive slope.
3. Compute `spread_t = USO_close_t - beta_t * GLD_close_t`. The fitted
   intercept is not subtracted, matching the book's traded-spread convention.
4. Compute the trailing 20-session mean and sample standard deviation of the
   dynamically estimated spread.
5. Compute `z_t = (spread_t - mean_t) / sd_t`.

State transitions:

- flat and `z_t < -1`: enter long spread;
- flat and `z_t > +1`: enter short spread;
- long spread and `z_t >= 0`: exit;
- short spread and `z_t <= 0`: exit;
- otherwise carry the current state.

An exit does not reverse on the same close. A new opposite entry requires a
later completed-session signal.

## Timing and holdings

- Signal and target hedge ratio are known only after the close.
- State and hedge changes execute at the next session's adjusted open.
- Long spread means long one USO share and short `beta_t` GLD shares.
- Short spread means the opposite.
- At every execution open, the two share legs are normalized to 100% gross
  market value. Net exposure is allowed to vary.
- While a trade remains open, the rolling hedge ratio is updated after each
  close and rebalanced at the next open, matching the adaptive source concept.
- If beta or z becomes invalid, the next-open target is flat.
- No stop loss, profit target, maximum hold, volatility target, leverage, or
  same-day execution is permitted.

## Costs and borrow boundary

Primary:

- 5 bp per one-way change in gross portfolio weight;
- no imputed historical borrow fee.

Stress:

- 10 bp per one-way change in gross portfolio weight;
- 100 bp annualized on realized short gross.

Turnover includes entries, exits, and daily adaptive-hedge rebalancing.
Historical borrow availability is unknown. This POC cannot establish that
every historical short could have been located.

## Statistical diagnostics

TRAIN reports, but does not turn into a three-way classifier:

- static Engle-Granger-style residual ADF t-statistic;
- dynamic-spread AR(1) coefficient and implied half-life when defined;
- 5- and 20-session variance ratios;
- correlation between signal z-score and the next five-session fixed-beta
  spread return.

These diagnostics describe different null hypotheses. None alone proves that
the implemented trading rule is profitable.

## Frozen inference

- 2,000 moving-block bootstrap draws over completed TRAIN trades;
- seed `5801`;
- block length `4` trades;
- 2,000 moving-block draws for the overlapping five-session convergence
  diagnostic, seed `5803`, block length `20` sessions;
- 2,000 matched-timing random-sign policies;
- seed `5802`;
- random-control hurdle: p90.

The random-sign control preserves trade timing, holding periods, gross pair
path, and estimated costs while breaking the mapping from z-score sign to
trade direction.

## TRAIN gates

All eight must pass:

1. all frozen data, timing, position, partition, and accounting checks pass;
2. at least 95% positive-beta indicator coverage after warm-up;
3. at least 30 completed trades, including at least 10 long-spread and 10
   short-spread trades;
4. primary-cost mean net trade return is positive and its 95% moving-block
   bootstrap lower bound is above zero;
5. completed-trade hit rate is above 50%;
6. observed mean net trade return exceeds the matched random-sign p90;
7. primary-cost bar return is positive in at least three of five TRAIN
   calendar years; and
8. z-score versus next-five-session fixed-beta spread-return correlation is
   negative and its 95% moving-block-bootstrap upper bound is below zero.

If any gate fails, return `STOP_LIT_MR_02_1_TRAIN_MECHANISM`. DEVELOPMENT,
CONFIRMATION, full portfolio replay, and later-period Sharpe/drawdown remain
structurally unopened.

## Conditional later evidence

Only after all TRAIN gates pass:

- replay the frozen rule without retuning;
- report trade-level and bar-level results separately;
- report primary and stress costs;
- report naive and autocorrelation-adjusted Sharpe, maximum drawdown,
  drawdown duration, exposure, turnover, and long/short contribution;
- require positive mean net trade return in both DEVELOPMENT and CONFIRMATION;
- require CONFIRMATION to beat its random-sign p90;
- require positive CONFIRMATION stress-cost return; and
- require positive CONFIRMATION contribution in at least two calendar years.

Failure returns `STOP_LIT_MR_02_1_LATER_REPLICATION`.

## Prohibited rescue

After inspection, do not change:

- GLD-USO;
- raw price to log price or ratio;
- the 20-session estimator or standardization window;
- `+/-1` entry or zero exit;
- the rolling hedge convention;
- costs, bootstrap, random control, or evidence partitions; or
- the TRAIN gates.

Any such proposal needs a substantive new identifier and fresh contract.
