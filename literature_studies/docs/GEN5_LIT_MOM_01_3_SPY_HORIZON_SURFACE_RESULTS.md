# LIT-MOM-01.3 SPY Horizon-Surface Predictor Results

Status: `STOP_LIT_MOM_01_3_SANDBOX_NO_SEARCH_ADJUSTED_PREDICTIVE_SURFACE`

## Bottom line

The frozen 2017-2023 sandbox did not contain a search-adjusted positive SPY
own-return predictor on the predeclared 28-cell surface. The highest observed
cell correlation was `0.016240`, far below the `0.177058` 90th-percentile
maximum from the complete admissible joint circular-shift control. Its
empirical upper-tail probability was `0.905912`.

The global gate therefore failed. No horizon was nominated, the 2024-2025
confirmation zone remains unread, and no trading policy or performance
surface was opened.

## Frozen execution

- Instrument: `SPY` adjusted daily Alpaca bars.
- Explicit as-of timestamp:
  `2026-08-21 17:30:00 America/New_York`.
- Requested data: `2016-01-04` through `2023-12-29` only.
- Sandbox anchors: no earlier than `2017-01-03`, with every target exit open
  on or before `2023-12-29`.
- Common anchors: `1,699`; every cell uses the same 250-session lookback and
  60-session future-availability boundary.
- Frozen grid: seven lookbacks `{1,5,10,25,60,120,250}` crossed with four
  targets `{5,10,25,60}`.
- Search control: all `1,200` admissible joint circular shifts with shortest
  circular displacement at least 250 sessions.
- Cell uncertainty: `10,000` seeded stationary-block bootstrap draws with
  expected block length 60.

All five requested-range coverage checks and all eight bar-integrity checks
passed. The workbench emitted a `stale_symbol` warning only because the local
cache ended before the August 2026 latest-completed session. The frozen query
ended in 2023, its requested range was explicitly `fully_cached`, and the
warning does not affect this sandbox window.

## Surface readout

Only four of the 28 correlations were positive, and none exceeded `0.016240`:

| Cell | Correlation | Beta |
|---|---:|---:|
| `L10_H5` | `0.016240` | `0.011343` |
| `L5_H10` | `0.015183` | `0.021231` |
| `L1_H10` | `0.004831` | `0.014116` |
| `L10_H10` | `0.002921` | `0.002911` |

The observed maximum sat at only the `9.42` percentile of the shifted-surface
maxima. This is not a near miss: the largest attractive-looking cell was
smaller than the global p90 threshold by about `0.161` correlation points.

The canonical Chan reference cell `L250_H25` pointed in the opposite direction:

- correlation: `-0.118644`;
- beta: `-0.049730`; and
- stationary-bootstrap 90% beta interval: `[-0.161571, 0.016122]`.

Its predictor-quintile conditional target means declined from `2.32%` in Q1
to `0.03%` in Q5. This is reversal-shaped sandbox evidence for SPY at the
canonical horizons, not authority to open a reversal strategy.

## Decision

Record
`STOP_LIT_MOM_01_3_SANDBOX_NO_SEARCH_ADJUSTED_PREDICTIVE_SURFACE`.

Do not:

- select the least-negative or nominally best cell;
- inspect 2024-2025 confirmation;
- change the horizon grid, global percentile, displacement exclusion,
  estimator, asset, or direction after seeing the surface;
- reinterpret the negative canonical cell as a mean-reversion nomination; or
- construct positions, exits, costs, P&L, Sharpe, drawdown, allocation, or
  live behavior from this sandbox.

This result is a narrow null for the frozen SPY predictor surface. It does not
erase time-series momentum in other instruments, frequencies, mechanisms, or
contracts, and it does not revise the separate `LIT-MOM-01.1` or `01.2` stops.

## Evidence packet

The ignored operator packet is at:

`runs/research_workbench/literature_grounded/lit_mom_01_3_spy_horizon_surface_20260821`

Key files:

- `mom013_report.md`;
- `mom013_surface_summary.csv`;
- `mom013_surface_decision.csv`;
- `mom013_circular_shift_maxima.csv`;
- `mom013_canonical_250_25.csv`;
- `visuals/mom013_surface_heatmaps.png`;
- `visuals/mom013_search_adjusted_control.png`; and
- `visuals/mom013_canonical_250_25.png`.

The reusable implementation is in
`literature_studies/R/gen5_lit_mom_01_3_spy_horizon_surface.R`, with runner
`literature_studies/scripts/run_gen5_lit_mom_01_3_spy_horizon_surface.R` and
focused tests in
`literature_studies/tests/testthat/test_gen5_lit_mom_01_3_spy_horizon_surface.R`.
