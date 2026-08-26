# TSLA Return Grid Conditioned on SPY ATR%

## Question

Can an external, broad-market volatility state organize the relationship
between TSLA's prior and following cumulative signed log returns?

This slice changes one authority only. TSLA remains the return asset, the
2018-2023 sample remains fixed, and the same 9 x 9 prior/forward horizon grid is
used. The LOW, MEDIUM, and HIGH labels now come from SPY's already accepted
HYP-REG-01.1 ATR-percent classifier instead of TSLA's own ATR-percent history.

## Fixed External State

- state asset: SPY;
- metric: Wilder ATR14 divided by SPY adjusted close;
- percentile: current SPY ATR% ranked against the preceding 252 completed SPY
  ATR% observations, excluding the current session;
- LOW entry below the 30th percentile and exit above the 40th;
- HIGH entry above the 70th percentile and exit below the 60th;
- otherwise MEDIUM, with direct LOW-to-HIGH and HIGH-to-LOW jumps allowed; and
- SPY state at anchor close `t` is known before TSLA's following return begins
  at `t+1`.

The 1,509-session state ledger contains LOW `568`, MEDIUM `430`, and HIGH `511`
SPY sessions. All SPY state dates align exactly with the TSLA return dates, and
the TSLA closes exactly match the previously accepted TSLA ledger.

## Visual Readout

The external state changes the shape of the TSLA return map:

- SPY LOW ATR%: 72 of 81 cells are positive. The strongest cell is `+0.2279`
  at 5 prior / 10 forward sessions.
- SPY MEDIUM ATR%: 67 of 81 cells are negative. The strongest absolute cell is
  `-0.1912` at 15 prior / 20 forward sessions.
- SPY HIGH ATR%: 60 of 81 cells are positive, but the surface is mild and mixed.
  The strongest absolute cell is `-0.1029` at 25 prior / 15 forward sessions.

No within-state cell passes BH-FDR. The largest direct contrast is SPY
MEDIUM-minus-LOW at 5 prior / 15 forward sessions: LOW is `+0.2129`, MEDIUM is
`-0.1764`, and the correlation difference is `-0.3892`. Three neighboring
MEDIUM-minus-LOW interactions pass their 81-cell family correction, but none
survives the stricter omnibus BH correction across all 486 within-state and
pairwise tests.

## Comparison With TSLA's Own ATR% Conditioning

This is not simply the earlier own-asset map rediscovered through SPY:

| State label | Own-map mean r | External-map mean r | Cellwise map correlation | Sign agreement |
|---|---:|---:|---:|---:|
| LOW | +0.1177 | +0.0905 | +0.665 | 72/81 |
| MEDIUM | +0.1609 | -0.0579 | +0.108 | 14/81 |
| HIGH | -0.0831 | +0.0306 | +0.800 | 25/81 |

LOW-state geometry is relatively similar. MEDIUM changes sign almost
completely. HIGH retains a related cell ordering but shifts upward enough that
most signs reverse. State names therefore are not portable meanings: "HIGH"
describes high movement capacity in the asset that owns the classifier, not a
universal market regime with one fixed TSLA implication.

## Interpretation

The external-cue idea is promising as a descriptive research direction because
SPY's state partitions the TSLA map coherently while avoiding direct reuse of
TSLA's own ATR% in the state label. The strongest contrast is LOW continuation
versus MEDIUM long-forward reversal, not the own-asset MEDIUM-continuation versus
HIGH-reversal pattern.

This does not establish causal market transmission or a tradable edge. SPY and
TSLA share calendar time and market shocks, the horizon cells overlap and nest,
and the same historical sample motivated and evaluated the conditioned view.
The correct status is **descriptively coherent external conditioning, with no
omnibus multiplicity survivor and no strategy authority**.

## Artifacts

- Complete state and pairwise tables, matrices, checks, and report:
  `runs/research_workbench/operator_hypothesis_lab/tsla_spy_atrp_conditioned_return_horizon_grid_20260825/`.
- External-versus-own map alignment:
  `own_vs_external_atrp_cell_comparison.csv` and
  `own_vs_external_atrp_map_summary.csv` in the same packet.
- Price/state chart:
  `visuals/tsla_spy_atrp_state_price_bands.png`.
- LOW, MEDIUM, HIGH, and direct-difference heatmaps: the other files in the
  packet's `visuals/` directory.
- Reproduction scripts:
  `scripts/inspect/run_tsla_spy_atrp_conditioned_return_horizon_grid.R` and
  `scripts/inspect/run_tsla_atrp_conditioned_return_horizon_grid.R`.
- Running evidence deck:
  `operator_hypothesis_lab/presentations/tsla_descriptive_microscope_evidence.pptx`.
