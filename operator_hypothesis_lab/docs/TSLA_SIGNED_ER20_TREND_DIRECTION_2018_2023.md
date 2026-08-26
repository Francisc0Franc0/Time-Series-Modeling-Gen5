# TSLA Signed-ER20 Trend-Direction POC: 2018-2023

## Question

Can the accepted 20-session path-efficiency measure be extended into a simple,
causal state label that distinguishes upward-trending, downward-trending, and
sideways TSLA paths without using moving-average crossovers?

## Frozen Construction

The signed efficiency ratio is:

`(log_close[t] - log_close[t-20]) / sum(abs(one-session log-price moves))`

It retains the sign discarded by the earlier absolute `ER20` measure:

- `signed ER20 >= +0.30`: `UP_TREND`.
- `-0.30 < signed ER20 < +0.30`: `SIDEWAYS`.
- `signed ER20 <= -0.30`: `DOWN_TREND`.

The window and cutoff were inherited unchanged from the accepted ER20 visual.
No parameter search was run. The state at close `t` uses closes through `t`
only, and the corresponding chart band begins at `t`.

This is a directional completion of ER20, not an independent filter:

`abs(signed ER20) = ER20`

## Scope

- Asset: `TSLA`.
- Source: canonical Alpaca SIP adjusted daily bars.
- Visible sessions: `2018-01-02` through `2023-12-29`.
- Classified sessions: `1,509`.
- Predictive target, return-grid conditioning, parameter optimization,
  strategy performance, and post-2023 data: none.

## State-Quality Readout

| State | Sessions | Share | Spans | Median span | Longest span | One-session spans |
|---|---:|---:|---:|---:|---:|---:|
| Up trend | 368 | 24.4% | 41 | 5 | 46 | 13 |
| Sideways | 958 | 63.5% | 79 | 8 | 54 | 14 |
| Down trend | 183 | 12.1% | 37 | 2 | 18 | 12 |

Across the full ledger there were `156` state changes, a `10.3%` daily
transition rate. The `157` contiguous spans included `39` one-session spans
(`24.8%`). There were no direct up-to-down or down-to-up transitions: every
direction reversal passed through the neutral sideways band.

## Bench Readout

The chart creates an intelligible visual distinction. Strong portions of the
2019-2021 rise and the 2023 rallies are green, while meaningful declining
paths—including parts of the 2022 decline—are red. Irregular and consolidating
paths are predominantly gray. Repeated price crossings are not needed because
the score compares net displacement with the full traveled path.

The state map is not uniformly stable. Down-trend states are substantially
shorter and less prevalent than up-trend or sideways states on this TSLA
sample. Roughly one third of both up and down spans last only one session. The
fixed score therefore works as a readable direction tag, but it remains a
flickery standalone regime label around boundaries and turning points.

That asymmetry is descriptive rather than a defect to repair after inspection.
TSLA rose materially over the study period, and the inherited symmetric cutoff
does not guarantee symmetric occupancy or duration. No persistence rule,
hysteresis, smoothing, alternate cutoff, or window change was added.

## Decision

`DESCRIPTIVE_SIGNED_ER20_DIRECTION_POC_COMPLETE_FILTER_APPLICATION_NOT_YET_RUN`

The metric is adequate to carry forward as the fixed direction-state baseline
in the own-asset workflow template. It has not yet been applied to the 9 by 9
return surface or the positive-versus-negative prior-return branches. No
predictive edge, moderator, or trading authority is established.

## Deferred Parameter and Time-Window Research

The current `2018-2023` period is an exploratory research surface, not proof
that six years is the correct estimation length or that the next deployment
increment should have any particular duration. Window length, state lookback,
cutoff, training span, forward evaluation span, and requalification frequency
are deliberately deferred until the workflow template is frozen and run on a
balanced multi-asset atlas. See
`operator_hypothesis_lab/docs/OWN_ASSET_RETURN_GEOMETRY_WORKFLOW_ROADMAP.md`.

## Artifacts

- Chart:
  `runs/research_workbench/operator_hypothesis_lab/tsla_signed_er20_trend_direction_20260826/visuals/tsla_signed_er20_direction_bands.png`
- State ledgers and diagnostics:
  `runs/research_workbench/operator_hypothesis_lab/tsla_signed_er20_trend_direction_20260826/`
- Reproduction script:
  `scripts/inspect/run_tsla_signed_er20_trend_direction.R`
- Pure calculation helpers:
  `operator_hypothesis_lab/R/tsla_signed_er20_direction.R`
- Running evidence deck:
  `operator_hypothesis_lab/presentations/tsla_descriptive_microscope_evidence.pptx`
