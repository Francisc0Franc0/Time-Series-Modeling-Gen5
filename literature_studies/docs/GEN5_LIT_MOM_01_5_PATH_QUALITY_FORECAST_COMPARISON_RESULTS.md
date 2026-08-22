# LIT-MOM-01.5 Path-Quality Forecast Comparison Results

Status: `STOP_LIT_MOM_01_5_NO_INCREMENTAL_PATH_QUALITY_FORECAST`

## Decision

Stop this path-quality forecast formulation at DEVELOPMENT. Constant TRAIN
drift was the lowest-loss authority for most assets. Raw trailing return
usually failed to improve on drift, and adding positive-move coherence and
shock concentration usually increased loss again. No non-SPY asset survived
the frozen serial-dependence, mechanism, drift, raw-return, and
within-stratum false-discovery gates.

Do not query the sealed 2024-2025 period and do not construct a trading rule
from the isolated favorable rows.

## Frozen comparison

Every eligible asset forecast all 24 nondegenerate cells formed by six
lookbacks (`5, 10, 25, 60, 120, 250`) and four future targets (`5, 10, 25,
60`). No cell was selected or reweighted.

Each asset/cell fit three TRAIN-only authorities on 2017-2020 and scored their
unchanged forecasts on 2021-2023:

- `B0_DRIFT`: constant TRAIN target mean;
- `B1_RAW`: intercept plus trailing log return; and
- `Q2_PATH`: raw return plus positive-return path efficiency and positive-
  return shock concentration.

Cell squared errors were divided by TRAIN target variance and equally
averaged across all 24 cells per DEVELOPMENT anchor. The primary comparison
was `D21 = loss(B1_RAW) - loss(Q2_PATH)`. `D10` compared raw return with
drift, and `D20` compared path quality with drift. Positive values favored the
model named second. Each asset/contrast received a 10,000-draw stationary-
block bootstrap followed by BH `q=0.10` within its frozen stratum.

## Data and analytical validity

- Frozen registry: 92/92 mechanically eligible under SHA-256
  `69C481DCB8443AADC30D8BF10FC7FFB7EC23D193CE88A992E42F8529225E4737`.
- Analysis eligible: 91/92.
- Complete retained surface: 2,184/2,184 cells across eligible assets.
- Authoritative query: `refresh=FALSE`; the requested 2016-2023 cache range
  was complete. The packet `WARN` is staleness relative to August 2026 only.
- SPY remained reference-only and outside candidate FDR families.
- Confirmation and strategy outcomes were not opened.

`SQQQ` was the only analytical exclusion. At `L=250`, only one of its 946
TRAIN anchors had a positive trailing return. Consequently the two
positive-path features were perfectly collinear, the four `L250` fits failed
the frozen full-rank requirement, and all 20 previously completed cells were
discarded. No model was reduced and no replacement asset or cell was used.

## Forecast loss result

Lower scaled loss is better.

| Authority | Median asset scaled loss | Lowest-loss assets |
|---|---:|---:|
| `B0_DRIFT` | 0.95752 | 77/91 |
| `B1_RAW` | 0.98407 | 13/91 |
| `Q2_PATH` | 1.07995 | 1/91 |

Across the 90 non-SPY candidate-producing comparisons:

| Contrast | Interpretation | Positive assets | Minimum raw p | Minimum within-stratum BH q | Controlled clues |
|---|---|---:|---:|---:|---:|
| `D10` | Raw return beats drift | 13/90 | 0.078792 | 1.000000 | 0 |
| `D21` | Path quality beats raw return | 14/90 | 0.010399 | 0.376462 | 0 |
| `D20` | Path quality beats drift | 4/90 | 0.259574 | 0.998100 | 0 |

The median asset differential was negative for every contrast: `-0.04` for
`D10`, `-0.06` for `D21`, and `-0.10` for `D20` after rounding to two decimal
loss units. The hypothesized TRAIN mechanism direction—median coherent-move
coefficient positive and median shock coefficient negative—held for only
11/91 eligible assets.

## Closest favorable rows do not transport

- `XLF` supplied the strongest raw primary `D21` probability. Path quality
  improved over raw return by `0.046041`, with a 90% interval
  `[0.016189, 0.079690]` and raw p `0.010399`, but its plain-ETF BH q was
  `0.696730`. It also remained worse than drift (`D20=-0.040639`) and its
  coefficient directions opposed the mechanism expectation.
- `TMF` had the smallest primary BH q because the engineered stratum was
  small: `D21=0.116272`, raw p `0.075292`, q `0.376462`, and 90% interval
  `[-0.010285, 0.249800]`. It was worse than drift (`D20=-0.023578`).
- `PG` was the only asset for which `Q2_PATH` had the lowest point-estimate
  loss: `1.00535` versus `1.01407` for drift and `1.02748` for raw return.
  Its path-over-drift improvement was only `0.008711`, raw p `0.259574`, and
  BH q `1.000000`.

None qualifies for confirmation or post-hoc horizon inspection.

## What the failure teaches

The richer model failed in two ways.

First, typical assets showed modest deterioration: most DEVELOPMENT points
were below zero on both path-over-raw and path-over-drift loss differences.
Additional path variables therefore did not reveal a broadly stable omitted
trend state.

Second, the unpenalized asymmetric representation created severe tail risk.
For `DBA` and `CORN`, positive `L=250` paths were rare in 2017-2020 TRAIN—42
and 39 anchors respectively—but common in 2021-2023 DEVELOPMENT—563 and 548
anchors. Their DEVELOPMENT coherent-path maxima were roughly 40 times their
TRAIN maxima, while the coherence and shock features were highly correlated
in TRAIN. The fixed OLS coefficients extrapolated catastrophically in several
long-lookback cells. The packet retains these failures rather than clipping,
regularizing, or removing them after observation.

This result does not prove that all trend-state features fail. It rejects this
specific asymmetric, unpenalized, all-horizon linear representation. Any
later sibling would need to motivate its handling of state support,
regularization, nonlinearity, or relative-return structure before outcomes;
it may not tune those choices against this packet and call the result fresh.

## Evidence packet

- Packet:
  `runs/research_workbench/literature_grounded/lit_mom_01_5_path_quality_forecast_comparison_20260821`
- Report: `mom015_report.md`
- Eligibility ledger: `mom015_coverage_and_eligibility.csv`
- Cell forecasts and losses: `mom015_development_cell_metrics.csv`
- Asset/contrast inference: `mom015_development_contrasts.csv`
- Decisions: `mom015_asset_decisions.csv`
- Visual evidence: `visuals/`

No thresholds, positions, trades, costs, P&L, Sharpe, drawdown, allocation,
leverage, advice, or live behavior were computed. The locked 2024-2025 period
remains unread.
