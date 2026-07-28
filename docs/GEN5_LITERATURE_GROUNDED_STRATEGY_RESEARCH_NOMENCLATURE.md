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
