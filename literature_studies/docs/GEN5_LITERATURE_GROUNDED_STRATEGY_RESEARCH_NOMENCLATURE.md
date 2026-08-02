# Literature-Grounded Strategy Research Nomenclature

Status: `FROZEN`

## Umbrella

The literature-led research avenue is named **Literature-Grounded Strategy
Research** and uses the stable tag `LIT`.

`LIT` distinguishes mechanisms sourced primarily from the operator-supplied
literature from the earlier organically developed Gen5 conversations. It does
not weaken the Gen5 leakage, falsification, evidence, or operator-control
requirements.

## Identifier

Every test uses:

`LIT-[FAMILY]-[CONCEPT].[VARIANT]`

- `FAMILY` identifies the economic mechanism, such as `MR` for mean reversion
  or `MOM` for momentum.
- `CONCEPT` increments when the underlying trading proposition changes.
- `VARIANT` increments only for a substantive, theoretically justified change
  to the same proposition.

Status remains separate from the identifier:

`LIT-MR-01.1 | STOP | TRAIN structural gate`

## Version discipline

A decimal increment is not permission to reactively tune a failed result.
`01.2` must have:

- a substantive mechanical change;
- an ex ante theoretical or externally sourced rationale;
- a newly frozen contract;
- an explicit change log from `01.1`; and
- fresh evidence where practical.

A different signal, economic relationship, or source proposition receives a
new concept number, for example `LIT-MR-02.1`.

Prior variants are immutable evidence. A later variant never replaces or
renames an earlier outcome.

## Current registry

| Identifier | Descriptive name | Legacy alias | Status |
|---|---|---|---|
| `LIT-MR-01.1` | Five-Session Cross-Sectional Sector Reversal | `L1` | `STOP_L1A_SECTOR_REVERSAL_MECHANISM` |
| `LIT-MR-02.1` | Adaptive GLD-USO Spread Bollinger Reversion | none | `STOP_LIT_MR_02_1_TRAIN_MECHANISM` |
| `LIT-MR-03.1` | Johansen Triplet Bollinger Reversion | none | Core batch STOP; `TRIPLET_ATLAS_01` OOS DEVELOPMENT complete |
| `LIT-MR-02.2` | Graded-Evidence Pair Bollinger Reversion | none | Retrospective OOS descriptive; fresh atlas STOP with no TRAIN pass |
| `LIT-MR-03.2` | Graded-Evidence Johansen Triplet Reversion | none | Retrospective descriptive and fresh OOS complete; no further easing recommended |
| `LIT-MR-04.1` | Kalman Dynamic-Regression Pair | none | `STOP_LIT_MR_04_1_TRAIN_STRATEGY`; 7/8 TRAIN gates, support miss |
| `LIT-MR-05.1` | Kalman Dynamic-Regression Triplet | none | `STOP_LIT_MR_05_1_TRAIN_STRATEGY`; 6/8 TRAIN gates |
| `LIT-MR-06.1` | Causal Buy-on-Gap Intraday Reversion | none | Atlas 01 STOP at 0/10; recent-wide Atlas 02 STOP at 0/12 |
| `LIT-MOM-01.1` | Interday Time-Series Momentum | none | `OOS_DEVELOPMENT_COMPLETE_LIT_MOM_01_1`; STOP recommended before CONFIRMATION |
| `LIT-MOM-01.2` | Long-Only Single-Position Interday Time-Series Momentum | none | `STOP_LIT_MOM_01_2_AUDIT_01_NO_INCREMENTAL_TIMING`; raw retrospective breadth did not survive exposure, random-timing, canonical-horizon, or beta attribution; no confirmation authority |
| `LIT-MOM-02.1` | Causal Opening-Gap Intraday Momentum | none | `STOP_LIT_MOM_02_1_OPENING_GAP_NO_TRAIN_NOMINEE`; 0/8 small POC and 0/92 wide atlas |

## Replication batches and instances

A fixed set of asset substitutions under unchanged mechanics is a replication
batch, not a decimal variant:

`LIT-MR-02.1-PANEL-A / pair_id=P01_IVV_SPY`

- `PANEL-A` names the predeclared batch.
- `pair_id` names one immutable instance.
- The canonical literature example remains `LIT-MR-02.1 / CANON_USO_GLD`.
- A pair substitution does not become `02.2`; changing the transform, window,
  thresholds, exit, or portfolio semantics would require a newly justified and
  frozen variant.

| Batch | Purpose | Status |
|---|---|---|
| `LIT-MR-02.1-PANEL-A` | Twelve positive-beta primary pairs plus two inverse semantic challengers, all fixed before outcomes | `STOP_LIT_MR_02_1_PANEL_A_NO_FULL_PASS` |
| `LIT-MR-02.1-PANEL-B` | Fifteen additional sector, industry, and producer/commodity relationships, all fixed before outcomes | `STOP_LIT_MR_02_1_PANEL_B_NO_FULL_PASS` |
| `LIT-MR-02.1 / RELATIONSHIP_ATLAS_01` | Twenty-five category-balanced pair instances from a frozen topology-by-mechanism generator | `STOP_LIT_MR_02_1_RELATIONSHIP_ATLAS_01_NO_FULL_PASS` |
| `LIT-MR-03.1 / TRIPLET_ATLAS_01` | Twenty-eight category-balanced triplets from a frozen seven-cell economic generator | `OOS_DEVELOPMENT_COMPLETE_LIT_MR_03_1_TRIPLET_ATLAS_01` |
| `LIT-MR-02.2 / RETROSPECTIVE` | Forty-four unique prior pairs under the frozen graded gates | `RETROSPECTIVE_DESCRIPTIVE_COMPLETE_LIT_MR_02_2` |
| `LIT-MR-02.2 / FRESH_ATLAS_01` | Twenty frozen fresh pairs across five categories | `STOP_LIT_MR_02_2_FRESH_ATLAS_01_NO_PASS` |
| `LIT-MR-03.2 / RETROSPECTIVE` | All thirty-six prior triplets under the frozen graded gates | `RETROSPECTIVE_DESCRIPTIVE_COMPLETE_LIT_MR_03_2` |
| `LIT-MR-03.2 / FRESH_ATLAS_01` | Twenty frozen fresh triplets across five categories | `OOS_DEVELOPMENT_COMPLETE_LIT_MR_03_2_FRESH_ATLAS_01` |
| `LIT-MR-06.1 / BUY_ON_GAP_ATLAS_01` | Ten static survivor panels spanning broad US stocks and nine sectors | `STOP_LIT_MR_06_1_ATLAS_NO_FULL_PASS`; DEVELOPMENT not queried |
| `LIT-MR-06.1 / RECENT_WIDE_ATLAS_02` | 305-stock combined panel plus eleven official-sector-derived panels on 2023-2024 TRAIN | `STOP_LIT_MR_06_1_RECENT_WIDE_ATLAS_02_NO_FULL_PASS`; WIDE_US 7/8; DEVELOPMENT not queried |
| `LIT-MOM-01.1 / STOCK_ATLAS_01` | Twenty-two stocks, exactly two from each of eleven sectors, under the unchanged per-stock Chapter 6 horizon screen and sleeve mechanics | `OOS_DEVELOPMENT_COMPLETE_LIT_MOM_01_1_STOCK_ATLAS_01`; HD was the sole TRAIN passer and lost money OOS |
| `LIT-MOM-01.2 / STOCK_ATLAS_01_RETROSPECTIVE` | The same frozen 22-stock panel; every stock searches all 49 TRAIN horizons independently and replays positive signals only with one full-capital fixed-H long position | `RETROSPECTIVE_EXPLORATION_COMPLETE_LIT_MOM_01_2_STOCK_ATLAS_01`; known 2021-2023 window, no winner-selection or confirmation authority |
| `LIT-MOM-01.2 / STOCK_ATLAS_02_2020_BREADTH_ATTENTION` | One hundred additional, non-overlapping stocks frozen as a 75-name sector-diversified core plus 25 names documented in contemporaneous 2020 retail-attention sources | `RETROSPECTIVE_EXPLORATION_COMPLETE_LIT_MOM_01_2_STOCK_ATLAS_02`; 91 coverage-eligible long-only replays, known 2021-2023 window, no selection or confirmation authority |
| `LIT-MOM-01.2 / AUDIT_01_EXPOSURE_AND_SELECTION` | Frozen attribution of 113 stock paths against buy-and-hold, matched exposure, always-long blocks, 1,000 matched random schedules, fixed `250/25`, fixed `60/5`, SPY regression, and supported environment cells | `STOP_LIT_MOM_01_2_AUDIT_01_NO_INCREMENTAL_TIMING`; 2/11 diagnostics passed; environment descriptive only |
| `LIT-MOM-02.1 / OPENING_GAP_ATLAS_01` | Eight-anchor causal POC followed by a 92-instrument, nine-category atlas under unchanged Example 7.1 mechanics | `STOP_LIT_MOM_02_1_OPENING_GAP_NO_TRAIN_NOMINEE`; XLP 7/8; DEVELOPMENT not queried |

Retrospective or source-reproduction views use instance suffixes rather than
decimal variants because the trading mechanics do not change:

| Instance | Purpose | Status |
|---|---|---|
| `LIT-MR-02.1 / CASESTUDY_2018` | Ex-post pedagogical view of a positive calendar year inside opened canonical TRAIN | `POSITIVE_CONTROL_ONLY` |
| `LIT-MR-02.1 / SOURCE_REPRO_2006_2012` | Chan Example 3.2 source-period reproduction using quarantined Yahoo reference bars | `POSITIVE_CONTROL_ONLY` |
| `LIT-MOM-01.1 / CANON_250_25` | Chan Example 6.1's literature-selected 250-session lookback and 25-session holding reference, evaluated beside but never substituted for the frozen SHY selector | `CANONICAL_REFERENCE_ONLY` |
| `LIT-MOM-01.1 / SHY_SELECTED_60_5` | Frozen TRAIN-selected SHY rule under the predeclared 49-cell horizon screen | `OOS_DEVELOPMENT_COMPLETE_STOP_RECOMMENDED` |
| `LIT-MOM-01.2 / SHY_60_5_RETROSPECTIVE` | Same TRAIN-selected SHY signal; positive calls alone enter one fixed-quantity, fully compounded long position held for exactly five open-to-open intervals | `RETROSPECTIVE_EXPLORATION_COMPLETE`; no fresh OOS authority |
| `LIT-MOM-01.1 / STOCK_ATLAS_01 / S11_HD` | Sole six-gate TRAIN passer in the fixed stock breadth panel; frozen 10/10 rule | `OOS_DEVELOPMENT_COMPLETE_STOP_RECOMMENDED` |
| `LIT-MOM-02.1 / SOURCE_FSTX_2004_2012` | Chan's published FSTX Example 7.1 period and headline, without an available continuous-contract reconstruction | `SOURCE_REFERENCE_ONLY` |
