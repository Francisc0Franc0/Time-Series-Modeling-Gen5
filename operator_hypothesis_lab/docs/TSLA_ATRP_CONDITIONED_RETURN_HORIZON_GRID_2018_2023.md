# TSLA ATR%-Conditioned Cumulative Return Horizon Grid

## Question

Does the relationship between prior and following cumulative signed log
returns differ across LOW, MEDIUM, and HIGH average-true-range-percent states?

This is the next descriptive slice in the TSLA microscope. It holds the asset,
2018-2023 study period, 9 x 9 prior/forward horizon grid, return construction,
anchor timing, and uncertainty machinery fixed. Only the conditioning variable
changes from ER20 path efficiency to the previously accepted causal ATR%
classifier from HYP-REG-01.1.

## Fixed ATR% State Authority

The analysis reuses the accepted daily state ledger without reselecting an ATR
length, percentile memory, threshold, hysteresis rule, or number of bins:

- metric: Wilder ATR14 divided by adjusted close;
- percentile: current ATR% ranked against the preceding 252 completed ATR%
  observations, excluding the current session;
- LOW entry below the 30th percentile and exit above the 40th;
- HIGH entry above the 70th percentile and exit below the 60th;
- otherwise MEDIUM, with direct LOW-to-HIGH and HIGH-to-LOW jumps allowed; and
- state at anchor close `t` is known before the following return begins at
  `t+1`.

Accepted TSLA occupancy in the 1,509-session analysis ledger is LOW `581`,
MEDIUM `341`, and HIGH `587`. Depending on prior/forward completeness, each
grid cell contains 339 to 587 observations.

The pre-2018 adjusted TSLA prices needed for the longest prior-return windows
come from the same cached daily series used by the aggregate and ER20 grids.
The run stops unless all 2018-2023 closes match the accepted ATR% ledger.

## Price-Level State View

The companion price chart overlays those exact accepted states on TSLA's
adjusted close and shows the causal trailing ATR% percentile underneath. Blue
marks LOW movement capacity, gold MEDIUM, and red HIGH. The colors are not
directional labels: each state can occur during rising, falling, or sideways
price paths. The four dashed reference levels correspond to the accepted
30/40 and 60/70 hysteresis boundaries; the colored band itself remains the
authoritative operational state.

This is a descriptive alignment check. It adds no threshold search, outcome
selection, prediction, or strategy calculation.

## Visual Readout

The three correlation surfaces separate strongly by volatility state:

- LOW: all 81 cells are positive, with Pearson correlations from about `0.001`
  to `0.198`.
- MEDIUM: all 81 cells are positive, from about `0.020` to `0.270`, with a
  coherent medium-prior / short-forward continuation island.
- HIGH: 77 of 81 cells are negative, from about `-0.301` to `+0.028`, with
  increasingly negative values toward longer prior and forward horizons.

This is a cleaner directional separation than the earlier red-versus-green
ER20 result. Descriptively, prior cumulative return behaves more like
continuation in LOW/MEDIUM ATR% states and more like reversal in HIGH ATR%
states.

## Strongest Point Estimates Are Not the Most Stable Cells

| State | Strongest absolute cell | Pearson | HAC 95% correlation-equivalent interval | Within-state BH q | R-squared |
|---|---:|---:|---:|---:|---:|
| LOW | 10 prior / 25 forward | +0.1979 | [-0.0290, +0.4249] | 0.1416 | 3.918% |
| MEDIUM | 25 prior / 15 forward | +0.2695 | [-0.0502, +0.5893] | 0.1595 | 7.265% |
| HIGH | 20 prior / 20 forward | -0.3009 | [-0.6661, +0.0643] | 0.3243 | 9.053% |

Every interval in this table crosses zero. The darkest cells are useful
descriptive landmarks, but they are not the cells with the strongest
dependence-robust evidence.

Within the separate 81-cell state families, LOW has `0/81`, MEDIUM has `21/81`,
and HIGH has `0/81` BH-FDR passes. Under one stricter BH correction across all
486 within-state and pairwise tests, only three within-state cells pass, all in
MEDIUM ATR%:

| Prior / forward sessions | Pearson | HAC 95% interval | Omnibus BH q | R-squared |
|---:|---:|---:|---:|---:|
| 5 / 3 | +0.2427 | [+0.1116, +0.3738] | 0.0449 | 5.889% |
| 10 / 2 | +0.2228 | [+0.0985, +0.3471] | 0.0449 | 4.965% |
| 10 / 3 | +0.2498 | [+0.1122, +0.3874] | 0.0449 | 6.240% |

## Direct State Comparisons

The largest correlation contrast is MEDIUM versus HIGH at 25 prior / 15
forward sessions:

- MEDIUM Pearson: `+0.2695`;
- HIGH Pearson: `-0.2784`;
- HIGH-minus-MEDIUM correlation difference: `-0.5479`;
- direct slope-interaction HAC p-value: `0.0202`; and
- within-comparison-family BH q-value: `0.0383`, but strict omnibus BH q-value:
  `0.0810`.

The largest visual contrast therefore does not survive the complete 486-test
correction. Three smaller HIGH-minus-MEDIUM interactions do:

| Prior / forward sessions | MEDIUM Pearson | HIGH Pearson | Difference | Omnibus BH q |
|---:|---:|---:|---:|---:|
| 5 / 4 | +0.2284 | -0.0955 | -0.3239 | 0.0463 |
| 5 / 5 | +0.2416 | -0.0953 | -0.3369 | 0.0449 |
| 20 / 3 | +0.2222 | -0.1186 | -0.3407 | 0.0449 |

Across the separate pairwise families, MEDIUM-minus-LOW has `0/81`,
HIGH-minus-LOW has `36/81`, and HIGH-minus-MEDIUM has `50/81` interaction
passes. The direct inferential test is the HAC slope interaction; the displayed
correlation difference is a descriptive effect-size contrast.

## Interpretation

The narrow descriptive thesis survives: pooling volatility states can conceal
opposing signed-return relationships. In this historical TSLA sample, the
clearest candidate mechanism is not simply "trend versus sideways." It is that
moderate movement capacity coincides with short-horizon continuation, whereas
high movement capacity coincides with a broad reversal-shaped surface.

This is not yet an edge or a trading rule:

- the same 2018-2023 data motivated and evaluated the conditional view;
- the 81 cells are highly dependent because their horizons overlap and nest;
- ATR% is an own-asset trailing-price variable, so temporal clustering and
  conditioning geometry remain possible explanations;
- the MEDIUM sample is the smallest state; and
- no post-2023 replication or prospective confirmation was opened.

The right status is **an unexpectedly coherent, partially multiplicity-robust
conditional pattern worth a separately frozen replication**, not confirmation
of volatility-gated momentum or reversal.

## Bookmarked Follow-Ups

These ideas are recorded but not opened by this slice:

1. Split green ER20 path-efficiency anchors into causal uptrend versus downtrend
   direction, then rerun the fixed grid.
2. Condition the fixed grid on an external market-context cue rather than only
   TSLA's own trailing data.

## Artifacts

- Complete 243-row state table:
  `runs/research_workbench/operator_hypothesis_lab/tsla_atrp_conditioned_return_horizon_grid_20260825/conditioned_horizon_grid_statistics.csv`.
- Complete 243-row direct-comparison table:
  `pairwise_state_comparison_statistics.csv` in the same packet.
- LOW, MEDIUM, HIGH, difference, R-squared, sample-size, and q-value matrices:
  the same packet.
- Price/state chart:
  `visuals/tsla_atrp_state_price_bands.png` in the same packet.
- Frozen chart inputs: `tsla_atrp_state_chart_ledger.csv` and
  `tsla_atrp_state_spans.csv` in the same packet.
- Heatmaps: the other files in `visuals/` in the same packet.
- Reproduction script:
  `scripts/inspect/run_tsla_atrp_conditioned_return_horizon_grid.R`.
- Running evidence deck:
  `operator_hypothesis_lab/presentations/tsla_descriptive_microscope_evidence.pptx`.
