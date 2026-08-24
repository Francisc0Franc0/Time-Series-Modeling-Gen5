# HYP-IMOM-04.1 CAL-A02 TSLA Direct-Exposure Plan

Status: `CAL_A02_COMPLETE_STOP_DIRECT_EXPOSURE_GATES_FAILED_CONFIRMATION_NOT_READ`

Attempt: `CAL-A02`

Outcome zone: `OUTCOME_AWARE_REUSED_CALIBRATION`

Frozen: `2026-08-23`

## Narrative hypothesis

TSLA's positive open-to-open returns may persist when a completed session shows
an established upward state, efficient directional progress, contained
downside volatility, and positive relative strength. When those conditions are
absent, cash may have higher expected utility.

This is not a rescue of the stopped `CAL-A01` crossover-permission atlas.
`CAL-A01` could only reject fresh SMA8/SMA14 entries while preserving the
parent exit. `CAL-A02` asks the different, continuous state question: after
each completed session, should the next executable open-to-open interval be
long TSLA or cash?

## Evidence boundary

- Provider: Alpaca SIP archive cache.
- Bar type: adjusted 30-minute regular-session OHLCV.
- Symbols: TSLA, QQQ, SPY, and SMH.
- Prehistory: calendar 2017 only for causal rolling features.
- Outcome-aware calibration: `2018-01-02` through `2023-12-29`.
- Chronological out-of-fold scoring: 2021Q1 through 2023Q4.
- Fresh transport: `2024-01-02` onward, sealed and unread.
- Explicit as-of timestamp: `2026-08-13 17:30:00 America/New_York`.

No 2024+ bar may enter source audit, feature construction, model fitting,
thresholding, controls, policy replay, reporting, or plotting.

## Decision clock and target

For completed session `t`:

1. Build all features from information available by the regular-session close
   of `t`.
2. Set the position at the open of session `t+1`.
3. Hold that position until the open of session `t+2`.
4. If adjacent decisions are both long, remain invested and do not manufacture
   an intervening exit and re-entry cost.

The regression target is the gross log return from the open of `t+1` to the
open of `t+2`. The executable policy uses the corresponding simple return.
TRAIN rows whose target interval reaches an OOF fold are embargoed.

The primary permission threshold is frozen at the round-trip primary-cost
buffer:

`predicted gross log return > -2 * log(1 - 0.001)`

The primary cost is 10 bp per side and the stress cost is 20 bp per side. No
prediction threshold is selected from market outcomes.

## Frozen causal feature atlas

Every model uses the same complete-case session ledger and these twelve main
features:

| ID | Feature | Construction at completed session `t` |
|---|---|---|
| `T200` | TSLA slow trend | close divided by SMA200 minus one |
| `A2050` | TSLA trend alignment | SMA20 divided by SMA50 minus one |
| `E20` | daily path efficiency | absolute 20-session displacement divided by total absolute daily path |
| `IE5` | intraday path efficiency | five-session mean of absolute open-close displacement divided by absolute 30-minute path |
| `DD63` | rolling drawdown | close divided by rolling 63-session high minus one |
| `DS20` | downside variance share | negative squared daily returns divided by total squared daily returns over 20 sessions |
| `VOV20` | volatility-of-volatility | 20-session standard deviation of absolute daily log returns |
| `RV20` | relative volume | log current volume divided by the prior-20-session median |
| `RSQ20` | QQQ-relative strength | TSLA minus QQQ 20-session log return |
| `RSS20` | SMH-relative strength | TSLA minus SMH 20-session log return |
| `QT200` | QQQ slow trend | QQQ close divided by SMA200 minus one |
| `ST200` | SMH slow trend | SMH close divided by SMA200 minus one |

The primary ridge model also receives four frozen interactions:

- `T200 * E20`;
- `T200 * DS20`;
- `RSQ20 * QT200`;
- `IE5 * RV20`.

All rolling calculations include only completed observations. No feature may
be re-windowed, redirected, dropped, or added after CAL-A02 outcomes are read.

## Frozen models

### `R1` — primary ridge return regressor

- Base-R linear ridge regression.
- TRAIN-only centering and scaling.
- Intercept is unpenalized.
- Lambda grid: `0.1, 1, 10, 100, 1000`.
- Lambda is chosen by expanding chronological inner validation using mean
  squared error.
- The model is refit on all eligible TRAIN rows after lambda selection.

### `T1` — secondary shallow interaction challenger

- Base-R depth-two regression tree.
- Main features only.
- Candidate split quantiles: 25%, 50%, and 75%.
- Minimum root-child support: 60 observations.
- Minimum terminal-leaf support: 30 observations.
- Leaf predictions are TRAIN means.

`R1` remains primary regardless of whether `T1` has the better observed point
estimate. `T1` is a prespecified nonlinear diagnostic, not a post-outcome
selector.

### Baselines and diagnostic ceiling

- `B0`: fold-specific TRAIN mean return.
- `B1`: always-long TSLA over the same executable open-to-open intervals.
- `B2`: hand rule long when `T200 >= 0`, otherwise cash.
- `CASH`: zero exposure.
- `ORACLE`: infeasible long permission when the realized forward gross log
  return exceeds the same primary round-trip cost buffer. The oracle is a
  diagnostic ceiling only and can never confer strategy evidence.

## Chronological scoring

Produce twelve expanding quarterly OOF folds from 2021Q1 through 2023Q4.
For each fold:

- TRAIN contains only rows whose executable exit open precedes the fold;
- transformations, ridge lambda, tree splits, and leaf means use TRAIN only;
- the complete quarter is scored without refitting;
- model predictions and permissions are written to an auditable ledger.

Primary predictive evidence is OOF mean-squared-error improvement versus `B0`.
MAE, correlation, coefficients, tree structure, and quarterly behavior are
diagnostics.

## Policy and capture metrics

Replay the complete 2021-2023 OOF sequence with continuous position accounting.
Costs occur only on `0 -> 1` entries and `1 -> 0` exits. Report:

- gross, 10 bp/side, and 20 bp/side total return;
- maximum drawdown;
- exposure;
- entry count and annualized one-way turnover;
- upside capture: fraction of aggregate positive TSLA interval returns held;
- downside capture: fraction of aggregate absolute negative TSLA interval
  returns held;
- quarterly positive-return count;
- representative rising, falling, sideways-rally, and whipsaw exposure tapes.

The benchmark comparison must not reward a model merely for remaining in cash.

## Positive controls and falsification

Before market labels are interpreted:

1. A planted linear synthetic case must be recovered by `R1` out of sample.
2. A planted two-feature conjunction must be recovered by `T1` out of sample.
3. The oracle must produce the expected executable ceiling under the same
   policy accounting.

Market falsification uses:

- 200 whole-session circular shifts of the target; both registered models are
  refit, and the null statistic is the best MSE improvement across `R1` and
  `T1` in each shifted world;
- 200 within-fold circular shifts of the primary permission sequence, which
  preserve exposure and local run structure while breaking date alignment;
- primary and stress costs;
- chronological quarter stability.

## Frozen gates

CAL-A02 may earn `CALIBRATION_PATTERN_PRESENT_FRESH_TRANSPORT_STILL_CLOSED`
only if every gate passes:

1. source integrity, exact calendars, and no 2024+ read;
2. both planted model controls and oracle accounting pass;
3. `R1` has positive OOF MSE improvement versus `B0`;
4. `R1` exceeds the familywise whole-session-shift p90;
5. primary-cost total return is positive and exceeds always-long TSLA;
6. primary-cost maximum drawdown is shallower than always-long TSLA;
7. upside capture is at least 60%;
8. downside capture is at most 40%;
9. OOF exposure is between 20% and 80%;
10. at least 8 of 12 OOF quarters are positive after primary costs;
11. primary-cost total return exceeds the p90 matched-permission control.

Failure of any gate records
`STOP_CAL_A02_DIRECT_EXPOSURE_GATES_FAILED_CONFIRMATION_NOT_READ`.

## Stop discipline

- Do not inspect 2024+ because CAL-A02 looks promising in TRAIN or OOF.
- Do not alter the target horizon, decision time, cost buffer, feature windows,
  interaction list, lambda grid, tree depth, capture thresholds, or gates after
  reading CAL-A02 outcomes.
- A future outcome-aware change becomes `CAL-A03` with its own frozen contract.
- Fresh transport requires a separate operator decision even if all gates pass.

## Execution decision

`CAL-A02` completed on `2026-08-23` and stopped before fresh transport. The
primary ridge model failed 6 of 11 frozen gates, including predictive loss,
familywise falsification, return dominance, downside capture, quarterly
stability, and matched-permission p90. The separately prespecified depth-two
tree produced an interesting positive compounded return but remained a
diagnostic: its proper-score loss trailed drift, it captured most downside, and
its root feature changed repeatedly across folds. Preserve that observation
for a separately contracted question; do not promote or tune it inside
`CAL-A02`.

See
[CAL-A02 results](HYP_IMOM_04_1_CAL_A02_TSLA_DIRECT_EXPOSURE_RESULTS.md).
