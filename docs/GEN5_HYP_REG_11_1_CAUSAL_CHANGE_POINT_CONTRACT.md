# HYP-REG-11.1 Causal Positive Change-Point Contract

Status: `STOP_CAUSAL_CHANGE_POINT_STAGE_A_FAILED_STRATEGY_NOT_RUN`

## Question

Can a causal one-sided CUSUM event identify a newly emerging positive return
process early enough to improve only fresh entries in the unchanged daily
SMA8/SMA14 long/cash parent?

This is an onset detector, not a permanent trend regime, return forecast, or
retrospective structural-break label.

## Evidence Boundary

- Identifier: `HYP-REG-11.1`.
- Evidence label: `DEVELOPMENT_REUSED_WINDOW`.
- Analysis: 2018-01-02 through 2023-12-29.
- Panel: the frozen 24-stock strategy panel plus SPY and QQQ references.
- Bars: adjusted daily OHLCV with explicit as-of timestamp
  `2026-08-15 17:30:00 America/New_York`.
- Confirmation: 2024-01-02 onward remains sealed unless all development gates
  pass and the operator separately opens confirmation.
- No threshold may be selected from real returns or strategy performance.

## Literature Ledger

| Source | Grounding | What it authorizes | What it does not authorize |
|---|---|---|---|
| Page (1954), *Continuous Inspection Schemes*, Biometrika 41, pp. 100-115, especially the sequential cumulative-score construction | <https://doi.org/10.1093/biomet/41.1-2.100> | A sequential statistic that accumulates evidence and signals after crossing a decision boundary | This equity-specific input, threshold, cooldown, or trading rule |
| Brown, Durbin, and Evans (1975), *Techniques for Testing the Constancy of Regression Relationships Over Time*, JRSS B 37, pp. 149-163, especially recursive residuals and CUSUM/CUSUMSQ | <https://doi.org/10.1111/j.2517-6161.1975.tb01532.x> | Cumulative residual monitoring and graphical inspection of instability | Treating full-sample break locations as live-known |
| Zeileis, Leisch, Kleiber, and Hornik (2005), *Monitoring Structural Change in Dynamic Econometric Models*, Sections 1-3 and pp. 99-121 | <https://www.zeileis.org/papers/Zeileis%2BLeisch%2BKleiber-2005.pdf> | The distinction between retrospective tests and causal monitoring of incoming data; explicit finite-sample size/power audits | A claim that any alarm is durable, directional alpha |

The exact POC is operator-designed from this family. It is not presented as a
published Chan, Page, Brown-Durbin-Evans, or Zeileis trading strategy.

## Stage A — Frozen Measurement

At close `t`, compute the daily log return and divide it by the sample standard
deviation of the prior 20 completed daily log returns:

```text
r_t = log(P_t / P_(t-1))
z_t = clip(r_t / sd(r_(t-20), ..., r_(t-1)), -3, +3)
S_t = max(0, S_(t-1) + z_t - k)
```

The positive standardized mean-shift of interest is frozen at `delta = 0.20`,
so Page's reference allowance is `k = delta / 2 = 0.10`. Clipping at three
standard deviations prevents one isolated extreme return from being allowed
to constitute accumulated evidence by itself.

The decision threshold `h` is not fitted to market data. It is selected from
the fixed grid `2.00, 2.25, ..., 30.00` as the smallest value for which each of
three 504-session no-change families has an alarm probability no greater than
20%:

1. Gaussian returns;
2. variance-standardized Student-t returns with five degrees of freedom;
3. Gaussian returns with a mid-path doubling of volatility but no mean shift.

Use 1,000 seeded paths per family. Then audit 1,000 paths each for a positive
`+0.15` and `+0.30` standardized mean shift, a negative `-0.30` shift, and one
isolated positive five-sigma jump. Stage A requires at least 70% of `+0.30`
paths to alarm within 60 sessions with median delay no greater than 40
sessions; negative-shift and isolated-jump alarms within 60 sessions must each
remain no greater than 20%.

After an alarm, reset `S` to zero and impose a ten-session refractory period.
The alarm date and following nine sessions form one fixed
`RECENT_POSITIVE_ONSET` eligibility window. Repeated evidence cannot extend the
window because accumulation is disabled during the refractory period.

Real-panel Stage A requires exact causality and price-scale invariance, zero
alarm/window semantic violations, at least 18/24 primary stocks with three or
more alarms over six years, at least 18/24 with one or more eligible fresh
SMA cross, and median eligibility occupancy between 1% and 25%.

## Stage B — Frozen Strategy Contact

- Parent: unchanged daily SMA8/SMA14 long/cash.
- Signal: fresh close-date SMA8-above-SMA14 cross.
- Entry: next open, 1x long, only if the signal date lies in a frozen
  `RECENT_POSITIVE_ONSET` window.
- A rejected signal is skipped, not deferred.
- Exit: next open after the unchanged parent SMA8-below-SMA14 cross.
- No alarm-driven direct entry, exit, sizing, leverage, shorting, or ATR join.
- Costs: 5 bp per side primary; 10 bp per side stress.
- Annual cells reset at each asset-year start and compound internally.
- Baselines: unfiltered parent, buy-and-hold, and cash.
- Controls: 200 deterministic within-asset/year circular rotations of the
  complete eligibility schedule; select 40 exposure-nearest controls using
  exposure only before inspecting returns.

## Gates and Stop Rules

All nine common strategy gates remain required: causal integrity, exact parent
reproduction, construction integrity, median return above parent, at least
15/24 stocks improved, at least 4/6 positive median-excess years, no worse
median drawdown and Sharpe, positive absolute median return, and at least an
80th-percentile return versus exposure-nearest controls.

Do not rescue failure by changing the volatility window, clip, target shift,
reference allowance, threshold grid, false-alarm budget, refractory/eligibility
length, event direction, parent, exit, assets, costs, ATR%, leverage, or 2024+
boundary.

## Explicit Exclusions

- Retrospective PELT, binary segmentation, smoothed break dates, or future
  confirmation of an alarm.
- Page-Hinkley, Bayesian online change-point detection, or HMMs.
- Negative alarms as a short signal.
- Combining T1-T3 measurements or selecting a favorable prior lane.

The post-series HMM bookmark remains unopened.

## Completed Readout

The synthetic-only calibration selected `h = 20.25`; every null family stayed
within the 20% false-alarm budget, and direction/jump falsification, append
causality, price-scale invariance, and exact event-window semantics passed.
Sensitivity and real-panel usability did not. Only 40.7% of sustained `+0.30`
shifts were detected within 60 sessions, timely detections had a 45-session
median delay, only 2/24 primary stocks produced at least three alarms, and no
primary stock had an eligible fresh SMA crossover. Stage A passed 5/7 gates.

Strategy outcomes were not accessed. Preserve the STOP, keep 2024+ sealed, and
do not rescue the boundary or event window. The detailed readout is in
`operator_hypothesis_lab/docs/HYP_REG_11_1_CAUSAL_CHANGE_POINT_RESULTS.md`.
