# HYP-IMOM-03.1 SMH-to-QQQ First-Hour Lead-Lag Results

Status: `STOP_HYP_IMOM_03_1_TRAIN_LEAD_LAG_GATES_FAILED`

## Question

Does first-hour SMH leadership over QQQ reach the broader growth complex with
a delay, causing QQQ to outperform SPY from the next 30-minute bar's open
through the same session's close?

## Source decision

The return-blind source audit passed all `6 / 6` checks.

- SMH, QQQ, and SPY used Alpaca SIP `30Min` bars with adjustment `all`.
- Their calendars were identical after the ten previously admitted common
  archive-gap exclusions and the shared early-close rules.
- TRAIN contained `751` sessions in 2018–2020.
- The two expanding TRAIN scoring folds contained `503` sessions in 2019–2020.
- The source also supports `498` prospective 2021–2022 DEVELOPMENT sessions
  and `250` 2023 confirmation sessions, but neither outcome zone was opened.

## Frozen test

The signal was fixed at 10:30 ET:

`first-hour SMH return - first-hour QQQ return`.

The causal target began at slot 3's open and ended at the final regular-session
close:

`remainder QQQ return - remainder SPY return`.

The `LEADER` model added the SMH-minus-QQQ signal to weekday, QQQ first-hour,
and SPY first-hour controls. The frozen wrong-clock placebo substituted the
prior admitted session's leadership signal. There was one signal window and
one target window, so no horizon search was performed.

## TRAIN result

The proposed lead-lag mechanism did not appear.

| Model | OOF MSE | OOF MAE | Prediction/target correlation |
|---|---:|---:|---:|
| Weekday drift | `1.349949921e-05` | `0.002529281` | `0.04210` |
| QQQ + SPY control | `1.360169628e-05` | `0.002548968` | `0.04514` |
| Add same-session SMH leadership | `1.360170345e-05` | `0.002548050` | `0.04500` |
| Prior-session wrong-clock placebo | `1.357498943e-05` | `0.002549208` | `0.05385` |

The all-TRAIN SMH-leadership coefficient was `-0.006352`, slightly negative
and economically close to flat. Adding it made MSE fractionally worse than the
QQQ/SPY control, although MAE improved by a negligible amount. The wrong-clock
placebo had lower MSE than the proposed same-session signal, and the simple
weekday-drift forecast had the lowest MSE and MAE of all four models.

The stationary-bootstrap 10th percentile of squared-loss improvement was
`-9.550407e-09`. The bootstrap probability that the same-session leader
improved on the QQQ/SPY control was `0.514`: effectively coin-flip evidence.

TRAIN gate readout:

| Gate | Result |
|---|---|
| Minimum support | PASS |
| Positive leadership coefficient | FAIL |
| MSE below QQQ/SPY control | FAIL |
| MAE below QQQ/SPY control | PASS |
| MSE below wrong-clock placebo | FAIL |
| Bootstrap q10 above zero | FAIL |

## Decision

Record `STOP_HYP_IMOM_03_1_TRAIN_LEAD_LAG_GATES_FAILED`.

- Do not construct or score 2021–2022 DEVELOPMENT outcomes.
- Preserve 2023 confirmation unread.
- Do not search 30-, 90-, or 120-minute signal windows, substitute SOXX/XSD,
  remove the QQQ/SPY controls, condition on large SMH moves, or invert the sign
  under this identifier.
- Continue to QQQ-S3 only as the already-bookmarked and economically distinct
  daily QQQ-versus-SPY relative-leadership proposition.

The stop is narrow: it rejects this first-hour-to-remainder transmission clock.
It does not show that semiconductors never lead QQQ at shorter clocks, around
specific events, or under a separately motivated state definition.

No strategy, P&L, costs, Sharpe, drawdown, allocation, leverage, or live
behavior was computed.

## Evidence

- [Frozen contract](HYP_IMOM_03_1_SMH_TO_QQQ_FIRST_HOUR_LEAD_LAG_CONTRACT.md)
- [Updated momentum-predictor evidence deck](../../literature_studies/presentations/gen5_momentum_predictor_evidence_series.pptx)
- [Run report](../../runs/research_workbench/operator_hypothesis_lab/hyp_imom_03_1_smh_qqq_lead_lag_20260822/him031_report.md)
- [Source coverage](../../runs/research_workbench/operator_hypothesis_lab/hyp_imom_03_1_smh_qqq_lead_lag_20260822/him031_source_coverage.csv)
- [TRAIN model metrics](../../runs/research_workbench/operator_hypothesis_lab/hyp_imom_03_1_smh_qqq_lead_lag_20260822/him031_train_model_metrics.csv)
- [TRAIN gates](../../runs/research_workbench/operator_hypothesis_lab/hyp_imom_03_1_smh_qqq_lead_lag_20260822/him031_train_gates.csv)
- [Model-loss figure](../../runs/research_workbench/operator_hypothesis_lab/hyp_imom_03_1_smh_qqq_lead_lag_20260822/visuals/him031_train_model_loss.png)
- [Partial-relationship figure](../../runs/research_workbench/operator_hypothesis_lab/hyp_imom_03_1_smh_qqq_lead_lag_20260822/visuals/him031_train_partial_relationship.png)
- [Representative event tapes](../../runs/research_workbench/operator_hypothesis_lab/hyp_imom_03_1_smh_qqq_lead_lag_20260822/visuals/him031_representative_event_tapes.png)
