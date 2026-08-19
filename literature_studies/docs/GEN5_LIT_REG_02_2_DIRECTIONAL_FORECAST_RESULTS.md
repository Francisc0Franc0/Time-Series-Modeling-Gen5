# LIT-REG-02.2 Directional HMM Forecast-Skill Results

Status: `COMPLETE_LIT_REG_02_2_SYNTHETIC_FORECAST_FRONTIER_MAPPED_MARKET_NOT_OPENED`

Date executed: 2026-08-19

## Bottom Line

The forecast-first reformulation replicated the useful part of `02.1` under
fresh evidence. All 24 new confirmation cases produced valid H2 and B2 fits,
all eight frozen gates passed, and the Markov-switching H2 probability beat
the constant, one-state AR(1), and fixed-ridge challengers on mean Brier score
and log loss with negative one-sided 90% paired upper confidence bounds.

That success did not translate into a broad, smooth detection frontier. Only
2 of 16 signal/persistence/history cells met the frozen cell definition, the
pattern was non-monotonic, and the financial-shaped Student-t/GARCH stress
lost mean advantage versus B0 and B1. The honest conclusion is therefore
narrow: the latent-state probability mechanism can add forecast information
in clear planted conditions, but this specification is not yet robust enough
to justify market or strategy contact.

## Evidence Boundary

- `market_data_read=FALSE`
- `semi_synthetic_market_data_read=FALSE`
- `strategy_data_read=FALSE`
- `confirmation_data_read=FALSE`
- No Alpaca query, market return, residual, 2024+ observation, strategy, PnL,
  Sharpe, drawdown, threshold, entry, exit, allocation, leverage, or live
  behavior entered the run.

## Stage A — Fresh Confirmation

All 24 fresh cases used seeds `75001:75024`, outside every `02.1` seed.

| Gate | Status | Evidence |
|---:|---|---|
| `A1` | `PASS` | H2 and B2 valid in `24/24`; `hmmTMB 1.1.2`. |
| `A2` | `PASS` | Append difference `0`. |
| `A3` | `PASS` | Parameter, filter, probability, and score replay difference `0`. |
| `A4` | `PASS` | H2 Brier `0.2422`; B0 `0.2578`, B1 `0.2570`, B2 `0.2495`; wins `17`, `18`, and `16` of 24; every one-sided 90% upper bound below zero. |
| `A5` | `PASS` | H2 log loss `0.6771`; B0 `0.7092`, B1 `0.7076`, B2 `0.6951`; wins `17`, `18`, and `16` of 24; every one-sided 90% upper bound below zero. |
| `A6` | `PASS` | Pooled calibration intercept `0.098`, slope `0.725`, sharpness `0.133`. |
| `A7` | `PASS` | Oracle Brier `0.2036` versus H2 `0.2422`; all scores finite. |
| `A8` | `PASS` | Seed integrity and B2 TRAIN/OOS causal-origin audits passed. |

The calibration slope below one indicates that H2 was somewhat too extreme,
while the small positive intercept indicates modest aggregate
underprediction of the positive event. Both remained inside the frozen
teaching bounds. These are not reasons to retune the inspected model.

Hard-state accuracy remained diagnostic rather than authoritative: median
`71.8%`, tenth percentile `58.5%`. Median maximum transition error was
`0.0160`, with ninetieth percentile `0.0550`. This again demonstrates why a
soft forecast can be useful without producing a clean daily state color.

## Stage B — Forecast Frontier

H2 and B2 were jointly valid in `63/64` cases. Two of 16 cells met the frozen
formal definition:

| TRAIN | Self-transition | Drift | Joint wins | Mean Brier gain vs per-case best baseline |
|---:|---:|---:|---:|---:|
| `1,000` | `0.90` | `5 bp/day` | `3/4` | `-0.00093` |
| `1,000` | `0.97` | `30 bp/day` | `3/4` | `+0.00025` |

There were zero formal detections in the four null cells. That is useful
specificity evidence.

The `5 bp` cell deserves caution. Its H2 mean beat each named baseline and
three replicates jointly beat all three, satisfying the frozen definition,
but one loss was large enough that H2 trailed an ex-post per-case
best-of-three composite on average. That composite is not deployable—it picks
the best baseline after seeing each case—but the negative gain reveals weak
cell stability.

More generally, stronger drift, greater persistence, or more TRAIN history
did not produce a monotonic improvement. With only four replicates per cell,
the frontier is a sparse characterization, not a smooth power law. Do not
select the two passing cells as production parameters.

## Stage C — Financial-Shaped Stress

All ten H2 and B2 fits were valid under standardized Student-t(6) GARCH noise.

| Metric | H2 | B0 | B1 | B2 |
|---|---:|---:|---:|---:|
| Mean Brier | `0.2532` | `0.2517` | `0.2519` | `0.2616` |
| Mean log loss | `0.6998` | `0.6965` | `0.6971` | `0.7218` |

H2 beat B0 in `6/10`, B1 in `4/10`, and B2 in `8/10` cases on each score.
Its average advantage over the simplest baselines disappeared under the
deliberate Gaussian-model misspecification. This is a robustness warning, not
a market result.

## Interpretation

`02.2` establishes three different facts:

1. the `02.1` proper-score clue replicated on fresh planted data and survived
   a stronger direct challenger;
2. the advantage was not a general consequence of fitting any two-state
   model, because null cells had no formal detections; and
3. forecast skill was fragile across the broader power grid and
   financial-shaped noise.

This is more informative than either “HMM failed” or “HMM found alpha.” It
identifies a legitimate synthetic niche and a serious robustness boundary.

## Reporter-Only Rerun

The first execution completed Stage A and every Stage B fit, then stopped
while row-binding forecasts because one B2-invalid case lacked fixed B2
columns. No frontier score table was inspected. The reporter was changed to
emit a stable schema and fill unavailable fields with `NA`; no scientific
input or output calculation changed. The complete rerun is authoritative.

## Next Decision

The COMPLETE verdict opens discussion only. Given the sparse and
non-monotonic frontier plus stress degradation, the recommended next step is
not immediate market testing. A separately frozen exercise could either:

- increase predeclared replication density to learn whether the apparent
  frontier is sampling noise; or
- use a real-residual semi-synthetic bridge to test forecast skill under
  realistic residual structure while retaining planted directional truth.

Neither path is authorized by this result.

## Evidence Packet

Authoritative ignored packet:
`runs/research_workbench/literature_studies/lit_reg_02_2_directional_forecast_frontier_20260819`

Key files include `stage_a_gates.csv`, `stage_a_skill_details.csv`,
`stage_a_calibration.csv`, `stage_b_frontier_summary.csv`,
`stage_c_case_summary.csv`, the representative probability tape, all charts,
`reporter_rerun_note.txt`, and `verdict.txt`.
