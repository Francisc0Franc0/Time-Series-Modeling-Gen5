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

Retrospective or source-reproduction views use instance suffixes rather than
decimal variants because the trading mechanics do not change:

| Instance | Purpose | Status |
|---|---|---|
| `LIT-MR-02.1 / CASESTUDY_2018` | Ex-post pedagogical view of a positive calendar year inside opened canonical TRAIN | `POSITIVE_CONTROL_ONLY` |
| `LIT-MR-02.1 / SOURCE_REPRO_2006_2012` | Chan Example 3.2 source-period reproduction using quarantined Yahoo reference bars | `POSITIVE_CONTROL_ONLY` |
| `LIT-MOM-01.1 / CANON_250_25` | Chan Example 6.1's literature-selected 250-session lookback and 25-session holding reference, evaluated beside but never substituted for the frozen SHY selector | `CANONICAL_REFERENCE_ONLY` |
| `LIT-MOM-01.1 / SHY_SELECTED_60_5` | Frozen TRAIN-selected SHY rule under the predeclared 49-cell horizon screen | `OOS_DEVELOPMENT_COMPLETE_STOP_RECOMMENDED` |
