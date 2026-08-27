# Own-Asset Loss-Rebound Topology

## Question

After the frozen 30-asset atlas transported the signed-ER20 DOWN loss-rebound
neighborhood, does a one-session-resolution map reveal a bounded island, a
narrow feature pinned to the 20-session signed-ER measurement window, or a
broad plateau/ridge?

## Frozen Slice

- Same 30 assets and six equal behavioral groups as the prior atlas.
- Same adjusted daily bars and 2018-01-02 through 2023-12-29 analysis window.
- Same cumulative close-to-close log-return construction.
- Prior and following horizons `10:30`, inclusive, in one-session increments.
- Negative-prior branch only.
- Primary view: signed-ER20 `DOWN_TREND`.
- Descriptive comparators: unfiltered and ATR% `HIGH`.
- Equal-asset medians, cross-asset sign breadth, group medians, connected
  regions, and cross-sections through window 20.
- No cellwise inference, BH scan, later-period data, asset expansion,
  parameter selection, or trading calculation.

The 441 cells within a surface are not independent. Neighboring prior and
following windows share most observations, so the fine grid is a morphology
view rather than 441 separate confirmations.

## Predeclared Display Rules

A cell is breadth-supported when at least 20 assets are estimable, its
equal-asset median Pearson correlation is negative, and at least 60% of assets
have a negative within-loss correlation. A strong cell additionally requires
median Pearson at or below `-0.10` and at least 70% negative assets.

Four-neighbor connectivity is used only to describe the shape. A strong
component that reaches any boundary of the 10-30 grid is called an
`OPEN_PLATEAU_OR_RIDGE`; it cannot be called a bounded island because the
surface is still open beyond the inspected window.

## Result

All eight run checks passed, including exact coarse-anchor parity with the
earlier 10/15/20/25 atlas cells.

| Loss branch | Breadth-supported | Strong | Largest strong component | Shape | Strongest median cell | 20/20 median |
|---|---:|---:|---:|---|---:|---:|
| Unfiltered | 437/441 | 289/441 | 289 | Open plateau/ridge | 24/20, `-0.1705` | `-0.1219` |
| ATR% high | 441/441 | 421/441 | 421 | Open plateau/ridge | 18/24, `-0.2929` | `-0.2539` |
| Signed-ER20 down | 440/441 | 414/441 | 414 | Open plateau/ridge | 20/26, `-0.2606` | `-0.2087` |

The signed-down result is therefore not a small 20/20 island. Its largest
strong connected component spans prior horizons 10-30 and following horizons
10-30 and touches the inspection boundary. The 20-session row and column are
locally ordinary rather than singular: the signed-down prior-20 row median is
only `-0.0036` below its adjacent rows, and the following-20 column median is
`-0.0099` below its adjacent columns.

ATR%-high losses produce the broadest and most negative descriptive surface.
That comparison is useful because it shows that the shape is not unique to the
signed-ER20 conditioning rule. It does not establish that volatility causes a
rebound or that ATR%-high is a trading filter.

All six signed-down behavioral-group surfaces are available separately. Their
shapes differ materially: defensive equities and equity ETFs are the most
uniformly negative, while mature growth, non-equity proxies, and the short end
of operator/high-beta are more mixed. Five assets per group are enough to keep
these differences visible, but not enough for population-level asset-class
claims.

## Interpretation

This pass reduces one important measurement-coupling concern. If the apparent
rebound existed only because the prior return and signed-ER20 numerator share
an exact 20-session displacement, the fine surface should have shown a narrow
notch or ridge pinned to 20. Instead, the cross-sections vary smoothly and the
strong region extends throughout most of the inspected window.

That is evidence about morphology, not mechanism or edge. Overlapping
observations, common calendar shocks, drift, selection of the 10-30 region
after the coarse atlas, and shared trailing-path conditioning all remain. A
negative within-loss slope also does not say that the average following return
is positive or realizable after timing and costs.

The current 30-asset atlas is sufficient for the approved question—whether the
coarse neighborhood was a TSLA-only or exact-window artifact. It is not a
complete representation of every asset type. More names per group would be a
separate breadth-expansion study and should not be used to make this same
descriptive surface look more certain.

## Sparse Boundary-Probe Addendum

The operator subsequently opened a sparse 30-100 boundary probe. It retained
the same 30 assets, dates, states, negative-prior branch, and descriptive rules,
then varied one horizon through `35, 40, 50, 75, 100` while holding the other at
`20`, `25`, or `30`. All 18 condition-by-orientation-by-anchor paths remained
strong at every outer checkpoint. At 100 sessions, the signed-down equal-asset
median correlation ranges from `-0.213` to `-0.251` when prior is varied and
from `-0.288` to `-0.326` when following is varied.

This extends the morphological description but not the trading conclusion.
The cumulative relationship remains open through 100; nested future returns do
not establish that rebound return continues accruing through session 100. See
`OWN_ASSET_RETURN_GEOMETRY_REBOUND_BOUNDARY_PROBE_2018_2023.md`.

## Decision

Status:

`DESCRIPTIVE_BOUNDARY_PROBE_COMPLETE_CUMULATIVE_REBOUND_PERSISTS_THROUGH_100_STOP_BEFORE_INCREMENTAL_DECOMPOSITION`

Freeze the 10-30 topology and sparse 30-100 boundary result as one open
cumulative-return plateau/ridge. Do not name 20/20, 20/26, 18/24, 50, 75, 100,
or any other cell as a selected parameter or holding period. The next meaningful
gate is a separately frozen incremental-return decomposition or temporal
transport—not a denser horizon search.

## Artifacts

- Packet:
  `runs/research_workbench/operator_hypothesis_lab/return_geometry_rebound_topology_20260827`
- Runner:
  `scripts/inspect/run_return_geometry_rebound_topology.R`
- Parent atlas:
  `runs/research_workbench/operator_hypothesis_lab/own_asset_return_geometry_atlas_20260826`
- Frozen registry:
  `operator_hypothesis_lab/registries/own_asset_return_geometry_atlas.csv`
- Sparse boundary-probe results:
  `operator_hypothesis_lab/docs/OWN_ASSET_RETURN_GEOMETRY_REBOUND_BOUNDARY_PROBE_2018_2023.md`
- Sparse boundary-probe packet:
  `runs/research_workbench/operator_hypothesis_lab/return_geometry_rebound_boundary_probe_20260827`
- Sparse boundary-probe runner:
  `scripts/inspect/run_return_geometry_rebound_boundary_probe.R`
- Running evidence deck:
  `operator_hypothesis_lab/presentations/tsla_descriptive_microscope_evidence.pptx`
