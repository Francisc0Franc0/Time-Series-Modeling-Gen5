# HYP-IMOM-03.1 SMH-to-QQQ First-Hour Lead-Lag Contract

Status: `EXECUTED_TRAIN_STOP_DEVELOPMENT_AND_CONFIRMATION_UNREAD`

Date frozen: `2026-08-22`

## Narrative hypothesis

When semiconductors outperform QQQ during the first hour of the regular
session, the broader growth complex has not fully incorporated that leadership
by 10:30 ET. QQQ should therefore outperform SPY over the remainder of the
same session after controlling for QQQ's and SPY's own first-hour moves.

This is a cross-asset intraday lead-lag question. It is not a continuation of
the stopped daily QQQ/equal-weight test, not an ETF trading policy, and not a
claim that semiconductor holdings are absent from QQQ.

## Evidence boundary

| Zone | Inclusive dates | Authority |
|---|---|---|
| Prehistory | `2017-09-01` through `2017-12-29` | Lag construction only |
| TRAIN | `2018-01-02` through `2020-12-31` | Model fitting and frozen gate evaluation |
| DEVELOPMENT | `2021-01-04` through `2022-12-30` | Read only if every TRAIN gate passes |
| CONFIRMATION | `2023-01-03` through `2023-12-29` | Sealed in this slice regardless of outcome |

The explicit as-of timestamp is `2026-08-22 17:30:00 America/New_York`.
No observation dated 2024 or later may be queried or loaded.

## Source and calendar contract

- Provider: Alpaca historical stock bars.
- Feed: `sip`.
- Timeframe: `30Min`.
- Adjustment: `all`.
- Symbols: `SMH`, `QQQ`, and `SPY` only.
- Scope: regular trading hours only.
- Normal sessions require slots `1:13`; admitted early closes require `1:7`,
  including the `2017-11-24` prehistory session.
- The ten previously documented Alpaca SIP archive-gap sessions are excluded
  globally for all three symbols without imputation.
- All symbols must have identical timestamps after the shared calendar rules.
- Duplicate timestamps, nonfinite OHLCV, nonpositive prices, or incomplete
  required slots are hard failures.

The return-blind inventory found exact common calendars after these rules:
`248`, `250`, `253`, `250`, `248`, and `250` sessions in 2018 through 2023.

## Causal construction

For symbol `j` and session `t`, the first-hour return is:

`fh(j,t) = log(close(j,t,slot2) / open(j,t,slot1))`.

The frozen semiconductor-leadership predictor is:

`x_lead(t) = fh(SMH,t) - fh(QQQ,t)`.

The signal becomes known only after slot 2 completes at 10:30 ET. The target
begins at slot 3's open, never at a first-hour price:

`rem(j,t) = log(close(j,t,last_regular_slot) / open(j,t,slot3))`.

The frozen target is:

`y(t) = rem(QQQ,t) - rem(SPY,t)`.

Early closes use slot 7 as the terminal close. The construction contains no
overnight return and no overlap between the signal bars and target bars.

## Frozen controls and placebo

Every design includes an intercept plus Tuesday-through-Friday indicators,
with Monday as reference. The four models are:

1. `DOW_DRIFT`: weekday-aware intercept only.
2. `OWN_MARKET`: weekday terms plus `fh(QQQ,t)` and `fh(SPY,t)`.
3. `LEADER`: `OWN_MARKET` plus `x_lead(t)`.
4. `WRONG_CLOCK`: `OWN_MARKET` plus `x_lead(t-1)`, the immediately prior
   admitted session's first-hour leadership.

The prior-session placebo is causal and uses the same assets and units while
breaking the proposed same-session transmission clock. It is fixed before any
return result is read. No wrong-leader ETF, alternative clock, residualization,
threshold, sign flip, or nearby window may be added under this identifier.

## TRAIN evaluation

There is one signal window and one target window, so there is no horizon or
asset search and no family-wise maximum-statistic adjustment.

TRAIN uses two expanding, time-ordered outer folds:

- fit 2018, score 2019;
- fit 2018–2019, score 2020.

Ordinary least squares is fitted separately for each frozen model. All models
are scored on identical out-of-fold sessions using mean squared error and mean
absolute error. The all-TRAIN `LEADER` coefficient supplies the economic-sign
check.

For the daily squared-loss improvement
`OWN_MARKET error^2 - LEADER error^2`, a deterministic stationary bootstrap
uses seed `731031`, `2,000` replicates, and expected block length `10` sessions.

TRAIN passes only if all gates hold:

1. at least `450` common scored sessions;
2. the all-TRAIN `x_lead` coefficient is strictly positive;
3. `LEADER` out-of-fold MSE is strictly below `OWN_MARKET` MSE;
4. `LEADER` out-of-fold MAE is strictly below `OWN_MARKET` MAE;
5. `LEADER` out-of-fold MSE is strictly below `WRONG_CLOCK` MSE; and
6. the stationary-bootstrap 10th percentile of mean squared-loss improvement
   is strictly positive.

Failure of any gate records
`STOP_HYP_IMOM_03_1_TRAIN_LEAD_LAG_GATES_FAILED` and leaves DEVELOPMENT and
CONFIRMATION unread.

## Locked DEVELOPMENT rule

Only after a complete TRAIN pass may the models be refit once on all TRAIN
sessions and scored, without modification, on 2021–2022 DEVELOPMENT.
DEVELOPMENT passes only if `LEADER` beats `OWN_MARKET` on MSE and MAE, beats
`WRONG_CLOCK` on MSE, has a strictly positive 10th-percentile stationary-
bootstrap loss improvement, and the mean target in the top quartile of
`x_lead` exceeds the mean target in the bottom quartile. Those quartile
thresholds are estimated once from TRAIN and then applied unchanged to
DEVELOPMENT.

A DEVELOPMENT pass records evidence for discussion only. It does not open
2023 confirmation, a strategy, a threshold, P&L, allocation, leverage, or live
behavior.

## STOP and interpretation rules

- A wrong-sign or null result rejects this exact same-session transmission
  specification; it does not establish reversal.
- Overlapping SMH/QQQ holdings are a reason for the QQQ first-hour control,
  not permission to redefine the signal after inspection.
- The provider-gap exclusions remain a common-calendar condition and may not
  be selectively restored.
- No trade timing, costs, returns, Sharpe, drawdown, or portfolio metrics are
  part of this predictor test.

## Final readout

Execution stopped at TRAIN under
`STOP_HYP_IMOM_03_1_TRAIN_LEAD_LAG_GATES_FAILED`. The all-TRAIN leadership
coefficient was `-0.006352`; the same-session signal failed MSE, wrong-clock,
and bootstrap gates. DEVELOPMENT and confirmation remained unread.
