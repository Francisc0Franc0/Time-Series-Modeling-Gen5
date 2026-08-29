# Daily Continuation Microscope

## Purpose

This slice separates the weaker but coherent momentum/continuation line from
the stronger loss-rebound line. It does not calculate a new outcome, select a
new horizon, or promote a strategy. It assembles the already-computed
2018-2023 evidence into one operator-facing research volume and gives the line
a durable registry identity.

The registered lead is:

- ID: `BEHAV-MOM-01`;
- nickname: `Sideways Gain Continuation`;
- maturity: `Behavioral lead`; and
- status: `DESCRIPTIVE_BEHAVIORAL_LEAD`.

The existing rebound implementation is registered separately as
`PROTO-MR-01`, `Volume-Veto Rebound`. The two lines are not treated as variants
of the same strategy.

## Narrative Hypothesis

After an asset has a positive completed return, its following return may be
more continuation-shaped when the completed path is inefficient or sideways,
or when movement capacity is low to moderate. Efficient trending paths may
instead be later-stage moves that lean toward gain exhaustion.

This is a conditional behavioral thesis. It is not the claim that positive
returns generally predict positive returns.

## Existing Evidence Assembled

### TSLA Origin

The fixed TSLA 9 by 9 cumulative-return grid reveals a weak positive ridge near
five to ten prior or following sessions. The largest Pearson estimate is about
`+0.092`, explains less than one percent of forward-return variance, and does
not survive the complete 81-cell multiplicity family. This earns a visual lead,
not a representative horizon.

### TSLA ATR% Conditioning

The accepted causal ATR% states separate the TSLA surface more clearly. LOW and
MEDIUM states are positive across the complete grid; HIGH is predominantly
negative. Three MEDIUM-state cells survive the stricter 486-test BH family.
The same sample still motivated and evaluated the conditional view, so this
does not open a rule or confirmation claim.

### 30-Asset Behavioral Catalog

The frozen 30-asset atlas turns the method into a four-behavior vocabulary:
gain continuation, gain exhaustion, loss rebound, and loss continuation. Under
the post-hoc catalog display rules, gain continuation appears in `39 / 81`
path-sideways cells and `17 / 81` ATR%-low cells, but in `0 / 81`
path-trending cells. Trending and signed-up states instead lean strongly toward
gain exhaustion.

These counts organize inspected morphology. They are not inferential gates.

### 129-Instrument Atlas

The wider sector-balanced atlas preserves the same positive-prior contrast at
small magnitude:

- ER20-sideways gain cells: median correlation `+0.027`, with `81.8%` of 225
  cells positive; and
- ER20-trending gain cells: median correlation `-0.028`, with `27.6%` of 225
  cells positive.

The result is broad enough to preserve as a hypothesis-generation clue and too
small and research-conditioned to call edge.

## Evidence Boundary

This slice adds no:

- selected prior or following horizon;
- next-open trading rule;
- drift, state-only, or exposure-matched baseline;
- transaction-cost or portfolio replay;
- new feature, threshold, or model;
- post-2023 query; or
- 30-minute calculation.

Post-2023 evidence remains sealed.

## Approved Sideways-Versus-Trending Contrast

The operator selected the direct contrast for fuller context:

> After a positive completed return, continuation is stronger in an
> ER20-sideways state than in an ER20-trending state.

The slice re-expressed the already-computed full-vocabulary atlas rather than
recomputing bars or returns. For every asset and prior/following horizon cell,
the positive-prior correlation in the causal ER20-trending state was subtracted
from the corresponding ER20-sideways correlation. The primary aggregation then
took asset medians within each of the 11 frozen sectors and an equal-sector
median across sectors.

Across the complete 15 by 15 surface:

- ER20-sideways median correlation is `+0.027`;
- ER20-trending median correlation is `-0.028`;
- the paired sideways-minus-trending median is `+0.048`;
- `209 / 225`, or `92.9%`, of cells favor sideways; and
- all 11 sectors have positive median paired contrasts across their 225-cell
  surfaces, with positive-cell breadth ranging from `62.2%` to `85.8%`.

The result is broad but not uniform. Sixteen cells do not favor sideways.
Exceptions cluster at the shortest horizons, several 20-session-prior / long-
forward combinations, and the `100 -> 100` diagonal cell. In the frozen
5/10/15/20-session lead region, `15 / 16` cells favor sideways and the median
paired contrast is `+0.047`.

There are `29,024 / 29,025` complete asset-level pairs. The one explicit blank
is RIVN's `100 -> 100` trending positive-prior branch, which has 24 observations
and therefore remains below the inherited 30-observation minimum. RIVN is a
partial-history attention name and does not enter the 88-stock core headline.

The contrast is a difference in correlations, not a return, spread trade, or
execution result. The same 2018-2023 history revealed and evaluated the state
split, the cumulative cells overlap, and no multiplicity or independent-
confirmation claim is attached to the 92.9% morphology.

Current status:

`DESCRIPTIVE_PAIRED_STATE_CONTRAST_COMPLETE_STOP_BEFORE_HORIZON_OR_RULE_SELECTION`

## Next Gate

Do not select the strongest observed cell. The next operator huddle should
decide whether to freeze one representative daily horizon together with causal
state timing, a next-open translation, a state-only/drift baseline, and an
explicit failure rule, or preserve this result as behavioral context while
opening the separately designed 30-minute lane.

The 30-minute lane remains bookmarked but design-only until its bar clock,
overnight-return treatment, horizon meaning, and any daily-to-intraday filter
timing are explicit.

## Artifacts

- Strategy candidate ledger:
  `operator_hypothesis_lab/registries/proto_strategy_ledger.xlsx`.
- Continuation microscope deck:
  `operator_hypothesis_lab/presentations/return_geometry_daily_continuation_microscope.pptx`.
- Paired state-contrast packet:
  `runs/research_workbench/operator_hypothesis_lab/return_geometry_continuation_state_contrast_20260828`.
- Paired state-contrast runner:
  `scripts/inspect/run_return_geometry_continuation_state_contrast.R`.
- Paired state-contrast helpers:
  `operator_hypothesis_lab/R/return_geometry_continuation_state_contrast.R`.
- TSLA aggregate source note:
  `operator_hypothesis_lab/docs/TSLA_CUMULATIVE_RETURN_HORIZON_GRID_2018_2023.md`.
- TSLA ATR% source note:
  `operator_hypothesis_lab/docs/TSLA_ATRP_CONDITIONED_RETURN_HORIZON_GRID_2018_2023.md`.
- 30-asset atlas source note:
  `operator_hypothesis_lab/docs/OWN_ASSET_RETURN_GEOMETRY_ATLAS_2018_2023.md`.
- 129-instrument atlas source note:
  `operator_hypothesis_lab/docs/RETURN_GEOMETRY_WIDE_ATLAS_2018_2023.md`.
