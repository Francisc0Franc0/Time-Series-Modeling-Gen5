# LIT-IMOM-01.2 30-Minute Path-Quality Forecast Comparison Results

Status: `STOP_LIT_IMOM_01_2_NO_CLOCK_CONTROLLED_PATH_QUALITY_FORECAST`

## Decision

Stop this 30-minute bar-domain transport at DEVELOPMENT. Higher time
resolution did not reveal the forecast relationship that was absent from the
daily study. Constant drift remained the lowest-loss authority for most
instruments, raw trailing return supplied no multiplicity-controlled clue,
and adding positive-path coherence and shock concentration increased loss
again.

Do not inspect 2024+ confirmation, select a favorable bar slot or horizon, or
construct a trading rule from the isolated favorable rows.

## Frozen comparison

The test deliberately preserved the same numeric surface as the daily engine
without multiplying horizons by thirteen:

- lookbacks: `5, 10, 25, 60, 120, 250` bars;
- future targets: `5, 10, 25, 60` bars; and
- all 24 cells equally weighted, with no selection or reweighting.

Each instrument/cell fit two parallel TRAIN-only chains on 2018-2020 and
scored unchanged forecasts on 2021-2023:

| Exact chain | Clock-aware chain | Incremental information |
|---|---|---|
| `B0_DRIFT` | `C0_CLOCK` | intercept versus TRAIN-fitted signal-bar slot |
| `B1_RAW` | `C1_CLOCK_RAW` | trailing log return |
| `Q2_PATH` | `C2_CLOCK_PATH` | raw return plus positive-path coherence and shock concentration |

The clock-aware chain is a falsification control for ordinary opening,
midday, and closing seasonality. Scaled losses were equal-averaged across 24
cells at each anchor and then within each session. Inference used 10,000-draw
stationary bootstraps of ordered session means with expected 20-session
blocks. BH `q=0.10` was applied separately by contrast across the 22 candidate
stocks.

## Data and analytical validity

- Frozen registry checksum:
  `ED6A9C87E00E53970528F9638BFB972323D47AF86B273C19A13DC89DE9D7B4AF`.
- All 26 instruments passed mechanical and analytical eligibility.
- Each instrument supplied 9,654 TRAIN and 9,639 DEVELOPMENT common anchors.
- Complete retained surface: 624/624 instrument/cells, with six full-rank
  models per cell.
- DEVELOPMENT inference covered 744 ordered trading sessions.
- The ten parent-series archive-gap sessions were excluded globally without
  imputation.
- Provider metadata remained Alpaca SIP, adjusted `30Min`, adjustment `all`.
- Maximum included session was `2023-12-29`; confirmation was not loaded.
- AMD, TSLA, SPY, and QQQ were reported as diagnostic-only and excluded from
  candidate FDR families.

## Model loss result

Lower scaled loss is better.

| Authority | Median instrument scaled loss | Lowest-loss instruments |
|---|---:|---:|
| `B0_DRIFT` | 0.77175 | 21/26 |
| `B1_RAW` | 0.77220 | 5/26 |
| `Q2_PATH` | 0.77561 | 0/26 |
| `C0_CLOCK` | 0.77189 | 21/26 |
| `C1_CLOCK_RAW` | 0.77235 | 5/26 |
| `C2_CLOCK_PATH` | 0.77577 | 0/26 |

The exact and clock-aware rankings were identical. TRAIN-fitted clock effects
therefore neither rescued drift/raw prediction nor explained away a hidden
path-quality result. The additional slot coefficients carried a small
estimation cost at the median rather than useful incremental authority.

## Controlled contrast result

Positive values favor the model named second.

| Contrast | Interpretation | Positive candidate stocks | Positive 90% lower bounds | Median differential | Minimum raw p | Minimum BH q |
|---|---|---:|---:|---:|---:|---:|
| `D10` | raw beats drift | 4/22 | 2 | -0.00147 | 0.024298 | 0.318968 |
| `D21` | path beats raw | 1/22 | 0 | -0.00372 | 0.461354 | 0.998000 |
| `D20` | path beats drift | 0/22 | 0 | -0.00497 | 0.645435 | 0.999200 |
| `K10` | clock-raw beats clock | 4/22 | 2 | -0.00147 | 0.022898 | 0.331067 |
| `K21` | clock-path beats clock-raw | 1/22 | 0 | -0.00374 | 0.459654 | 0.998100 |
| `K20` | clock-path beats clock | 0/22 | 0 | -0.00495 | 0.631737 | 0.999500 |

No exact or clock-controlled raw clue and no path-quality candidate survived
the complete frozen gate.

## Near-misses remain diagnostic only

- `TXN` had the strongest clock-controlled raw-over-clock row:
  `K10=0.003058`, 90% interval `[0.000323, 0.005632]`, raw p `0.022898`,
  and BH q `0.331067`.
- `GOOGL` also had a positive raw interval:
  `K10=0.001983`, 90% interval `[0.000231, 0.003730]`, raw p `0.030097`,
  and BH q `0.331067`.
- `CAT` was the only candidate stock with positive clock-path-over-clock-raw
  point loss: `K21=0.000494`, but its interval
  `[-0.004059, 0.004177]`, raw p `0.459654`, and BH q `0.998100` were null.
  It also remained worse than the clock baseline (`K20=-0.001013`).

These rows cannot select an asset, horizon, slot, or later confirmation test.

## Path and clock diagnostics

Only 4/26 instruments had the expected median clock-aware coefficient
directions: coherent-positive `Q > 0` and shock-positive `S < 0`. The
remembered AMD and TSLA cases, as well as SPY and QQQ, had the opposite median
direction and negative path-loss contrasts.

The null was not localized to a particular clock segment:

- median `K21` and `K20` were negative in every one of the 24 L/H cells;
- median `K21` was negative for every predeclared signal-slot/session-crossing
  group; and
- targets that crossed a session boundary generally deteriorated more than
  targets contained within a session.

The richest path model never had the lowest instrument-average loss in either
the exact or clock-aware chain.

## What this changes

The daily null could not, by itself, rule out an intraday manifestation. This
test now closes that specific uncertainty for the approved 30-minute panel
and direct numeric bar-domain formulation. The higher-resolution series
contained more path detail, but those details did not supply stable
incremental future-return information.

This does not prove that all intraday predictors fail. It rejects this exact
unpenalized asymmetric path representation over this liquid 24-stock panel,
including horizons from roughly 2.5 trading hours through 19 sessions. A
future sibling would need genuinely new, pre-outcome motivation—such as
cross-sectional relative returns, market microstructure, or a different
state representation—rather than another clock or horizon rescaling of the
same path variables.

## Evidence packet

- Packet:
  `runs/research_workbench/literature_grounded/lit_imom_01_2_30min_path_quality_forecast_comparison_20260821`
- Report: `imom012_report.md`
- Health and coverage: `imom012_data_health.csv` and
  `imom012_coverage_and_eligibility.csv`
- Cell and session evidence: `imom012_development_cell_metrics.csv` and
  `imom012_development_session_losses.csv`
- Controlled inference: `imom012_development_contrasts.csv`
- Decisions: `imom012_asset_decisions.csv`
- Visual evidence: `visuals/`

No thresholds, positions, trades, costs, turnover, P&L, Sharpe, drawdown,
allocation, leverage, advice, or live behavior were computed. The 2024+
period remains unread.
