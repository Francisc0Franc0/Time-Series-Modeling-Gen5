# HYP-REG-11.1 Causal Positive Change-Point Results

Status: `STOP_CAUSAL_CHANGE_POINT_STAGE_A_FAILED_STRATEGY_NOT_RUN`

## Question

Can a causally calibrated positive CUSUM onset event improve fresh next-open
entries in the unchanged daily SMA8/SMA14 long/cash parent?

## Evidence Boundary

- Evidence label: `DEVELOPMENT_REUSED_WINDOW`.
- Analysis: 2018-01-02 through 2023-12-29.
- Panel: 24 primary stocks plus SPY and QQQ references.
- Confirmation: 2024-01-02 onward remained sealed.
- The threshold was calibrated only on seeded synthetic paths.
- No strategy returns, timing controls, ATR join, threshold rescue, or
  confirmation data were accessed after Stage A failed.

## Construction

The one-sided Page-style statistic uses today's log return divided by the
sample volatility of the prior 20 completed returns. Each standardized return
is clipped to `[-3,+3]`; the running positive score subtracts a frozen `0.10`
allowance, resets at zero, and alarms after crossing `h`. An alarm resets the
score and creates one non-extending ten-session event window.

The threshold is the smallest value on the frozen `2.00` to `30.00` grid that
keeps 504-session alarm probability no greater than 20% for Gaussian,
Student-t5, and pure volatility-step null paths. The full source ledger and
exact mechanics are in the contract.

## Synthetic Calibration

The false-alarm algorithm selected `h = 20.25`:

| No-change family | 504-session alarm probability |
|---|---:|
| Gaussian | 14.4% |
| Student-t5 | 16.0% |
| Volatility step without mean shift | 19.3% |

Specificity therefore passed. Directional and isolated-jump falsification
also passed: a `-0.30` shift generated an alarm within 60 sessions on only
0.2% of paths, and one positive five-sigma jump did so on only 2.7%.

Sensitivity did not pass. A sustained `+0.30` standardized mean shift was
detected within 60 sessions on only 40.7% of paths versus the frozen 70%
minimum. Among timely detections, median delay was 45 sessions versus the
maximum of 40. The weaker `+0.15` shift was detected within 60 sessions on
only 12.8% of paths.

## Real-Panel Usability

The causal ledger was exact, append invariant, and price-scale invariant to a
maximum numerical difference of `5.24e-13`. Alarm resets and ten-session
eligibility windows had zero semantic or spacing violations.

Those coherent events were unusably sparse:

- only AMD and TSLA reached three alarms over six years;
- median primary-stock eligibility occupied 0.3% of sessions;
- no primary stock had a fresh SMA8/SMA14 cross inside an eligible window.

The detector therefore failed both its synthetic sensitivity gate and its
real-panel usability gate. Stage A passed 5/7 gates.

## Decision

Stop before strategy contact. Running a backtest with zero eligible fresh
crosses would not establish protection, timing skill, or economic value. Do
not lower `h`, lengthen the event window, change the false-alarm budget,
volatility window, clipping, allowance, direction, parent, exit, assets,
costs, leverage, or evidence boundary under `HYP-REG-11.1`.

Retain the causal standardization, synthetic specificity/power harness,
event-window ledger, and representative tapes as audited research
infrastructure. The next roadmap gate is discussion of T5 range position and
breakout persistence, including whether it belongs in `HYP-REG` as context or
`HYP-MOM` as a direct entry strategy. The post-series HMM bookmark remains
unopened.

## Artifacts

- Contract: `docs/GEN5_HYP_REG_11_1_CAUSAL_CHANGE_POINT_CONTRACT.md`.
- Engine: `operator_hypothesis_lab/R/hyp_reg_11_1_causal_change_point_poc.R`.
- Runner:
  `operator_hypothesis_lab/scripts/run_hyp_reg_11_1_causal_change_point_poc.R`.
- Registry:
  `operator_hypothesis_lab/registries/hyp_reg_11_1_causal_change_point_registry.csv`.
- Evidence deck:
  `operator_hypothesis_lab/presentations/hyp_reg_11_1_causal_change_point_evidence.pptx`.
- Ignored packet:
  `runs/research_workbench/operator_hypothesis_lab/hyp_reg_11_1_causal_change_point_20260816`.
