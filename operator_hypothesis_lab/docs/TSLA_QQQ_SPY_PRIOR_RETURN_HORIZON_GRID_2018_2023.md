# QQQ/SPY Prior Return Versus Following TSLA Return

## Question

Does cumulative QQQ or SPY return over one or more completed prior sessions
relate to TSLA cumulative return over one or more following sessions?

This slice returns to the basic prior-versus-forward return microscope without
a state filter. It substitutes a quasi-external market return for TSLA's own
prior return, while preserving the target, sample, horizons, timing, and
uncertainty machinery.

## Frozen Design

- target return asset: TSLA;
- prior-return authorities: QQQ and SPY, tested as separate univariate
  predictors;
- data: Alpaca SIP adjusted daily bars on the common QQQ/SPY/TSLA session
  calendar;
- analysis window: 2018-01-02 through 2023-12-29;
- prior and following horizons: `1, 2, 3, 4, 5, 10, 15, 20, 25` sessions;
- timing: the QQQ or SPY prior window ends at anchor close `t`; the TSLA
  following window begins after `t`;
- primary measure: Pearson correlation / OLS slope;
- uncertainty: Newey-West/HAC with lag at least `p + f - 1`;
- multiplicity: BH-FDR within each 81-cell predictor family and across the
  pooled 162 signed-return cells;
- comparison: QQQ-minus-SPY cell differences are descriptive only; and
- no post-2023 confirmation, relative-strength model, trading rule, or
  performance calculation.

All three symbols supplied 1,572 adjusted daily bars from 2017-10-02 through
2023-12-29. The 162 cells contain 1,485 to 1,509 complete observations, and all
source, timing, sample, and finite-statistic checks passed.

## QQQ Readout

The QQQ surface is positive in `72/81` cells and has mean correlation `+0.0459`.
Its strongest cell is 10 prior / 10 forward sessions:

- Pearson correlation: `+0.1337`;
- HAC 95% interval: `[+0.0098, +0.2575]`;
- raw HAC p-value: `0.0344`;
- within-QQQ BH q-value: `0.3612`;
- pooled 162-cell BH q-value: `0.5383`; and
- OLS R-squared: `1.79%`.

Seven QQQ cells have unadjusted HAC intervals that exclude zero, but none
survives the 81-cell QQQ family correction. The visual surface forms a broad
positive island around roughly 5-15 prior sessions and 4-15 following TSLA
sessions, then weakens or turns negative in the longest prior/forward corner.

## SPY Readout

The SPY surface is positive in `70/81` cells and has mean correlation `+0.0345`.
Its strongest cell is 10 prior / 5 forward sessions:

- Pearson correlation: `+0.1108`;
- HAC 95% interval: `[-0.0211, +0.2426]`;
- raw HAC p-value: `0.0996`;
- within-SPY BH q-value: `0.6620`;
- pooled 162-cell BH q-value: `0.5383`; and
- OLS R-squared: `1.23%`.

Four SPY cells have unadjusted HAC intervals that exclude zero, but none
survives the SPY family correction. SPY traces nearly the same positive island
as QQQ, with a somewhat weaker long-horizon surface.

## QQQ, SPY, and TSLA-Own Comparison

QQQ and SPY agree in sign on `79/81` cells and their correlation maps have
cellwise correlation `+0.9469`. The largest descriptive QQQ-minus-SPY
difference is only `+0.0354`, at 15 prior / 10 forward sessions.

The same geometry is also present in the frozen TSLA-own prior-return map:

| Prior-return authority | Mean r | Positive cells | Strongest cell | Map correlation vs TSLA-own | Sign agreement vs TSLA-own |
|---|---:|---:|---|---:|---:|
| TSLA-own | +0.0280 | 69/81 | +0.0923 at 5/10 | +1.000 | 81/81 |
| QQQ | +0.0459 | 72/81 | +0.1337 at 10/10 | +0.906 | 78/81 |
| SPY | +0.0345 | 70/81 | +0.1108 at 10/5 | +0.965 | 80/81 |

QQQ is somewhat stronger in point estimate, but this is not evidence that it
adds distinct predictive information. The close agreement among all three maps
is more consistent with common market/TSLA trend geometry than with a unique
QQQ or SPY lead in this aggregate sample.

## Multiplicity and Stop

- signed-return family BH passes: QQQ `0/81`, SPY `0/81`;
- signed-return pooled BH passes: `0/162`;
- direction family BH passes: QQQ `0/81`, SPY `0/81`; and
- direction pooled BH passes: `0/162`.

The result is a coherent descriptive clue, not a confirmed lead-lag effect.
QQQ, SPY, and TSLA share market shocks and trend episodes; the horizon cells
overlap and nest; and this one historical sample both reveals and measures the
surface. Preserve the positive medium-horizon island, but do not select a cell,
claim independent information, or open a strategy gate from this packet.

## Artifacts

- Complete packet:
  `runs/research_workbench/operator_hypothesis_lab/tsla_qqq_spy_prior_return_horizon_grid_20260825/`.
- Complete 162-cell table: `cross_asset_horizon_grid_statistics.csv`.
- QQQ-versus-SPY comparison: `qqq_vs_spy_cell_comparison.csv`.
- Own/external baseline comparison: `tsla_own_qqq_spy_cell_comparison.csv` and
  `tsla_own_qqq_spy_map_summary.csv`.
- Visuals: QQQ, SPY, QQQ-minus-SPY, and a shared-scale TSLA-own/QQQ/SPY
  Pearson heatmap comparison in `visuals/`.
- Reproduction script:
  `scripts/inspect/run_tsla_qqq_spy_prior_return_horizon_grid.R`.
- Running evidence deck:
  `operator_hypothesis_lab/presentations/tsla_descriptive_microscope_evidence.pptx`.
