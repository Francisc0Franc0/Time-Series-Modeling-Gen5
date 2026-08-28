# Return-Geometry Incremental Forward Decomposition (2018-2023)

## Purpose

The wide-atlas study found that the cumulative signed-ER20 down-state
loss-rebound relationship remained visible through 100 following sessions.
Because cumulative targets nest all earlier returns, that result did not show
when the response arrived. This slice decomposes the future into disjoint
blocks so an early echo can be distinguished from continuing conditional
accrual.

## Frozen Microscope

- Universe: the frozen 129-instrument atlas. The full-history 88-stock,
  11-sector core is the primary equal-sector result; the other cohorts remain
  diagnostic.
- Evidence window: adjusted daily bars from 2018 through 2023. Post-2023 data
  remain sealed.
- Anchor: exactly 20 prior sessions with a negative cumulative log return.
- State: signed ER20 `DOWN_TREND`, known at the anchor.
- Future blocks: sessions `1-5`, `6-10`, `11-20`, `21-40`, `41-60`, and
  `61-100`.
- Common sample: every observation has a complete 100-session future path, so
  all six blocks use the same anchors.
- Primary measures: prior-return magnitude versus incremental block return,
  summarized by correlation, slope, and sector breadth.
- Actionability descriptor: conditional mean block return minus the same
  asset's unconditional mean drift, expressed per session.
- Comparator: the unfiltered negative-prior branch only.

This slice does not open ATR%, other ER states, positive priors, other prior
horizons, formal inference, multiplicity selection, trading, PnL, or
post-2023 outcomes.

## Frozen Duration Rule

A late block (`21-40`, `41-60`, or `61-100`) is descriptively supportive only
when all three conditions hold:

1. the equal-sector median incremental correlation is negative;
2. at least 7 of 11 sector medians are negative; and
3. equal-sector drift-adjusted return per session is positive.

At least two of the three late blocks must pass to retain descriptive duration
support.

## Readout

| Following block | Incremental r | Cumulative r | Sectors with negative r | Excess return / session | Sectors with positive excess |
|---|---:|---:|---:|---:|---:|
| 1-5 | -0.146 | -0.146 | 11/11 | +0.88 bp | 6/11 |
| 6-10 | -0.094 | -0.173 | 8/11 | +4.53 bp | 6/11 |
| 11-20 | -0.211 | -0.212 | 11/11 | +7.07 bp | 10/11 |
| 21-40 | -0.059 | -0.221 | 10/11 | +4.47 bp | 9/11 |
| 41-60 | -0.164 | -0.405 | 10/11 | +0.72 bp | 8/11 |
| 61-100 | -0.057 | -0.339 | 7/11 | -0.90 bp | 3/11 |

The `21-40` and `41-60` blocks pass the frozen late-block rule. The `61-100`
block does not: although its median correlation remains slightly negative and
7/11 sector medians are negative, conditional return falls below same-asset
unconditional drift and only 3/11 sector excess medians remain positive.

Status:

`LATE_INCREMENTAL_DURATION_RETAINS_DESCRIPTIVE_SUPPORT`

## Interpretation

The cumulative plateau was not only a 5-10-session rebound echoed into longer
targets. New relationship structure and positive drift-adjusted accrual remain
visible into sessions 21-40 and 41-60. The evidence then fades: sessions
61-100 do not retain positive conditional accrual above ordinary asset drift.

This locates descriptive response timing; it does not establish a 60-session
holding rule. Overlapping anchors, path risk, exposure matching, costs,
opportunity cost, temporal transport, and an executable event policy remain
unresolved.

## Evidence Surface

- Packet: `runs/research_workbench/operator_hypothesis_lab/return_geometry_incremental_forward_decomposition_20260827`
- Script: `scripts/inspect/run_return_geometry_incremental_forward_decomposition.R`
- R helper: `operator_hypothesis_lab/R/return_geometry_incremental_forward_decomposition.R`
- Deck: `operator_hypothesis_lab/presentations/return_geometry_edge_promotion_huddle.pptx`

All 12 construction checks passed. The six incremental blocks reconstruct the
1-100 cumulative return to numerical precision, the common-anchor sample is
identical across blocks, the shared cumulative cell reproduces the prior atlas,
and the latest included session is 2023-12-29.

## STOP

Freeze this timing morphology. Do not retune the blocks, infer a holding period,
open another filter or prior horizon, or query post-2023 outcomes until the next
gate is designed.
