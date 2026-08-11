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
| `HYP-MOM-04.1` | Regularized Trend-State Quartile | `TRAIN_SELECTION` | `STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN` |
| `HYP-MOM-04.1 / SP500-PIT-DATA-AUDIT-01` | Point-in-Time S&P 500 Replication Feasibility | `DATA_FEASIBILITY_AUDIT` | `STOP_SP500_PIT_DATA_GATES_FAILED_REPLICATION_NOT_RUN` |
| `HYP-MOM-04.1 / SP500-PIT-SOURCE-REPAIR-01` | Accessible Source Repair | `DATA_SOURCE_FEASIBILITY` | `STOP_SP500_PIT_SOURCE_REPAIR_INCOMPLETE_FALLBACK_DISCUSSION_OPEN` |
| `HYP-MOM-04.1 / DEPLOYMENT-UNIVERSE-DATA-AUDIT-01` | September 2020 SPY Fixed Deployment Cohort | `DATA_FEASIBILITY_AND_TRAIN_SELECTION` | `STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN` |

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

`HYP-MOM-04.1` is a new concept because it replaces a single formulaic signal
with a six-feature cross-sectional quarterly ranker. Its pooled TRAIN fit was
strong, but the expanding-validation rank IC was negative. The frozen OOS lock
therefore held: 2021-2023 was not queried, and no pooled-fit feature or
comparator may be promoted under this identifier.

`HYP-MOM-04.1 / SP500-PIT-DATA-AUDIT-01` changes no model mechanic. It is a
pre-replication data-feasibility sub-lane. Six of nine hard data gates passed,
but public-roster identity agreement, contemporaneous sector coverage, and
terminal-outcome completeness failed. No `SP500-PIT-REPLICATION-01` strategy
lane was therefore frozen or run.

`HYP-MOM-04.1 / SP500-PIT-SOURCE-REPAIR-01` changes no model or gate. It tested
whether existing entitlements could repair the failed data audit. Alpaca
returned relevant corporate-action records for only 8 of 39 unresolved
identities, while no licensed point-in-time membership/delisting authority was
available locally.

`HYP-MOM-04.1 / DEPLOYMENT-UNIVERSE-DATA-AUDIT-01` keeps every model mechanic
unchanged while replacing the unusable historical-membership plumbing with a
fixed SPY cohort publicly knowable before OOS. The corrected September 2020
filing passed all nine data gates and authorized the unchanged Ridge TRAIN on
481 complete identities. Expanding-validation IC was nevertheless `-0.0623`
and positive in only `4 / 9` quarters. G3 failed, so the shared
`STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN` remains authoritative and no 2021-2023
outcome was queried.
