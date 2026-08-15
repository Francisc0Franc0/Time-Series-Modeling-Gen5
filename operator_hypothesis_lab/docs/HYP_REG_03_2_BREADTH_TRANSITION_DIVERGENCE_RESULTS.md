# HYP-REG-03.2 Breadth-Transition and Leadership-Divergence Results

Status: `STOP_BREADTH_TRANSITION_GATES_FAILED_NO_JOINT_FILTER`

## Question

While SPY's visible `SMA20/SMA60` trend remains positive, do simultaneous
weakening in ten-sector participation and equal-weight leadership warn that
SPY will decline over the next 20 sessions?

This narrower question follows the HYP-REG-03.1 clue without tuning its
SMA20 level score or reversing the failed H63 result.

## Frozen Design

The diagnostic combined:

- `D(t)`: the 20-session change in median sector `log(close/SMA20)`;
- `G(t)`: the 20-session change in `log(RSP/SPY)`;
- `X(t)`: the cross-sector IQR of sector depth, retained as a continuous
  diagnostic only;
- `N(t)`: an unfitted equal-weight average of the prior-relative weakness of
  `D(t)` and `G(t)`.

Inside a positive visible SPY trend, `NARROWING` required `D(t) < 0` and
`G(t) < 0`; `HEALTHY` required both to be non-negative. Mixed states were
reported but prohibited from post-result selection.

The sole return target was causal next-open H20 SPY open-to-open direction.
All-daily rows supplied effect sizes; all 20 deterministic H20 starting
offsets supplied non-overlapping stability views. Temporal halves, calendar
years, future measurement semantics, and 200 within-year circular state-timing
controls were frozen before outcomes were read. The analysis remained
2018-2023 and 2024+ stayed sealed.

## Data Admission

RSP was initially absent from the local cache, so the first run stopped before
analysis. A bounded adjusted-daily Alpaca refresh populated the frozen
2016-2023 request. All 12 assets then retained 2,012 rows, all 1,509 analysis
sessions aligned, and every integrity check passed. Query-health
`stale_symbol` warnings reflect the deliberately bounded 2023 endpoint rather
than missing requested-window history.

## Primary Result

| State | Observations | Median H20 return | H20 DOWN rate |
|---|---:|---:|---:|
| HEALTHY | 174 | +1.547% | 31.61% |
| NARROWING | 401 | +1.394% | 35.41% |
| MIXED_BREADTH_WEAK | 224 | +2.123% | 29.91% |
| MIXED_LEADERSHIP_WEAK | 225 | +0.972% | 37.78% |

The predeclared `NARROWING` warning produced only a `-0.152` percentage-point
median-return gap and a `+3.802` percentage-point DOWN-rate gap versus
`HEALTHY`. Both missed the frozen `-0.75` and `+10` percentage-point effect
thresholds.

The mixed leadership-weak state had the lowest median return and highest DOWN
rate. That is an inspected descriptive clue, not authority to discard the
sector-breadth condition or promote RSP/SPY alone under this identifier.

## Continuous and Stability Evidence

| Measurement | Spearman with H20 SPY return |
|---|---:|
| Breadth level | -0.146 |
| Breadth transition `D(t)` | -0.086 |
| RSP/SPY leadership transition `G(t)` | +0.039 |
| Narrowing-risk score `N(t)` | -0.030 |
| Sector dispersion `X(t)` | +0.060 |

The narrowing score's DOWN AUC was `0.527`, only slightly above chance. Its
deciles were not monotone. Dispersion was also non-monotone and did not supply
a defensible modifier.

All 20 starting offsets contained adequate state support, but only `7 / 20`
showed both a negative return gap and positive DOWN-rate gap. Only `2 / 6`
calendar years did so. The temporal halves contradicted one another:

- 2018-2020: `+0.016 pp` return gap and `+10.535 pp` DOWN-rate gap;
- 2021-2023: `-0.450 pp` return gap and `-4.143 pp` DOWN-rate gap.

The actual return-gap timing ranked at the `42.5th` percentile of circular
controls and the DOWN-rate gap at the `71.0th`, well short of the frozen
10th/90th falsification gate.

## The Most Important Mechanistic Finding

The state failed to preserve its own meaning into the next month. Relative to
`HEALTHY`, `NARROWING` was followed by:

- `+2.474 pp` more future sector-breadth improvement overall;
- `+0.320 pp` more future RSP/SPY improvement overall.

The breadth result was positive in both temporal halves. Rather than detecting
a durable participation breakdown, simultaneous negative 20-session changes
often marked a point from which breadth rebounded. This explains why adding
transition signs did not create a stable directional warning.

That does not authorize a post-hoc mean-reversion strategy. It changes the
theoretical interpretation: negative recent breadth change is not equivalent
to persistent breadth decay.

## Gate Decision

Only integrity passed: `1 / 8` gates.

- Record `STOP_BREADTH_TRANSITION_GATES_FAILED_NO_JOINT_FILTER`.
- Do not join ATR%, run a strategy overlay, select the mixed leadership state,
  add thresholds, tune lookbacks, reverse the sensor, or inspect 2024+.
- Preserve RSP/SPY relative leadership as the one component whose continuous
  sign matched the intended mechanism, but treat that only as theory input for
  a separately frozen future question.
- Recovery thrust, VIX structure, intraday persistence, and true
  point-in-time constituent breadth remain unopened lanes.

## Artifacts

- Contract: `docs/GEN5_HYP_REG_03_2_BREADTH_TRANSITION_DIVERGENCE_CONTRACT.md`
- Registry: `operator_hypothesis_lab/registries/hyp_reg_03_2_breadth_transition_registry.csv`
- Run packet: `runs/research_workbench/operator_hypothesis_lab/hyp_reg_03_2_breadth_transition_20260814`
- Evidence deck: `operator_hypothesis_lab/presentations/hyp_reg_03_2_breadth_transition_divergence_evidence.pptx`
