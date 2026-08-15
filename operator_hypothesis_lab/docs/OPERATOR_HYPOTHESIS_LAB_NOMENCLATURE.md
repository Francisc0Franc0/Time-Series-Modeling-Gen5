# Operator Hypothesis Lab Nomenclature

Status: `FROZEN`

## Umbrella and identifier

Operator-origin hypotheses use:

`HYP-[FAMILY]-[CONCEPT].[VARIANT]`

- `HYP` distinguishes operator-origin questions from `LIT` literature-derived
  questions and mainline Gen5.x research.
- `FAMILY` identifies the proposed economic behavior or measurement source,
  such as `MOM`, `IMOM` for intraday-bar momentum, `MR`, `EVT`, `VOL`, `TA`,
  or `ALT` for alternative data.
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
| `HYP-MOM-04.2` | Causal Feature Atlas + Nested Basket Search | `TRAIN_FEATURE_DIAGNOSTICS_AND_SELECTION` | `STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN` |
| `HYP-MOM-04.3A` | Target Structure Audit | `TRAIN_TARGET_DIAGNOSTICS` | `TARGET_AUDIT_COMPLETE_SELECTION_NOT_FROZEN` |
| `HYP-MOM-04.3B` | Sector-Relative Temporal Replication | `HISTORICAL_DEVELOPMENT` | `STOP_DEVELOPMENT_REPLICATION_FAILED_CONFIRMATION_NOT_RUN` |
| `HYP-MOM-04.3C` | Frozen-Feature Transport Audit | `RETROSPECTIVE_DEVELOPMENT_DIAGNOSTIC` | `FEATURE_TRANSPORT_AUDIT_COMPLETE_NO_PROMOTION_AUTHORITY` |
| `HYP-MOM-05.1` | Ordered Triple-SMA Pullback/Reclaim | `DISCOVERY_REUSED_WINDOW` | `WIDE_DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY` |
| `HYP-MOM-05.2` | Triple-SMA Grid Walk-Forward | `REUSED_WINDOW_WALK_FORWARD_DEVELOPMENT` | `STOP_DEVELOPMENT_WFA_FAILED_CONFIRMATION_NOT_RUN` |
| `HYP-MOM-06.1` | Daily SMA8/SMA14 Crossover Reconstruction | `PLANNED` | `FROZEN_PLAN_EXECUTION_NOT_OPEN` |
| `HYP-IMOM-01.1` | 30-Minute SMA8/SMA14 Crossover Reconstruction | `PLANNED` | `FROZEN_PLAN_EXECUTION_NOT_OPEN` |
| `HYP-IMOM-02.1` | Session-Scaled 30-Minute Price/SMA Cross | `PLANNED` | `FROZEN_PLAN_EXECUTION_NOT_OPEN` |
| `HYP-ALT-01.1` | WSB Daily Ticker Attention Tape | `FORWARD_COLLECTION_POC` | `IMPLEMENTED_STOP_LIVE_REDDIT_ACCESS_NOT_CONFIGURED` |

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

`HYP-MOM-04.2` is a substantive derivative because it expands the feature
question from six variables to a frozen 33-feature atlas, replaces one pooled
Ridge selection with nine predefined basket candidates under nested
time-ordered validation, and makes the complete candidate search part of a
permutation null. It is not permission to enumerate arbitrary subsets. Pooled
scatter and decile shapes remain descriptive; outer transport and the
search-adjusted null govern promotion. Both failed, so OOS remained sealed.

`HYP-MOM-04.3A` is a diagnostic derivative because it changes no feature,
model, portfolio, or data boundary. It decomposes the H04.2 target into three
predeclared economic questions and measures how sector and prior beta alter
the evidence. The `A` suffix distinguishes this audit from a future, separately
approved target-specific model lane. The audit recommends sector-relative
return for discussion but leaves target selection explicitly unfrozen.

`HYP-MOM-04.3B` freezes the recommended sector-relative target and tests one
compact four-feature Ridge model on later `2021Q1-2023Q3` data. The letter
increment distinguishes target audit (`A`) from target-specific temporal
replication (`B`) without pretending it is a new strategy family. The model
failed five of six replication gates and underperformed both frozen
comparators. Preserve the STOP and keep 2024+ confirmation sealed.

`HYP-MOM-04.3C` is a diagnostic derivative of the failed `04.3B` replication.
It changes no target, feature, model, or evidence boundary and fits nothing.
The `C` suffix marks a retrospective explanation of feature transport: full-
rank IC, quartile and decile shape, temporal breadth, sector breadth, frozen-
coefficient direction, and terminal sensitivity. It nominates no feature and
does not authorize a sign flip or confirmation run.

`HYP-MOM-05.1` is a new minimal formulaic concept. The ordered 15/30/45 stack
provides trend permission; a fresh stack activation creates the first entry;
close at or below SMA30 exits; and a fresh SMA30 reclaim while still ordered
is the only post-exit re-entry. Losing stack order alone does not exit. Its
1x/1.8x wide discovery was broadly negative, with reclaims dominating the
trade count and behaving as short-lived whipsaws. Preserve the no-promotion
status and treat any reclaim delay, confirmation, slope, volatility, average,
asset, or sector change as a separately frozen hypothesis.

`HYP-MOM-05.2` is a substantive same-family variant because parameter
selection becomes part of the model. It freezes a 27-triplet horizon family,
global expanding half-year selection, a five-component rank score, and a
one-standard-error low-turnover tie-break. The selector moved toward slower,
more separated horizons but produced negative median return in every outer
block and weak matched-timing percentiles. Preserve the development STOP and
treat any grid expansion or mechanism filter as a distinct hypothesis rather
than an H05.2 retry.

`HYP-MOM-06.1`, `HYP-IMOM-01.1`, and `HYP-IMOM-02.1` are completed DEVELOPMENT
identifiers. `HYP-MOM-06.1` reconstructs the operator's daily SMA8/SMA14
question and remains the accepted positive absolute-return parent baseline.
`HYP-IMOM-01.1` asks the economically distinct question on 30-minute bars,
where the same numeric averages cover roughly one session. `HYP-IMOM-02.1`
ports the price/slow-anchor question using session-equivalent 30-minute
horizons. The related Chan adaptation remains `LIT-IMOM-01.1` under the
literature-study phylogeny. The shared series is complete and stops before any
confirmation or live authority.

`HYP-REG-01.1` is a strategy-independent measurement lane: causal ATR14/close
percentiles with a prior-252-session memory and hysteretic low/medium/high
states. Its pass establishes volatility-magnitude classification only.
`HYP-REG-01.2` is a substantive decimal variant because the accepted state is
allowed to control entry permission for the unchanged `HYP-MOM-06.1` strategy.
It freezes `ATR_LOW_OFF` as one specific overlay and permanently records its
DEVELOPMENT failure. Trying another state combination, transition rule,
threshold, strategy, or asset subset requires a new predeclared variant; it is
not a reactive repair of `01.2`.

`HYP-ALT-01.1` is a measurement lane rather than a trading strategy. `ALT`
marks an alternative-data source, while `01.1` freezes the first approved WSB
comment-collection and ticker-recognition design. Provider access, coverage,
privacy, deletion, and symbol-classification evidence must pass before any
separate hypothesis may ask whether the resulting attention measure predicts
prices. Changes to sentiment, source communities, day cutoffs, ticker parsing,
or predictive targets require a separately discussed contract.
