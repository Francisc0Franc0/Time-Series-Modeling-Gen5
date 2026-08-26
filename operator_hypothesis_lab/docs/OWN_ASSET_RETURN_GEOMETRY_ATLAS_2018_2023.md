# Own-Asset Return-Geometry Atlas

## Question

Does the frozen TSLA return-geometry microscope reveal a similar shape across
a predeclared balanced asset atlas, before the project opens finer return
horizons such as 6-9 sessions?

## Why the Atlas Came Before a Finer Grid

Adding 6-9-session horizons immediately after the TSLA result would have been
a local zoom motivated by an inspected winner. The atlas instead asks a more
basic transport question while leaving the original horizon grid unchanged.
Only a repeated cross-asset neighborhood should earn a separately frozen local
refinement.

## Frozen Atlas

The registry was fixed before results were read. It contains 30 assets in six
equal five-asset groups:

- operator/high beta: TSLA, AMD, NVDA, GME, AMC;
- mature growth: AAPL, MSFT, AMZN, GOOGL, CRM;
- cyclical/value: JPM, CAT, XOM, BA, F;
- defensive equities: JNJ, PG, KO, WMT, PEP;
- equity ETFs: SPY, QQQ, IWM, DIA, SMH; and
- non-equity proxies: TLT, IEF, GLD, SLV, USO.

TSLA remains the discovery reference. The other 29 assets are transport
observations, not 29 independent time experiments: many rows share calendar
dates and market shocks.

## Frozen Microscope

- Adjusted Alpaca daily OHLCV only.
- Analysis window: 2018-01-02 through 2023-12-29.
- Cumulative close-to-close log returns.
- Prior and following horizons: `1, 2, 3, 4, 5, 10, 15, 20, 25` sessions.
- Unfiltered, unsigned ER20, accepted causal ATR%, and signed-ER20 states.
- Negative-prior and positive-prior branches plus their slope contrast.
- No asset-specific threshold, horizon, state, or best-cell selection.
- No 6-9-session refinement and no post-2023 data.

The complete 9 by 9 surfaces are descriptive morphology. HAC and BH inference
was restricted to seven TSLA-discovered cells frozen before atlas results were
read: the four earlier unfiltered sign-asymmetry cells and three signed-ER20
DOWN-state cells.

The recomputed TSLA signed-ER20 state, comparison, and sign-branch surfaces
match the preceding frozen packet to below `1e-12` after using the identical
log-ratio return construction.

## Principal Result: The DOWN-State Rebound Shape Transports

At the frozen signed-ER20 DOWN prior-20 / following-20 cell:

- 23 of 29 non-TSLA assets have a negative Pearson correlation;
- same-sign breadth versus TSLA is 79.3%;
- the transport median Pearson correlation is `-0.1960`;
- the transport median OLS slope is `-0.3551`;
- 13 of 29 raw HAC tests have p below 0.05; and
- 12 of 29 survive BH across the 29 tests in this one frozen cell and also the
  complete fixed 210-test family.

This is not one-cell luck. Every cell in the 15/20/25-prior by
15/20/25-following neighborhood has a negative equal-asset median correlation.
The medians range from `-0.1500` to `-0.2564`, and 70.0%-83.3% of assets are
negative in each of those nine cells. The strongest equal-asset median cell is
20 prior / 25 following at `-0.2564`.

All six behavioral groups have a negative median 20/20 correlation:

| Group | Assets excluding TSLA | Median Pearson |
|---|---:|---:|
| Operator/high beta | 4 | -0.1028 |
| Mature growth | 5 | -0.0905 |
| Cyclical/value | 5 | -0.1833 |
| Defensive equity | 5 | -0.3126 |
| Equity ETF | 5 | -0.3903 |
| Non-equity proxy | 5 | -0.0858 |

Leave-one-asset-out transport medians remain between approximately `-0.21`
and `-0.20`. TSLA therefore does not create the aggregate result by itself.

The direct DOWN-minus-SIDEWAYS 20/20 comparison also transports, but less
strongly: its transport median correlation contrast is `-0.1735`, 69.0% share
the TSLA contrast sign, nine raw tests pass 0.05, and two survive the fixed-cell
BH correction.

## What Did Not Transport as Cleanly

The short-prior DOWN-state sign kink is weaker than the aggregate rebound
surface:

- only 15 of 29 transport assets have both prior-sign branches large enough
  for the frozen 5/20 slope-interaction test;
- the estimable transport median slope contrast is `+0.8705`;
- 55.2% share TSLA's descriptive correlation-difference sign; and
- three assets survive the fixed-cell BH correction.

The original unfiltered 1/1 sign asymmetry does not transport: only 27.6% of
assets share TSLA's sign and none has raw p below 0.05. The unfiltered 20/4,
20/5, and 20/10 sign cells show modest 65.5% same-sign breadth, but only the
20/10 cell has two fixed-cell BH survivors. The atlas therefore strengthens
the broad signed-ER20 DOWN-state rebound finding much more than it strengthens
the earlier general sign-asymmetry story.

## Interpretation

The broad result is a conditional shape: while an asset is already in a
signed-ER20 DOWN path, more negative completed returns tend to align with less
negative or more positive following returns. It is a cross-asset rebound
geometry, not evidence that all DOWN-state observations have positive future
returns and not a ready-made long signal.

Important limitations remain:

- signed ER20 and the prior-return predictor share the same trailing path;
- at prior horizon 20 the signed-ER numerator and prior return share the exact
  signed displacement, so the conditioning geometry is partly mechanical;
- overlapping windows and common market dates create strong dependence;
- correlation and slope do not establish expectancy after drift, timing, and
  trading costs; and
- no later period has tested temporal transport.

The raw pooled scatter is retained only as a morphology view. Equal-asset
medians, group breadth, fixed-cell inference, and leave-one-asset-out summaries
are the primary cross-asset readouts.

## Decision

Status:

`DESCRIPTIVE_ATLAS_COMPLETE_DOWN_REBOUND_TRANSPORTS_BROADLY_STOP_BEFORE_FINE_GRID`

The atlas validates the decision to transport before zooming. It also changes
where a future local refinement should focus: the repeated neighborhood is
roughly 15-25 prior and 15-25 following sessions, not specifically the proposed
6-9-session gap. Keep both finer-horizon work and post-2023 temporal transport
closed until the operator reviews this shape and explicitly chooses the next
gate.

## Artifacts

- Packet:
  `runs/research_workbench/operator_hypothesis_lab/own_asset_return_geometry_atlas_20260826`
- Frozen registry:
  `operator_hypothesis_lab/registries/own_asset_return_geometry_atlas.csv`
- Runner:
  `scripts/inspect/run_own_asset_return_geometry_atlas.R`
- Reusable helpers:
  `operator_hypothesis_lab/R/own_asset_return_geometry_atlas.R`
- Running evidence deck:
  `operator_hypothesis_lab/presentations/tsla_descriptive_microscope_evidence.pptx`
