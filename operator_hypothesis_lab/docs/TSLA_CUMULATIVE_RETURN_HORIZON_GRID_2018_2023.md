# TSLA Cumulative Prior-Versus-Forward Return Horizon Grid

## Question

Could adjacent daily returns be too noisy to reveal a signed continuation or
reversal relationship that becomes more visible after aggregating several
prior or following sessions?

This is a wider descriptive scan, not a strategy search. It extends the fixed
TSLA `t-1` versus `t` study to a predeclared grid and keeps the same
2018-2023 evidence boundary.

## Fixed Grid

- Asset: `TSLA`.
- Source: canonical Alpaca SIP adjusted daily bars.
- Prior horizons: `1, 2, 3, 4, 5, 10, 15, 20, 25` sessions.
- Forward horizons: `1, 2, 3, 4, 5, 10, 15, 20, 25` sessions.
- Cells: `81`.
- Observations per cell: `1,485` to `1,509`.
- First forward session: no earlier than `2018-01-02`.
- Last forward endpoint: no later than `2023-12-29`.
- Post-2023 data: not read.
- Trading or performance calculation: none.

For an anchor close `C[t]`, the two quantities are:

```text
prior(p)   = log(C[t] / C[t-p])
forward(f) = log(C[t+f] / C[t])
```

The prior window ends at the anchor close. The forward return begins from that
same close, so no return interval appears on both sides of the comparison.

## Statistics

Pearson correlation is the primary comparable measure across cells. Each cell
also records Spearman correlation, OLS slope and R-squared, the probability of
a positive forward return after positive versus non-positive prior return, and
the same-sign rate.

Because cumulative windows overlap across neighboring anchor dates,
Newey-West/HAC uncertainty uses at least `p + f - 1` lags. Signed-return slope
p-values are adjusted across all 81 cells with both Benjamini-Hochberg FDR and
Bonferroni. The direction-difference family receives its own corresponding
multiplicity columns.

## Pearson Surface

| Prior / Forward | 1 | 2 | 3 | 4 | 5 | 10 | 15 | 20 | 25 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | -0.021 | +0.013 | +0.027 | +0.033 | +0.015 | +0.044 | +0.042 | +0.017 | +0.017 |
| 2 | +0.013 | +0.044 | +0.055 | +0.043 | +0.026 | +0.065 | +0.060 | +0.026 | +0.024 |
| 3 | +0.027 | +0.055 | +0.050 | +0.038 | +0.037 | +0.077 | +0.059 | +0.024 | +0.023 |
| 4 | +0.032 | +0.042 | +0.038 | +0.040 | +0.039 | +0.088 | +0.061 | +0.018 | +0.018 |
| 5 | +0.014 | +0.026 | +0.037 | +0.039 | +0.045 | **+0.092** | +0.056 | +0.015 | +0.014 |
| 10 | +0.043 | +0.064 | +0.076 | +0.087 | **+0.092** | +0.091 | +0.034 | +0.006 | -0.005 |
| 15 | +0.041 | +0.058 | +0.058 | +0.060 | +0.055 | +0.034 | -0.003 | -0.030 | -0.037 |
| 20 | +0.016 | +0.026 | +0.024 | +0.018 | +0.015 | +0.007 | -0.029 | -0.050 | -0.059 |
| 25 | +0.017 | +0.023 | +0.023 | +0.018 | +0.014 | -0.004 | -0.037 | -0.059 | -0.070 |

Aggregation does reveal a coherent positive region centered roughly on five to
ten prior or following sessions. It is not merely one isolated maximum. The
largest value is `+0.0923` at five prior versus ten forward sessions; the
reverse ten-prior/five-forward cell is `+0.0915`, and ten versus ten is
`+0.0907`.

## Evidence Strength

The ridge remains weak and statistically unresolved:

- Five prior / ten forward Pearson: `+0.0923`.
- Overlap-aware 95% HAC interval: `[-0.0030, +0.1876]`.
- Raw HAC p-value: `0.0576`.
- BH-FDR q-value: `0.6603`.
- R-squared: `0.852%`.
- Signed-return BH-FDR passes: `0 / 81`.
- Signed-return Bonferroni passes: `0 / 81`.

All signed-return overlap-aware intervals include zero. The negative region at
the longest paired horizons is also unresolved: the 25/25 Pearson estimate is
`-0.0701` with a wide HAC interval of `[-0.3185, +0.1782]`.

## Direction View

Several cells show positive differences in the probability of a forward gain
after a positive versus non-positive prior cumulative return. The smallest raw
p-value occurs at ten prior versus three forward sessions:

- Direction difference: `+8.1` percentage points.
- 95% HAC interval: `[+1.0, +15.1]` percentage points.
- Raw HAC p-value: `0.0249`.
- BH-FDR q-value: `0.5542`.
- Direction BH-FDR passes: `0 / 81`.

The raw direction result is therefore a useful example of why the full scan
must remain visible. It does not survive the declared multiplicity treatment.

## Readout

The wider view changes the visual intuition but not the evidence status.
Multi-session aggregation exposes a weak, coherent continuation ridge near the
five-to-ten-session region. It explains less than one percent of forward-return
variance at its maximum, every signed-return interval includes zero, and no
signed or direction cell survives the 81-cell scan.

This ridge is reasonable to bookmark as one candidate for a separately frozen
replication. It is not a discovered edge, a selected model, or authority to
trade. If pursued, the next slice should name one representative comparison in
advance rather than refine this grid until a preferred cell appears.

## Artifacts

- Complete cell table:
  `runs/research_workbench/operator_hypothesis_lab/tsla_cumulative_return_horizon_grid_20260825/horizon_grid_statistics.csv`
- Pearson, Spearman, slope, HAC p-value, BH q-value, R-squared, direction, and
  sample-size matrix CSVs in the same packet.
- Descriptive ranking:
  `cells_ranked_by_absolute_correlation.csv`.
- Overview heatmaps: `visuals/` in the same packet.
- Reproduction script:
  `scripts/inspect/run_tsla_cumulative_return_horizon_grid.R`.
- Running evidence deck:
  `operator_hypothesis_lab/presentations/tsla_descriptive_microscope_evidence.pptx`.
