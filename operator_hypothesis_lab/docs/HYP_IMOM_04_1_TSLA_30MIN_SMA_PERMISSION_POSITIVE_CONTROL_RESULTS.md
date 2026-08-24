# HYP-IMOM-04.1 TSLA 30-Minute SMA Permission Positive-Control Results

Status: `STOP_CALIBRATION_GATES_FAILED_FRESH_CONFIRMATION_NOT_READ`

Attempt: `CAL-A01`

Outcome zone: `OUTCOME_AWARE_REUSED_CALIBRATION`

Date completed: `2026-08-23`

## Question

Can six causal state and entry-quality features, plus three frozen two-feature
AND gates, identify fresh TSLA 30-minute SMA8/SMA14 crossovers whose expected
move survives explicit costs?

This was a deliberately outcome-aware positive-control exercise. A favorable
retrospective TSLA result could demonstrate the shape of a functioning
permission model, but it could not establish independent discovery. The
separately reserved 2024+ transport window remained unread.

## Frozen construction

The unchanged HYP-IMOM-01.1 parent supplied every entry and exit:

- adjusted Alpaca SIP 30-minute regular-session bars;
- fresh completed-bar SMA8-above-SMA14 crosses;
- next-bar-open entry and the unchanged next-bar-open parent exit;
- annual cash-start and flat-end blocks;
- 1x replay with 10 bp/side primary and 20 bp/side stress costs;
- no alternate entry after a rejected parent event.

`CAL-A01` attached six causal features to one parent-event ledger: prior-day
TSLA distance above SMA200, prior-day ATR14/close percentile, completed-bar
crossover impulse, prior-26-bar whipsaw count, same-slot dollar-volume
surprise, and prior-day QQQ distance above SMA200. It also froze three AND
gates: trend plus ATR%, impulse plus low whipsaw, and trend plus participation.

Every candidate used the same complete-case events, expanding quarterly
2021-2023 scoring, TRAIN-only monotone threshold fitting, minimum leaf support,
an intercept probability comparator, 200 matched random permissions, and 200
whole-session shifts whose null statistic was the best result across all nine
variants.

## Integrity and positive-control engine

All source and parent-reproduction checks passed.

- The source stopped at `2023-12-29`; no 2024+ bar was read.
- All 727 TSLA parent events from 2018-2023 reproduced the earlier parent trade
  identities and 10 bp/side returns exactly.
- The common feature ledger contained 637 eligible events. ATR14/252 history
  was the binding prehistory requirement, so the first complete event occurred
  on `2018-10-01`; every 2019-2023 parent event was feature-complete.
- Feature-only correlation showed that most candidates supplied distinct
  measurements. The largest relationship was TSLA versus QQQ daily trend at
  Spearman `0.704`; ATR percentile versus crossover impulse was `0.292`.

Before TSLA labels were scored, the engine recovered all nine separately
planted synthetic cases, including the three interactions. The experiment
therefore produced a worked **synthetic** positive control even though the
market calibration did not.

## Predictive readout

The nominal selector was the prior-day TSLA trend feature, `T`.

| Measure | Readout |
|---|---:|
| Chronological OOF events | 359 |
| OOF Brier improvement versus fold intercept | `0.000943` |
| Familywise session-shift percentile | `66.5%` |
| Familywise p90 Brier improvement | `0.003001` |
| Permitted events | 72 |
| OOF participation | `20.1%` |
| Permitted win rate | `38.89%` |
| Rejected win rate | `37.63%` |
| Permitted mean net trade | `+0.028%` |
| Rejected mean net trade | `+0.312%` |
| All-parent mean net trade | `+0.255%` |

The small proper-score improvement did not survive the atlas-level timing
control and pointed in the wrong economic direction. The supposedly favorable
leaf had a slightly higher win rate but much smaller average net return than
the rejected leaf.

The threshold was also operationally unstable. TRAIN-selected distance-above-
SMA200 thresholds ranged from about `+11.3%` to `+74.7%`. The rule permitted no
event in six of the twelve scored quarters and only 20.1% overall, despite the
25% TRAIN participation floor. This was not an admissible stable permission
surface.

No other feature repaired the result. Only `T_AND_P` had another positive
Brier point estimate, `0.000357`, but it permitted 14.2% of events and also had
negative permitted-versus-rejected return separation. ATR%, crossover impulse,
participation, market alignment, and the trend-plus-ATR gate all trailed the
intercept on Brier loss. The whipsaw-only and impulse-plus-whipsaw rules returned
no admissible permission in the scored folds.

## Policy readout

| Policy/scenario | 2021-2023 return | Maximum drawdown | Exposure | Mean annual turnover | Trades |
|---|---:|---:|---:|---:|---:|
| Selected `T`, gross | `+14.12%` | `-22.93%` | `9.62%` | `48.59x` | 72 |
| Selected `T`, 10 bp/side | `-1.19%` | `-29.35%` | `9.62%` | `48.37x` | 72 |
| Selected `T`, 20 bp/side | `-14.46%` | `-35.37%` | `9.62%` | `48.15x` | 72 |
| Selected `T`, one-bar delay | `-1.46%` | trade-close `-23.97%` | — | — | 72 |
| Unfiltered parent, 10 bp/side | `+91.32%` | `-48.78%` | `50.57%` | `239.28x` | 359 |
| Hand rule `T >= 0`, 10 bp/side | `+34.00%` | `-44.75%` | `29.53%` | `150.05x` | 214 |

The model successfully reduced turnover and drawdown, but it mostly removed
profitable exposure rather than selectively removing bad trades. Its primary-
cost total return ranked at only the `3.5th` percentile of 200 matched random
permissions; the matched-random p90 was `+96.98%`.

The unfiltered TSLA parent was unusually profitable during this reused period,
which explains why TSLA had seemed like a plausible positive control. The
experiment shows that remembered asset-level success is not equivalent to a
known feature-level permission mechanism.

## Gate decision

`CAL-A01` passed 3/8 frozen calibration gates:

- PASS: source and parent integrity;
- PASS: nine-of-nine synthetic recovery;
- PASS: positive nominal Brier improvement;
- FAIL: permitted-versus-rejected economic separation;
- FAIL: positive and parent-improving selected policy;
- FAIL: matched-random p90;
- FAIL: familywise whole-session-shift p90;
- FAIL: minimum OOF participation.

Record `STOP_CALIBRATION_GATES_FAILED_FRESH_CONFIRMATION_NOT_READ`.

Do not rescue `CAL-A01` by changing a feature window, threshold direction,
participation floor, combination, model, target, cost interpretation, or TSLA
date range after seeing these results. Any new calibration attempt must receive
`CAL-A02` and remain outcome-aware. Do not open 2024+ TSLA transport from this
STOP.

## Evidence

- [Frozen plan](HYP_IMOM_04_1_TSLA_30MIN_SMA_PERMISSION_POSITIVE_CONTROL_PLAN.md)
- [Run report](../../runs/research_workbench/operator_hypothesis_lab/hyp_imom_04_1_tsla_30min_sma_permission_positive_control_20260823/him041_report.md)
- [Run specification](../../runs/research_workbench/operator_hypothesis_lab/hyp_imom_04_1_tsla_30min_sma_permission_positive_control_20260823/him041_run_spec.csv)
- [Parent event ledger](../../runs/research_workbench/operator_hypothesis_lab/hyp_imom_04_1_tsla_30min_sma_permission_positive_control_20260823/him041_tsla_parent_event_ledger.csv)
- [Model metrics](../../runs/research_workbench/operator_hypothesis_lab/hyp_imom_04_1_tsla_30min_sma_permission_positive_control_20260823/him041_model_metrics.csv)
- [Calibration gates](../../runs/research_workbench/operator_hypothesis_lab/hyp_imom_04_1_tsla_30min_sma_permission_positive_control_20260823/him041_calibration_gates.csv)
- [Human-facing momentum evidence deck](../../literature_studies/presentations/gen5_momentum_predictor_evidence_series.pptx)
