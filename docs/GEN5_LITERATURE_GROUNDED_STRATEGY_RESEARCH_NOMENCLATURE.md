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
| `LIT-MR-03.1` | Johansen Triplet Bollinger Reversion | none | `STOP_LIT_MR_03_1_NO_TRAIN_NOMINATION` |

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

Retrospective or source-reproduction views use instance suffixes rather than
decimal variants because the trading mechanics do not change:

| Instance | Purpose | Status |
|---|---|---|
| `LIT-MR-02.1 / CASESTUDY_2018` | Ex-post pedagogical view of a positive calendar year inside opened canonical TRAIN | `POSITIVE_CONTROL_ONLY` |
| `LIT-MR-02.1 / SOURCE_REPRO_2006_2012` | Chan Example 3.2 source-period reproduction using quarantined Yahoo reference bars | `POSITIVE_CONTROL_ONLY` |
