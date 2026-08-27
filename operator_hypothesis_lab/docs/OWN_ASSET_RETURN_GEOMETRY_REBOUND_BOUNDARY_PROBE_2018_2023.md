# Own-Asset Loss-Rebound Boundary Probe

## Question

The one-session 10-30 loss-rebound map ended at an open plateau rather than a
bounded island. Does that cumulative-return relationship decay soon after the
original boundary, or remain visible at materially longer windows?

## Frozen Slice

- Same 30 assets, six equal behavioral groups, and frozen registry as the
  preceding atlas and topology runs.
- Same adjusted daily bars and 2018-01-02 through 2023-12-29 analysis window.
- Same cumulative close-to-close log returns and negative-prior branch.
- Primary condition: signed-ER20 `DOWN_TREND`.
- Descriptive comparators: unfiltered and ATR% `HIGH`.
- Sparse checkpoints rather than a dense enlarged grid: vary
  `10:30, 35, 40, 50, 75, 100` while holding the other horizon at `20`, `25`,
  or `30`, in both orientations.
- Equal-asset median Pearson correlation, cross-asset sign breadth, behavioral
  group medians, and observation support.
- No cellwise inference, parameter selection, later-period data, asset
  expansion, strategy calculation, or holding-period decision.

The union contains 147 unique prior/following pairs, not a 100 by 100 search.
All cells shared with the 10-30 fine grid must reproduce exactly.

## Predeclared Descriptive Rules

The topology display rules were carried forward unchanged. A checkpoint is
breadth-supported when at least 20 assets are estimable, its equal-asset median
Pearson correlation is negative, and at least 60% of assets have a negative
within-loss correlation. A strong checkpoint additionally requires median
Pearson at or below `-0.10` and at least 70% negative assets.

These rules summarize cross-sectional morphology. They are not statistical
significance thresholds or trading gates.

## Result

All 12 run checks passed. Exact parity with the preceding 10-30 packet held at
every shared cross-section cell. All 18 condition-by-orientation-by-anchor
paths remained breadth-supported and strong at each outer checkpoint: 35, 40,
50, 75, and 100 sessions.

At the 100-session boundary:

| Condition | Varied horizon | Fixed horizons | Median Pearson range | Negative-asset breadth | Median branch observations |
|---|---|---|---:|---:|---:|
| Unfiltered | Prior | Following 20/25/30 | `-0.204` to `-0.215` | 90.0%-93.3% | 529 |
| Unfiltered | Following | Prior 20/25/30 | `-0.157` to `-0.179` | 83.3%-93.3% | 573-580 |
| ATR% high | Prior | Following 20/25/30 | `-0.265` to `-0.282` | 90.0%-93.3% | 278 |
| ATR% high | Following | Prior 20/25/30 | `-0.212` to `-0.234` | 83.3%-93.3% | 300-306 |
| Signed-ER20 down | Prior | Following 20/25/30 | `-0.213` to `-0.251` | 86.7%-93.3% | 121 |
| Signed-ER20 down | Following | Prior 20/25/30 | `-0.288` to `-0.326` | 90.0%-93.3% | 146-154 |

The primary signed-down surface therefore does not reveal a cumulative-return
decay boundary by 100 sessions. With the prior horizon fixed at 20-30 and the
following window extended to 100, equal-asset median correlation is especially
negative (`-0.29` to `-0.33`). The comparison surfaces tell the same broad
story: this is not unique to the exact signed-ER20 state.

The six five-asset groups remain heterogeneous. At the 100-session signed-down
boundary, equity ETFs are the most uniformly negative (group medians roughly
`-0.58` to `-0.67`), while non-equity proxies are much weaker when the following
window expands (roughly `-0.03` to `-0.06`). Cyclical/value and operator/high-beta
groups remain clearly negative. These small group panels are descriptive and
do not support population-level asset-class claims.

Observation support remains usable for this descriptive question. At the
signed-down 100-session boundary, the median per-asset negative-branch count is
121 when prior is varied and 146-154 when following is varied. The packet's
minimum asset-count guardrail is also satisfied throughout.

## Interpretation

This probe changes the morphological description from “open at 30” to
“cumulative relationship still open at 100.” It does not identify a preferred
horizon. A 100-session cumulative following return contains the earlier
1-20, 1-40, and 1-75 returns inside it. These targets are nested, highly
overlapping summaries of the same paths. A strong 100-session correlation may
therefore mean that the response occurred early and was merely carried inside
the longer total; it does not show that new rebound return continues to accrue
for 100 sessions.

The wider prior windows reduce one exact-coupling concern: a 100-session prior
return shares only its last 20 sessions with the signed-ER20 displacement.
Persistence away from exactly 20 is inconsistent with a singular measurement
notch. It still does not remove state-selection effects, overlapping windows,
common calendar shocks, drift, or the exploratory choice to investigate this
region after the original atlas.

## Decision

Status:

`DESCRIPTIVE_BOUNDARY_PROBE_COMPLETE_CUMULATIVE_REBOUND_PERSISTS_THROUGH_100_STOP_BEFORE_INCREMENTAL_DECOMPOSITION`

Freeze the sparse boundary result. Do not interpret 50, 75, or 100 as a holding
period, select the strongest endpoint, or fill the intervening grid. The next
high-signal question is a separately frozen incremental-return decomposition:
for example, ask how much of the following response occurs in sessions 1-20,
21-40, 41-60, and 61-100 while holding the conditioning and prior-return
definition fixed. That test would distinguish a long-lived response from a
short response embedded in a long cumulative target.

## Artifacts

- Packet:
  `runs/research_workbench/operator_hypothesis_lab/return_geometry_rebound_boundary_probe_20260827`
- Runner:
  `scripts/inspect/run_return_geometry_rebound_boundary_probe.R`
- Parent topology results:
  `operator_hypothesis_lab/docs/OWN_ASSET_RETURN_GEOMETRY_REBOUND_TOPOLOGY_2018_2023.md`
- Frozen registry:
  `operator_hypothesis_lab/registries/own_asset_return_geometry_atlas.csv`
- Running evidence deck:
  `operator_hypothesis_lab/presentations/tsla_descriptive_microscope_evidence.pptx`
