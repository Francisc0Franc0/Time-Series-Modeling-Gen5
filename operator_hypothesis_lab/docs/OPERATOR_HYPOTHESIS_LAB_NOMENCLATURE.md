# Operator Hypothesis Lab Nomenclature

Status: `FROZEN`

## Umbrella and identifier

Operator-origin hypotheses use:

`HYP-[FAMILY]-[CONCEPT].[VARIANT]`

- `HYP` distinguishes operator-origin questions from `LIT` literature-derived
  questions and mainline Gen5.x research.
- `FAMILY` identifies the proposed economic behavior, such as `MOM`, `MR`,
  `EVT`, `VOL`, or `TA`.
- `CONCEPT` changes when the trading proposition changes.
- `VARIANT` changes only when a substantive mechanic changes.

Changing a chart color, fixing a bug, or adding a diagnostic does not create a
new variant. Changing the signal definition, entry timing, exit family, or
position semantics normally does.

Evidence stage and status remain separate from the identifier:

`HYP-MOM-01.1 | DISCOVERY_REUSED_WINDOW | COMPLETE`

## Discovery discipline

Discovery may compare a small, explicitly recorded set of reasonable
definitions or exits. It may not report the best inspected cell as fresh alpha.
All inspected variants remain visible, and any rule that advances must receive
a new frozen replication contract before a distinct dataset is queried.

## Registry

| Identifier | Descriptive name | Current stage | Status |
|---|---|---|---|
| `HYP-MOM-01.1` | Two Consecutive Green Gap-Ups | `DISCOVERY_REUSED_WINDOW` | `DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY` |
| `HYP-MOM-01.1 / DIAGNOSTIC_ATLAS_01` | Causal Condition and Path Atlas | `DISCOVERY_REUSED_WINDOW` | `DIAGNOSTIC_ATLAS_COMPLETE_NO_STRATEGY_AUTHORITY` |
| `HYP-MOM-01.1 / STOCK_ATLAS_02_BREADTH_EXTENSION` | Frozen 100-Name Breadth Extension | `DISCOVERY_REUSED_WINDOW` | `DISCOVERY_BREADTH_EXTENSION_COMPLETE_NO_STRATEGY_AUTHORITY` |
| `HYP-MOM-02.1` | SMA200 Cross Long/Cash | `DISCOVERY_REUSED_WINDOW` | `WIDE_DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY` |

`HYP-MOM-02.1` is authoritative under the
`CROSS_TRIGGERED_ONLY_NO_WARM_START` initialization. Every discovery path
starts in cash and can enter only after a fresh in-window cross above SMA200.
This correction restores the originally stated event question, so it does not
create a substantive-mechanics decimal revision such as `02.2`.
