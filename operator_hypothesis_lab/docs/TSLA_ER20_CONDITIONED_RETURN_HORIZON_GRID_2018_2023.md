# TSLA ER20-Conditioned Cumulative Return Horizon Grid

## Question

Could prior-versus-forward cumulative signed-return dependence be stronger in
some path regimes and weaker in others, causing the relationship to wash out
when red and green ER20 observations are pooled?

This is a direct follow-up to two completed descriptive slices:

- the fixed 9 x 9 prior-versus-forward cumulative-return grid; and
- the fixed causal ER20 path-regime visualization.

No new regime metric, threshold, return horizon, asset, or confirmation period
was selected for this comparison.

## Fixed Conditioning Rule

The state at anchor close `t` reproduces the prior ER POC exactly:

`ER20[t] = abs(log_close[t] - log_close[t-20]) / sum(abs(one-session log moves))`

- Red / sideways: `ER20[t] < 0.30`.
- Green / trending: `ER20[t] >= 0.30`.
- ER20 at `t` uses only closes through `t`.
- The prior cumulative return ends at `t`.
- The following cumulative return begins after `t`.
- The predeclared prior and forward horizons remain
  `1, 2, 3, 4, 5, 10, 15, 20, 25` sessions.
- Anchor sessions are restricted to the visible 2018-2023 ER ledger. The one
  pre-2018 anchor whose forward window begins in 2018 is not assigned a color.

The result is 162 regime-specific cells and 81 direct red-versus-green
comparisons. Regime sample sizes range from 547 to 957 observations per cell.

## What Changed Visually

The aggregate grid's weak positive ridge separates into visibly different
surfaces:

- Red observations contain a coherent positive island centered around roughly
  10-15 prior sessions and 3-10 following sessions.
- Green observations retain small positive patches at short horizons, but the
  red medium-horizon island is muted or reversed.
- The green long-prior / long-forward corner becomes increasingly negative.

The clearest example is the 15-prior / 5-forward cell:

| Surface | Pearson correlation | R-squared |
|---|---:|---:|
| Aggregate | +0.0554 | 0.307% |
| Red / sideways | +0.1727 | 2.983% |
| Green / trending | -0.0578 | 0.335% |
| Green minus red | -0.2306 | — |

This is an intuitive example of the proposed washout mechanism: pooling two
states with different point estimates produces a much smaller aggregate
correlation.

## Strongest Regime-Specific Cells

### Red / Sideways

- Largest absolute Pearson: `+0.1727` at 15 prior / 5 forward.
- Observations: `953`.
- Overlap-aware HAC correlation-equivalent interval:
  `[-0.0112, +0.3566]`.
- Raw HAC slope p-value: `0.0657`.
- Within-red BH q-value across 81 cells: `0.7334`.
- R-squared: `2.983%`.

### Green / Trending

- Largest absolute Pearson: `-0.1542` at 25 prior / 25 forward.
- Observations: `547`.
- Overlap-aware HAC correlation-equivalent interval:
  `[-0.4590, +0.1507]`.
- Raw HAC slope p-value: `0.3216`.
- Within-green BH q-value across 81 cells: `0.9454`.
- R-squared: `2.377%`.

Neither regime has a raw within-regime slope p-value below 0.05. Neither has a
BH-FDR pass.

## Direct Red-Versus-Green Comparison

The largest absolute correlation contrast is again 15 prior / 5 forward:

- Red Pearson: `+0.1727`.
- Green Pearson: `-0.0578`.
- Green-minus-red Pearson difference: `-0.2306`.
- Green-minus-red OLS slope interaction: `-0.1836`.
- Interaction HAC 95% interval: `[-0.3483, -0.0189]`.
- Raw interaction p-value: `0.0289`.
- Interaction BH q-value across 81 cells: `0.9159`.

Two of 81 slope interactions have raw p-values below 0.05. Zero of 81 survive
BH-FDR. The slope interaction is the overlap-aware inferential comparison; the
displayed correlation difference is a descriptive effect-size contrast rather
than the interaction coefficient itself.

## Interpretation

The data support the narrow descriptive thesis that the prior-versus-forward
return map looks different in red and green ER20 states. The pattern is broad
enough to be more interesting than one isolated cell, and the 15-prior /
5-forward example shows how pooling can attenuate opposing point estimates.

The data do not yet establish a stable regime-dependent return relationship:

- every strongest within-regime interval includes zero;
- no red or green signed-return cell survives the 81-cell scan;
- no red-versus-green interaction survives the 81-cell scan; and
- green has fewer observations, particularly at the longest forward horizons.

The correct status is therefore a coherent conditional pattern, not a
confirmed moderator, predictive model, edge, or trading rule.

## Important Mechanical Caveat

ER20 and the prior-return variable are both functions of the trailing price
path. Conditioning on ER20 can reveal a useful path state known at the anchor,
but it can also create selection effects tied to the geometry of that same
past path. This slice does not identify ER20 as a separately causal moderator.

A future comparison using a regime variable less mechanically entangled with
the prior return would help distinguish genuine state dependence from this
conditioning geometry.

## Artifacts

- Complete regime-specific table:
  `runs/research_workbench/operator_hypothesis_lab/tsla_er20_conditioned_return_horizon_grid_20260825/conditioned_horizon_grid_statistics.csv`
- Direct red-versus-green comparisons:
  `regime_comparison_statistics.csv` in the same packet.
- Red, green, green-minus-red, R-squared, interaction-q, and sample-size matrix
  CSVs in the same packet.
- Overview heatmaps: `visuals/` in the same packet.
- Reproduction script:
  `scripts/inspect/run_tsla_er20_conditioned_return_horizon_grid.R`.
- Running evidence deck:
  `operator_hypothesis_lab/presentations/tsla_descriptive_microscope_evidence.pptx`.
