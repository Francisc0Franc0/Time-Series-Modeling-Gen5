# Daily Continuation Microscope

## Purpose

This research volume separates the weaker but coherent momentum/continuation
line from the stronger loss-rebound line. It first assembled the descriptive
2018-2023 evidence, then translated one literal version of the lead into a
causal next-open TRAIN rule. The translation is intentionally minimal: it
tests mechanics and matched baselines without selecting a horizon or opening
post-2023 outcomes.

The registered lead is:

- ID: `BEHAV-MOM-01`;
- nickname: `Sideways Gain Continuation`;
- maturity: `Proto-strategy`; and
- status: `TRAIN_NEXT_OPEN_HORIZON_COMPARISON_COMPLETE_STOP_BEFORE_SELECTION_OR_OOS`.

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

## Initial Evidence Boundary

The descriptive assembly selected no prior or following horizon, trading rule,
baseline, cost model, portfolio replay, feature, threshold, or model. It also
left post-2023 and 30-minute data sealed. The later executable slice opened
only the explicitly frozen daily mechanics and matched TRAIN baselines below.

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

## Minimal Next-Open Rule Translation

The operator approved a direct daily translation rather than an optimized
search. At completed close `t`, the primary rule requires:

- completed 20-session log return `R20 > 0`;
- causal path-efficiency state `ER20 < 0.30` (sideways/red);
- entry at open `t+1`;
- exit after `5`, `10`, or `20` held sessions;
- one live position per asset/rule/horizon, ignoring signals until exit; and
- `10 bp` round-trip cost.

Four matched references were calculated on the same next-open clock:
trending-plus-positive-R20, positive-R20-only, sideways-only, and unconditional
same-horizon drift. All 129 frozen instruments remain visible, while the
88-stock, 11-sector equal-sector core is the primary aggregation. The complete
calculation remains inside 2018-2023 TRAIN.

All 16 construction checks passed. Under the equal-sector median-asset lens,
the primary rule returned approximately `+5 bp`, `+23 bp`, and `+66 bp` net per
trade at 5, 10, and 20 sessions. Those positive levels do not clear the basic
drift comparison: excess versus unconditional same-horizon drift was `-16 bp`,
`-10 bp`, and `-14 bp` respectively, with only 1, 2, and 4 of 11 sector medians
positive.

The state contrast is more nuanced. Sideways-plus-positive-R20 beat
trending-plus-positive-R20 at 20 sessions under both aggregation lenses:
approximately `+38 bp` under the equal-sector median and `+5 bp` when events
are pooled. It did not do so at both 5 and 10 sessions. Moreover, the positive
R20 condition itself did not add value to the sideways state: the primary rule
trailed sideways-only by about `7 bp`, `9 bp`, and `14 bp` at the three holds.

The executable conclusion is therefore not “20 sessions wins.” It is:

- the literal rule is mechanically viable and produces positive raw returns;
- no frozen hold improves on ordinary drift;
- only the 20-session sideways-versus-trending contrast is directionally
  consistent under both weighting lenses; and
- the sign condition appears to detract rather than help.

Current status:

`TRAIN_NEXT_OPEN_HORIZON_COMPARISON_COMPLETE_STOP_BEFORE_SELECTION_OR_OOS`

## Next Gate

Do not select the 20-session hold, tune the ER threshold, or query post-2023
outcomes from this readout. The next operator huddle should decide whether the
20-session state contrast warrants a separately predeclared mechanism test
without the positive-R20 condition, or should remain descriptive context.

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
- Next-open rule packet:
  `runs/research_workbench/operator_hypothesis_lab/return_geometry_continuation_next_open_rule_20260829`.
- Next-open rule runner:
  `scripts/inspect/run_return_geometry_continuation_next_open_rule.R`.
- Next-open rule helpers:
  `operator_hypothesis_lab/R/return_geometry_continuation_next_open_rule.R`.
- TSLA aggregate source note:
  `operator_hypothesis_lab/docs/TSLA_CUMULATIVE_RETURN_HORIZON_GRID_2018_2023.md`.
- TSLA ATR% source note:
  `operator_hypothesis_lab/docs/TSLA_ATRP_CONDITIONED_RETURN_HORIZON_GRID_2018_2023.md`.
- 30-asset atlas source note:
  `operator_hypothesis_lab/docs/OWN_ASSET_RETURN_GEOMETRY_ATLAS_2018_2023.md`.
- 129-instrument atlas source note:
  `operator_hypothesis_lab/docs/RETURN_GEOMETRY_WIDE_ATLAS_2018_2023.md`.
