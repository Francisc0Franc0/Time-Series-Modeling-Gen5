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
| `HYP-MOM-02.2` | Qualified SMA200 Entry / SMA50 Exit | `DISCOVERY_REUSED_WINDOW` | `WIDE_DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY` |
| `HYP-MOM-02 / ATTRIBUTION_ATLAS_01` | Entry / Exit / Re-entry Attribution | `DISCOVERY_REUSED_WINDOW` | `REUSED_WINDOW_ATTRIBUTION_COMPLETE_NO_PROMOTION_AUTHORITY` |
| `HYP-MOM-02.3` | Qualified SMA200 Entry / SMA50 Exit / SMA50-Reclaim Re-entry | `HISTORICAL_DEVELOPMENT` | `STOP_NO_DEVELOPMENT_NOMINEE` |
| `HYP-MOM-03.1` | Rising-SMA200 Regime / SMA50 Pullback Reclaim | `HISTORICAL_DEVELOPMENT` | `STOP_NO_DEVELOPMENT_NOMINEE` |

`HYP-MOM-02.1` is authoritative under the
`CROSS_TRIGGERED_ONLY_NO_WARM_START` initialization. Every discovery path
starts in cash and can enter only after a fresh in-window cross above SMA200.
This correction restores the originally stated event question, so it does not
create a substantive-mechanics decimal revision such as `02.2`.

`HYP-MOM-02.2` is the substantive revision: entry requires both a fresh
in-window SMA200 cross and close above SMA50; exit occurs after the first close
at or below SMA50; and re-entry requires a new qualified SMA200 cross. The
warm-start and fresh-cross `02.1` views remain valuable estimands inside the
same investigation, but the composite entry, exit, and lockout change warrants
the decimal increment.

`HYP-MOM-02.3` is a substantive repair to the strict `02.2` lockout: after the
first qualified trade exits, a fresh SMA50 reclaim above SMA200 may re-enter
without waiting for another SMA200 cross. `HYP-MOM-03.1` is a new concept,
because the rising SMA200 becomes regime permission and the SMA50 reclaim—not
the SMA200 cross—becomes the entry setup. Both stopped on their predeclared
2016-2020 development gates; neither opened a context variant or confirmation.
