# HYP-IMOM-04.1 CAL-A02 TSLA Direct-Exposure Results

Status: `STOP_CAL_A02_DIRECT_EXPOSURE_GATES_FAILED_CONFIRMATION_NOT_READ`

Attempt: `CAL-A02`

Outcome zone: `OUTCOME_AWARE_REUSED_CALIBRATION`

Date completed: `2026-08-23`

## Question

Can a causal state model built from completed TSLA, QQQ, SPY, and SMH
30-minute sessions decide whether the next executable TSLA open-to-open
interval should be long or cash, retaining at least 60% of upside while
capturing at most 40% of downside?

This changed the scientific question after the stopped `CAL-A01` crossover
filter. CAL-A02 had continuous daily authority to enter or leave TSLA at the
next open; it was no longer restricted to fresh SMA8/SMA14 events.

## Frozen construction and boundary

- Alpaca SIP adjusted 30-minute archive data;
- TSLA, QQQ, SPY, and separately cached SMH;
- 2017 prehistory for causal rolling features;
- outcome-aware 2018-2023 calibration;
- twelve expanding quarterly OOF folds from 2021Q1 through 2023Q4;
- completed-session features at `t`, position at the open of `t+1`, and target
  return from that open to the open of `t+2`;
- 10 bp/side primary and 20 bp/side stress costs charged only when exposure
  changed;
- 2024+ sealed and unread.

Five 2017 prehistory sessions had unequal cross-symbol intraday bar counts and
were excluded before rolling features. No unequal-count session occurred in
the 2018-2023 calibration window. All remaining symbol calendars and bar
counts were exact.

The common ledger contained 1,380 complete causal sessions, including every
2019-2023 eligible session. The OOF policy surface contained 746 executable
2021-2023 intervals.

## Models and controls

The primary `R1` model was a TRAIN-standardized ridge return regressor over
twelve main features and four frozen interactions. Lambda came from expanding
inner validation. The primary long threshold was the frozen 10 bp/side
round-trip log-cost buffer, `0.00200100`.

The secondary `T1` model was a prespecified depth-two regression tree over the
twelve main features. It was a nonlinear diagnostic and could not replace R1
after outcomes were seen.

Both planted positive controls passed:

- R1 recovered the planted linear return mechanism;
- T1 recovered the planted two-feature conjunction.

The executable oracle also passed all four accounting checks and demonstrated
that the policy engine could express the desired upper-left capture pattern.
The oracle is infeasible and carries no market evidence.

## Primary predictive result

R1 did not improve the conditional return forecast.

| Measure | R1 readout |
|---|---:|
| OOF observations | 746 |
| OOF MSE | `0.00157129` |
| Fold-drift MSE | `0.00156490` |
| MSE improvement | `-0.00000639` |
| Prediction/return correlation | `-0.0118` |
| Familywise target-shift percentile | `36.5%` |
| Familywise p90 improvement | `0.00000986` |
| Permission fraction | `72.1%` |
| Mean return when permitted | `+0.076%` |
| Mean return when rejected | `+0.110%` |

The model was a coarse exposure throttle, not a directional discriminator. It
was long for roughly seven sessions out of ten, and the rejected sessions had
the higher mean TSLA return.

Inner validation selected the strongest ridge penalty, `lambda = 1000`, in
every reported fold. Coefficients were consequently small and mostly smooth,
but their combined forecast did not transport beyond drift.

## Primary policy result

| Policy/scenario | Return | Maximum drawdown | Exposure | Upside capture | Downside capture | Positive quarters |
|---|---:|---:|---:|---:|---:|---:|
| R1 gross | `-1.36%` | `-63.39%` | `72.1%` | `71.8%` | `72.2%` | 6/12 |
| R1, 10 bp/side | `-7.48%` | `-64.54%` | `72.1%` | `71.8%` | `72.2%` | 6/12 |
| R1, 20 bp/side | `-13.23%` | `-65.66%` | `72.1%` | `71.8%` | `72.2%` | 5/12 |
| Always long, 10 bp/side | `+5.54%` | `-74.96%` | `100.0%` | `100.0%` | `100.0%` | 6/12 |
| Hand `T200 >= 0`, 10 bp/side | `-28.38%` | `-54.40%` | `61.0%` | `54.1%` | `57.2%` | 3/12 |
| Oracle, 10 bp/side | diagnostic ceiling | `-0.10%` | `48.4%` | `99.8%` | `0.0%` | 12/12 |

R1 reduced drawdown relative to always long, but only by proportionally
removing exposure. Its upside and downside capture were nearly identical, so
the equity curve did not exhibit the desired pattern of rising with TSLA and
remaining flat through declines.

R1 ranked at the 87th percentile of 200 within-fold circular permission
shifts, but did not exceed the frozen p90. The matched p90 total return was
`-0.75%`, still above R1's `-7.48%`.

## The nonlinear tree observation

T1 produced a surprising `+55.68%` primary-cost return with `-58.02%` maximum
drawdown and 67.8% exposure. This is worth preserving as a hypothesis clue,
but it is not a CAL-A02 survivor:

- T1's MSE improvement was worse than R1's at `-0.00002870`;
- its prediction/return correlation was only `0.0268`;
- it captured 67.7% of upside and 63.2% of downside, far from the frozen
  upper-left capture target;
- only 6 of 12 quarters were positive;
- large gains in 2021Q4 and 2023Q2 offset severe losses in 2022Q3-Q4;
- the root split changed from SMH trend to TSLA drawdown, SMH-relative
  strength, relative volume, QQQ trend, and back to SMH trend across folds.

This pattern is consistent with unstable nonlinear tail timing or a few
fortuitously included large moves. CAL-A02 did not preregister tree-specific
matched-policy inference or a tail-sensitive objective, so those analyses
must not be added after seeing the return. A future CAL-A03 could ask a new,
narrow question about nonlinear tail capture, with independent controls and
the 2024+ boundary still closed until separately authorized.

## Gate decision

CAL-A02 passed 5 of 11 frozen gates:

- PASS: source and chronological-embargo integrity;
- PASS: both planted models and oracle accounting;
- FAIL: positive R1 MSE improvement;
- FAIL: familywise target-shift p90;
- FAIL: positive and always-long-beating return;
- PASS: shallower maximum drawdown than always long;
- PASS: minimum 60% upside capture;
- FAIL: maximum 40% downside capture;
- PASS: bounded 20%-80% exposure;
- FAIL: at least 8/12 positive quarters;
- FAIL: matched-permission p90.

Record `STOP_CAL_A02_DIRECT_EXPOSURE_GATES_FAILED_CONFIRMATION_NOT_READ`.

Do not change the CAL-A02 target horizon, feature windows, interaction list,
model hierarchy, cost buffer, capture thresholds, or gates. Any further
outcome-aware attempt is CAL-A03. Do not read 2024+ from this STOP.

## Evidence

- [Frozen plan](HYP_IMOM_04_1_CAL_A02_TSLA_DIRECT_EXPOSURE_PLAN.md)
- [Run report](../../runs/research_workbench/operator_hypothesis_lab/hyp_imom_04_1_cal_a02_tsla_direct_exposure_20260823/him042_report.md)
- [Run specification](../../runs/research_workbench/operator_hypothesis_lab/hyp_imom_04_1_cal_a02_tsla_direct_exposure_20260823/him042_run_spec.csv)
- [Session feature ledger](../../runs/research_workbench/operator_hypothesis_lab/hyp_imom_04_1_cal_a02_tsla_direct_exposure_20260823/him042_session_feature_ledger.csv)
- [Model metrics](../../runs/research_workbench/operator_hypothesis_lab/hyp_imom_04_1_cal_a02_tsla_direct_exposure_20260823/him042_model_metrics.csv)
- [Policy summary](../../runs/research_workbench/operator_hypothesis_lab/hyp_imom_04_1_cal_a02_tsla_direct_exposure_20260823/him042_policy_summary.csv)
- [Calibration gates](../../runs/research_workbench/operator_hypothesis_lab/hyp_imom_04_1_cal_a02_tsla_direct_exposure_20260823/him042_calibration_gates.csv)
- [Human-facing momentum evidence deck](../../literature_studies/presentations/gen5_momentum_predictor_evidence_series.pptx)
