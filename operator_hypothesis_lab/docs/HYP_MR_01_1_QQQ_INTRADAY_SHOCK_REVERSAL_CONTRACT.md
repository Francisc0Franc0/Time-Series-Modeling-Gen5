# HYP-MR-01.1 QQQ Intraday-Shock Reversal Contract

Status: `STOP_HYP_MR_01_1_DEVELOPMENT_REVERSAL_GATES_FAILED_CONFIRMATION_NOT_RUN`

Date frozen: `2026-08-22`

Outcome recorded: `2026-08-22`

The frozen TRAIN model passed all six gates: beta `-0.00165345`, Spearman
`-0.093618`, positive loss improvement in all three expanding folds, and
pooled improvement above the complete 887-shift p90. That pass authorized the
predeclared DEVELOPMENT read. The unchanged model then lost to drift overall,
with Spearman `-0.002767`, loss improvement `-3.9104e-07`, bootstrap
P(improvement > 0) `0.3167`, and only one positive year. Confirmation remained
sealed.

## Identity and boundary

`HYP-MR-01.1` is a new predictor-only mean-reversion concept. It is not a
sign inversion or rescue of any stopped momentum identifier. It changes the
economic mechanism, predictor decomposition, and target: a completed QQQ cash
session is used to forecast the next cash session.

No strategy, position rule, return threshold, P&L, Sharpe, drawdown,
allocation, leverage, confirmation read, or live behavior is authorized.

## Narrative hypothesis

An unusually large QQQ open-to-close move can contain temporary liquidity or
positioning pressure. Relative to the volatility known before that session,
the signed move should predict an opposite-signed open-to-close return during
the next session.

The registered direction is negative:

`beta < 0` in `E[Y[t+1] | X[t]] = alpha + beta * X[t]`.

## Source and evidence partitions

- Provider: canonical Gen5 Alpaca adjusted-daily cache.
- Instrument: `QQQ` only.
- Bars: adjusted daily OHLCV.
- Explicit as-of timestamp: `2026-08-22 17:30:00 America/New_York`.
- Query warm-up start: `2016-01-04`.
- TRAIN anchors and next-session targets: `2017-01-03` through `2020-12-31`.
- Conditional DEVELOPMENT anchors and targets: `2021-01-04` through
  `2023-12-29`.
- Sealed confirmation: `2024-01-02` through `2025-12-31`.
- No 2026 bar may enter a feature, target, fit, diagnostic, plot, or decision.

The runner must query only through TRAIN first. DEVELOPMENT may be queried only
after every frozen TRAIN gate passes. Confirmation remains unread even after a
DEVELOPMENT pass.

## Causal predictor

For session `t`, define true range:

`TR[t] = max(high[t] - low[t], abs(high[t] - close[t-1]), abs(low[t] - close[t-1]))`.

The normalization excludes the current session:

`ATR20_prior[t] = mean(TR[t-20], ..., TR[t-1])`

`ATRpct20_prior[t] = ATR20_prior[t] / close[t-1]`.

The one registered predictor is:

`X[t] = log(close[t] / open[t]) / ATRpct20_prior[t]`.

All quantities are known after session `t` closes. The current session's range
cannot damp or inflate its own normalization.

## Forward target and timing

The one registered target is:

`Y[t+1] = log(close[t+1] / open[t+1])`.

The signal is complete after close `t`. Any later policy would begin no earlier
than open `t+1`; this slice does not construct such a policy.

## Registered model and benchmark

The primary model is ordinary least squares:

`REVERSAL: Y = alpha + beta * X + error`.

The only benchmark is fitted on the same training rows:

`DRIFT: Y = alpha + error`.

No regularization, nonlinear term, threshold, interaction, alternate feature,
alternate target, classifier, or model family may be inspected under this
identifier.

## TRAIN expanding-fold forecast

Generate genuine one-year-ahead TRAIN predictions:

- fit through `2017-12-31`, score calendar `2018`;
- fit through `2018-12-31`, score calendar `2019`;
- fit through `2019-12-31`, score calendar `2020`.

Each fold independently fits both `REVERSAL` and `DRIFT`. The primary forecast
statistic is the pooled scored-row improvement:

`mean(SE_DRIFT - SE_REVERSAL)`.

Positive values favor the registered regressor.

## Timing falsification control

The complete timing family contains every circular shift of `Y` whose minimum
circular displacement is at least 60 rows.

For every admissible shift:

1. rotate the full TRAIN target vector relative to dates and `X`;
2. rerun all three expanding folds;
3. record pooled `mean(SE_DRIFT - SE_REVERSAL)`.

The search-adjusted hurdle is the type-7 90th percentile of this complete null.
The empirical upper-tail probability uses the plus-one correction.

## Influence audit

The primary model retains every valid row. A predeclared sensitivity removes
the largest 1% of observations by `abs(X)` using the type-7 99th percentile,
then refits the full-TRAIN slope. The sensitivity may not replace the primary
estimate. It exists to prevent a few extreme sessions from supplying the
registered direction.

## TRAIN gates

TRAIN passes only if all six gates hold:

1. at least 900 valid TRAIN anchors exist;
2. the full-TRAIN OLS slope is negative;
3. the full-TRAIN Spearman correlation is negative;
4. pooled expanding-fold MSE improvement over `DRIFT` is positive;
5. at least two of three calendar folds have positive MSE improvement;
6. pooled improvement is strictly above the circular-shift p90, and the
   influence-excluded slope remains negative.

The final item is conjunctive: both timing specificity and influence-sign
stability must hold. Descriptive deciles and Pearson correlation cannot rescue
a failed gate.

If any gate fails, record
`STOP_HYP_MR_01_1_TRAIN_REVERSAL_GATES_FAILED`, query no DEVELOPMENT outcome,
and preserve confirmation.

## Conditional DEVELOPMENT gates

After a complete TRAIN pass, freeze the full-TRAIN coefficients and predict the
same one-step target on `2021-2023` rows. DEVELOPMENT passes only if:

1. at least 600 valid rows exist;
2. the DEVELOPMENT Spearman correlation is negative;
3. frozen `REVERSAL` MSE is below frozen `DRIFT` MSE;
4. a 10,000-replicate stationary bootstrap with expected block length 20 and
   seed `110101` assigns at least 90% probability to positive loss improvement;
5. at least two of the three calendar years have positive loss improvement.

A pass ends in
`DEVELOPMENT_PASS_HYP_MR_01_1_CONFIRMATION_REVIEW_REQUIRED`. It does not open
confirmation.

## Source and construction gates

Before outcomes are interpreted, require:

- exact QQQ identity, strict date order, and unique sessions;
- adjusted `1D` bars only;
- positive finite OHLCV;
- query-start and requested-end coverage;
- maximum observed date no later than the requested evidence boundary;
- positive finite prior-only ATR normalization;
- exact next-session target alignment;
- no feature or target overlap across the signal boundary.

A stale-cache warning is harmless only when the deliberately historical
requested range is fully covered; the packet must say so explicitly.

## STOP discipline

Under this identifier, do not:

- change QQQ, the 20-session prior-only ATR, or the one-session target;
- use close-to-close, overnight, open-to-open, first-hour, or multi-day targets;
- add thresholds, nonlinearities, interactions, filters, weekdays, regimes, or
  other predictors;
- select a classifier after seeing regression results;
- delete or winsorize observations beyond the registered influence audit;
- invert a positive slope into continuation;
- inspect nearby dates or confirmation after a STOP;
- reinterpret forecast evidence as a trading strategy.

Any such question requires a new narrative, identifier, contract, and fresh
evidence boundary.

## Required artifacts

- frozen contract and run specification;
- source, coverage, integrity, and causal-construction audits;
- full-TRAIN model statistics and expanding-fold predictions;
- complete circular-shift null and TRAIN gate table;
- influence audit and predictor-decile diagnostic;
- representative large-shock event panels;
- conditional DEVELOPMENT evidence or an explicit unread marker;
- explicit confirmation unread marker;
- readable results report and progress-log update.
