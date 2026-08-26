# TSLA Return Grid Conditioned on QQQ ATR%

## Question

Can the accepted ATR-percent movement-capacity state of QQQ organize the
relationship between TSLA's prior and following cumulative signed log returns?

This is a one-variable substitution of the completed SPY external-context
slice. TSLA remains the return asset, the 2018-2023 sample and 9 x 9 horizon
grid remain fixed, and the LOW, MEDIUM, and HIGH labels now come from QQQ's
accepted HYP-REG-01.1 ATR-percent classifier. QQQ is an external price series
but an economically overlapping, technology-heavy context for TSLA, so this is
best described as **quasi-external conditioning**.

## Frozen Design

- return asset: TSLA;
- state authority: QQQ;
- metric: Wilder ATR14 divided by QQQ adjusted close;
- percentile: current QQQ ATR% ranked against the preceding 252 completed QQQ
  ATR% observations, excluding the current session;
- state machine: LOW with 30/40 hysteresis, HIGH with 70/60 hysteresis, and
  otherwise MEDIUM;
- timing: QQQ state is known at TSLA anchor close `t`; the TSLA forward-return
  interval begins after `t`;
- horizons: prior and forward `1, 2, 3, 4, 5, 10, 15, 20, 25` sessions;
- uncertainty: overlap-aware Newey-West/HAC intervals;
- multiplicity: BH-FDR within each 81-cell state or pairwise family and a
  pooled BH-FDR check across all 486 tests; and
- no post-2023 read, trading calculation, or strategy authority.

The 1,509-session state ledger contains LOW `574`, MEDIUM `390`, and HIGH `545`
QQQ sessions. All state dates align with the TSLA return dates, and the TSLA
adjusted closes exactly match the accepted TSLA ledger.

## Visual Readout

- **QQQ LOW:** `77/81` correlations are positive. The surface contains a broad
  continuation ridge, strongest at `+0.2602` for 10 prior / 5 forward sessions.
  Its HAC interval is `[+0.0869, +0.4335]`, but its within-LOW BH q-value is
  `0.0509`: close to, but not below, the declared `0.05` boundary.
- **QQQ MEDIUM:** `44/81` cells are positive and `37/81` are negative. Short
  windows are mostly positive, while longer prior/forward combinations turn
  negative. The strongest absolute cell is `-0.2238` at 20 prior / 25 forward.
- **QQQ HIGH:** `59/81` cells are negative, but the map is mild. The strongest
  absolute cell is `-0.1123` at 25 prior / 15 forward.

The largest direct state contrast is QQQ MEDIUM-minus-LOW at 10 prior / 15
forward: LOW is `+0.2065`, MEDIUM is `-0.1354`, and the difference is `-0.3420`.
Its raw interaction p-value is `0.0043`, but its within-family BH q-value is
`0.2739`.

## Multiplicity Readout

- within-state BH-FDR passes: LOW `0/81`, MEDIUM `0/81`, HIGH `0/81`;
- pairwise interaction BH-FDR passes: `0/243`; and
- strict omnibus passes across all 486 tests: `0`.

The correct statistical statement is therefore not that QQQ LOW "passes." The
LOW ridge is visually coherent and contains the slice's nearest family-adjusted
result, but it remains on the non-passing side of the frozen boundary.

## Three-Way Context Comparison

| State | Authority | Mean correlation | Positive cells | Sign agreement vs TSLA-own | Map correlation vs TSLA-own |
|---|---|---:|---:|---:|---:|
| LOW | TSLA-own | +0.1177 | 81/81 | 81/81 | +1.000 |
| LOW | SPY | +0.0905 | 72/81 | 72/81 | +0.665 |
| LOW | QQQ | +0.1227 | 77/81 | 77/81 | +0.650 |
| MEDIUM | TSLA-own | +0.1609 | 81/81 | 81/81 | +1.000 |
| MEDIUM | SPY | -0.0579 | 14/81 | 14/81 | +0.108 |
| MEDIUM | QQQ | -0.0097 | 44/81 | 44/81 | +0.087 |
| HIGH | TSLA-own | -0.0831 | 4/81 | 81/81 | +1.000 |
| HIGH | SPY | +0.0306 | 60/81 | 25/81 | +0.800 |
| HIGH | QQQ | -0.0215 | 22/81 | 63/81 | +0.586 |

QQQ LOW preserves the own-asset continuation geometry at least as broadly as
SPY LOW. QQQ MEDIUM weakens and partially reverses the own-asset MEDIUM map, but
less completely than SPY MEDIUM. QQQ HIGH remains mostly negative and therefore
resembles the sign of TSLA-own HIGH more than SPY HIGH does. Identically named
ATR% states are not universal regimes; the asset owning the classifier matters.

## Interpretation and Stop

QQQ movement capacity partitions the TSLA surface coherently enough to remain a
useful descriptive cue. The clearest pattern is LOW continuation versus a
MEDIUM long-horizon deterioration, while HIGH is muted rather than a strong
reversal state.

This result does not establish causal transmission, independent information, or
a tradable edge. QQQ and TSLA share market shocks and economic exposure; the
horizon cells overlap and nest; and the same historical sample motivated and
measured the conditional view. Preserve the result as
**descriptively coherent quasi-external conditioning with no multiplicity
survivor**. Do not select the LOW near-pass, change thresholds, or open a
strategy surface from this packet.

## Artifacts

- Complete packet:
  `runs/research_workbench/operator_hypothesis_lab/tsla_qqq_atrp_conditioned_return_horizon_grid_20260825/`.
- Three-authority summary:
  `own_spy_qqq_atrp_map_summary.csv` in the packet.
- QQQ-versus-own alignment:
  `own_vs_external_atrp_cell_comparison.csv` and
  `own_vs_external_atrp_map_summary.csv`.
- Price/state chart:
  `visuals/tsla_qqq_atrp_state_price_bands.png`.
- Reproduction scripts:
  `scripts/inspect/run_tsla_qqq_atrp_conditioned_return_horizon_grid.R` and
  `scripts/inspect/run_tsla_atrp_conditioned_return_horizon_grid.R`.
- Running evidence deck:
  `operator_hypothesis_lab/presentations/tsla_descriptive_microscope_evidence.pptx`.
