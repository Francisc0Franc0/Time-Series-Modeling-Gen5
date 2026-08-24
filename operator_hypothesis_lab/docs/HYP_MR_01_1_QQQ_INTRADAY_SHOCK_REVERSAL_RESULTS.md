# HYP-MR-01.1 QQQ Intraday-Shock Reversal Results

Status: `STOP_HYP_MR_01_1_DEVELOPMENT_REVERSAL_GATES_FAILED_CONFIRMATION_NOT_RUN`

Date completed: `2026-08-22`

## Decision

The univariate reversal model earned a genuine TRAIN pass and therefore earned
the frozen DEVELOPMENT read. It did not transport. Stop the identifier without
changing the asset, ATR normalization, target, model, dates, or direction.

Confirmation remains unread.

## Frozen question

After QQQ completes an unusually large open-to-close move relative to the
strictly prior 20-session ATR%, does the next session's open-to-close return
move in the opposite direction?

The one registered model was:

`Y[t+1] = alpha + beta * X[t] + error`, with expected `beta < 0`.

The only benchmark was an intercept-only drift forecast. No classifier,
threshold, alternate horizon, alternate asset, nonlinear term, or strategy was
tested.

## Source and construction

- Alpaca SIP adjusted daily QQQ bars.
- Explicit as-of: `2026-08-22 17:30:00 America/New_York`.
- TRAIN query: `2016-01-04` through `2020-12-31`.
- TRAIN coverage: `1,259` sessions; `1,006` valid predictor-target anchors.
- DEVELOPMENT: `752` valid rows across 2021-2023.
- Source audit: `7 / 7` pass.
- Construction audit: `4 / 4` pass.
- The generic stale-cache WARN reflects the deliberately historical query;
  the complete requested range was covered.

The current session never entered its own ATR denominator, and every target
was the exact next session's open-to-close return.

## TRAIN evidence

The model cleared all `6 / 6` gates:

- full-TRAIN beta: `-0.0016534492`;
- Pearson correlation: `-0.101799`;
- Spearman correlation: `-0.093618`;
- pooled expanding-fold MSE improvement: `1.11650170682e-06`;
- positive folds: `3 / 3`;
- complete admissible circular shifts: `887`;
- shift-null p90: `1.14971887687e-07`;
- empirical upper-tail probability: `0.002252`.

The predeclared influence audit excluded the eleven largest observations by
`abs(X)`. The slope remained negative at `-0.0015123593` across the retained
`995` rows.

The three one-year-ahead improvements were positive but uneven. The 2020 fold
supplied most of the pooled improvement:

| Fold | Fitted beta | MSE improvement |
|---|---:|---:|
| 2018 | `-0.00083939` | `5.5015e-07` |
| 2019 | `-0.00095035` | `1.5384e-07` |
| 2020 | `-0.00090935` | `2.6372e-06` |

This was sufficient under the frozen contract to authorize DEVELOPMENT. It was
not sufficient to claim a durable edge.

## DEVELOPMENT transport

The full-TRAIN coefficients were frozen before the 2021-2023 outcomes were
queried. DEVELOPMENT passed only `2 / 5` gates:

- Spearman correlation: `-0.002767`, essentially zero;
- frozen model MSE: `0.0001581673`;
- frozen drift MSE: `0.0001577763`;
- loss improvement: `-3.91040804512e-07`;
- stationary-bootstrap P(improvement > 0): `0.3167`;
- positive years: `1 / 3`.

By calendar year, loss improvement was:

| Year | MSE improvement |
|---|---:|
| 2021 | `+3.8758e-07` |
| 2022 | `-4.2495e-07` |
| 2023 | `-1.1387e-06` |

The sign remained microscopically negative in association terms, but its
forecast value disappeared and then became harmful relative to drift. A sign
alone is not enough.

## Interpretation

This is a useful example of why a strong-looking TRAIN result is not an edge.
The TRAIN relationship was real enough to beat the registered timing control,
survive the influence audit, and improve all three expanding folds. Yet those
folds still belonged to one historical era, and the effect did not reproduce
in the later untouched period.

The correct reading is not that regression failed or that reversal never
exists. The narrow claim is that this fixed QQQ normalized intraday-shock
coefficient was not temporally stable across the registered boundary.

Do not rescue the result by selecting 2021, weakening the benchmark, fitting a
new coefficient on DEVELOPMENT, adding a large-move threshold, changing ATR,
switching to classification, or moving to another horizon under this
identifier.

## Evidence packet

- Run packet:
  `runs/research_workbench/operator_hypothesis_lab/hyp_mr_01_1_qqq_intraday_shock_reversal_20260822`
- TRAIN relationship: `visuals/hmr011_train_relationship.png`
- TRAIN fold evidence: `visuals/hmr011_train_fold_improvement.png`
- Timing falsification: `visuals/hmr011_train_timing_control.png`
- Representative shocks: `visuals/hmr011_train_representative_shocks.png`
- DEVELOPMENT transport: `visuals/hmr011_development_transport.png`

This remains predictor evidence only. No trade rule, P&L, portfolio, or live
behavior was constructed.

## Breadth follow-up

`HYP-MR-01.2` applied this predictor unchanged to an outcome-independent
36-asset atlas. QQQ ranked fourth and at the `91.7`th percentile by relative
OOF MSE improvement, but the atlas median was negative and only `12 / 36`
assets beat drift. The breadth study stopped in TRAIN, leaving its later
partitions unread. See
`HYP_MR_01_2_CROSS_ASSET_INTRADAY_SHOCK_REVERSAL_ATLAS_RESULTS.md`.
