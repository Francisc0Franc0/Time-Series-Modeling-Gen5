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

## Behavioral Catalog Synthesis

The same microscope can be read as a descriptive vocabulary rather than a
search for one recurring cell. Prior-return sign and the within-branch slope
define four archetypes:

| Prior branch | Positive slope | Negative slope |
|---|---|---|
| Positive prior return | gain continuation | gain exhaustion |
| Negative prior return | loss continuation | loss rebound |

For this post-atlas catalog, a cell is called cross-asset supported only when
at least 20 assets are estimable and at least 60% of them share the same slope
sign. These are display rules for organizing the already-inspected atlas, not
new inferential thresholds. A state is labeled broad when at least half its
eligible cells are supported, a cluster when at least one fifth are supported,
and a pocket when at least three cells are supported.

The eight frozen conditioning states reveal distinct behavior profiles:

| State | Eligible cells | Gain continuation | Gain exhaustion | Loss rebound | Loss continuation |
|---|---:|---:|---:|---:|---:|
| Unfiltered | 81 | 5 | 44 | 65 | 4 |
| Path sideways | 81 | 39 | 26 | 55 | 5 |
| Path trending | 81 | 0 | 72 | 70 | 1 |
| Signed up | 45 | 0 | 41 | 16 | 6 |
| Signed down | 36 | 7 | 2 | 24 | 1 |
| ATR low | 81 | 17 | 28 | 65 | 0 |
| ATR medium | 81 | 10 | 27 | 18 | 17 |
| ATR high | 81 | 9 | 40 | 71 | 2 |

The strongest atlas-wide pattern is therefore loss rebound, especially in
high-ATR and path-trending states. Gain exhaustion is broad in path-trending
and signed-up states. Classical gain continuation is not universal, but it
does form a meaningful cluster in path-sideways cells and a smaller cluster in
low ATR%. Loss continuation is the least broadly represented archetype.

These geometries motivate mechanisms to falsify, not explanations already
established. Gradual information diffusion is one possible basis for the
sideways/low-volatility gain-continuation cluster. Extension and later-stage
repricing could underlie gain exhaustion. Overshoot, liquidity relief, short
covering, or volatility normalization could produce loss rebound. Persistent
bad-news repricing or forced deleveraging could produce loss continuation, but
that archetype is not broad in this atlas. Shared-path conditioning,
overlapping windows, drift, and common market dates remain serious alternative
explanations.

## Decision

Status:

`DESCRIPTIVE_ATLAS_COMPLETE_BOUNDARY_PROBE_OPEN_THROUGH_100_STOP_BEFORE_INCREMENTAL_DECOMPOSITION`

The atlas validated the decision to transport before zooming. The subsequently
approved 10-30 one-session refinement is now complete: signed-down loss
rebound occupies one 414-cell strong connected component, touches every edge
of the inspected grid, and is not pinned to 20 sessions. See
`OWN_ASSET_RETURN_GEOMETRY_REBOUND_TOPOLOGY_2018_2023.md`. Freeze that open
plateau/ridge and keep post-2023 temporal transport, further horizon expansion,
asset expansion, and trading interpretation closed until separately opened.

A subsequently approved sparse 30-100 boundary probe found that all 18
condition-by-orientation-by-anchor paths remained strong at every outer
checkpoint. The cumulative-return plateau is therefore still open at 100, but
the nested future targets do not identify when the response accrues. See
`OWN_ASSET_RETURN_GEOMETRY_REBOUND_BOUNDARY_PROBE_2018_2023.md`.

## Artifacts

- Packet:
  `runs/research_workbench/operator_hypothesis_lab/own_asset_return_geometry_atlas_20260826`
- Frozen registry:
  `operator_hypothesis_lab/registries/own_asset_return_geometry_atlas.csv`
- Runner:
  `scripts/inspect/run_own_asset_return_geometry_atlas.R`
- Reusable helpers:
  `operator_hypothesis_lab/R/own_asset_return_geometry_atlas.R`
- Behavioral-catalog runner:
  `scripts/inspect/run_return_geometry_behavior_catalog.R`
- Behavioral-catalog packet:
  `runs/research_workbench/operator_hypothesis_lab/return_geometry_behavior_catalog_20260826`
- Fine-grid topology results:
  `operator_hypothesis_lab/docs/OWN_ASSET_RETURN_GEOMETRY_REBOUND_TOPOLOGY_2018_2023.md`
- Fine-grid topology packet:
  `runs/research_workbench/operator_hypothesis_lab/return_geometry_rebound_topology_20260827`
- Fine-grid topology runner:
  `scripts/inspect/run_return_geometry_rebound_topology.R`
- Sparse boundary-probe results:
  `operator_hypothesis_lab/docs/OWN_ASSET_RETURN_GEOMETRY_REBOUND_BOUNDARY_PROBE_2018_2023.md`
- Sparse boundary-probe packet:
  `runs/research_workbench/operator_hypothesis_lab/return_geometry_rebound_boundary_probe_20260827`
- Sparse boundary-probe runner:
  `scripts/inspect/run_return_geometry_rebound_boundary_probe.R`
- Running evidence deck:
  `operator_hypothesis_lab/presentations/tsla_descriptive_microscope_evidence.pptx`
