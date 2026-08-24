# QQQ Minimal-Hypothesis Research Slate

Status: `QQQ_S1_S2_S3_S5_S6_STOP_S1_WRONG_SIGN_FOLLOWUP_BOOKMARKED_S4_DATA_BLOCKED`

Date bookmarked: `2026-08-21`

## Purpose

Preserve the operator-approved QQQ research slate before any outcome is read
or any individual test is formalized. The six entries below are separate
economic propositions. They are not rescues of stopped `LIT-MOM-01.x`,
`LIT-IMOM-01.x`, or M1 specifications, and they must not be collapsed into one
large model or one pooled discovery exercise.

The labels `QQQ-S1` through `QQQ-S6` are planning labels only. Each test must
receive its own formal Gen5 identifier and frozen contract before
implementation.

## Approved slate

| Planning label | Narrative hypothesis | Minimal predictor and target | Distinct mechanism | Main dependency or falsification risk |
|---|---|---|---|---|
| `QQQ-S1` | Recent cap-weighted Nasdaq-100 leadership over the same names at equal weight persists over a short forward horizon because benchmarked positioning adjusts gradually. | Predictor: trailing `QQQ minus equal-weight Nasdaq-100` log-return spread. Target: forward value of the same spread. | Within-universe concentration and mega-cap leadership, rather than broad-market direction. | A long, authoritative equal-weight Nasdaq-100 series must pass a return-blind history and methodology audit. The March 2026 QEW launch is not sufficient historical evidence by itself. |
| `QQQ-S2` | Semiconductor leadership early in the regular session reaches the broader growth complex with a delay. | Predictor: first-hour `SMH minus QQQ` or, if frozen ex ante, `SMH minus SPY` return. Target: QQQ excess return over the remainder of the same session. | Cross-asset intraday lead-lag. | QQQ's own first-hour return must be controlled so overlapping holdings and general market movement cannot masquerade as semiconductor leadership. |
| `QQQ-S3` | Nasdaq-100 leadership over the broad US market persists because style-allocation shifts occur gradually. | Predictor: trailing `QQQ minus SPY` log return. Target: forward `QQQ minus SPY` log return. | Relative style leadership with market direction removed. | This is closest to the stopped own-return predictor family; it advances only if the relative target adds information beyond intercept-only spread drift and the separate QQQ/SPY legs. |
| `QQQ-S4` | A QQQ advance supported by broad Nasdaq-100 participation is more durable than an equally large advance carried by a few names. | Predictors: QQQ return, causal constituent breadth, and their interaction. Target: forward QQQ return or a separately frozen QQQ-relative target. | Internal cross-sectional confirmation. | Requires point-in-time constituent membership and constituent bars. Current membership must never be projected backward. |
| `QQQ-S5` | A QQQ move accompanied by unusually high participation contains more persistent information than the same return on ordinary volume. | Predictors: trailing QQQ return, causal volume surprise, and one signed interaction. Target: forward QQQ return. | Participation-conditioned continuation. | ETF volume has market-structure ambiguity. The interaction must add forecast value beyond drift, raw return, and volume alone; nearby volume definitions may not be mined. |
| `QQQ-S6` | Within a frozen QQQ-adjacent growth and technology ETF basket, recent relative leaders continue to outperform recent laggards. | Predictor: trailing within-basket rank. Target: forward top-minus-bottom or rank-return relation. | Cross-sectional ETF leadership. | This overlaps conceptually with stopped M1. It is last priority and must justify the basket and grouping ex ante rather than reuse a correlated subset as a rescue. |

## Execution ledger

| Planning label | Formal identifier | Status | Decision |
|---|---|---|---|
| `QQQ-S1` | `HYP-MOM-07.1` | `STOP_HYP_MOM_07_1_NO_SEARCH_ADJUSTED_TRAIN_SURFACE` | All nine TRAIN correlations were negative; observed maximum `-0.038244` versus shift-null p90 `+0.166329`. No DEVELOPMENT or confirmation read. |
| `QQQ-S1-R` | not assigned | `BOOKMARKED_WRONG_SIGN_FOLLOWUP_NOT_OPEN` | Future independent investigation of whether cap-weighted leadership over equal weight predicts relative reversal. This is a novel question motivated by an unexpected full-surface sign, not a rescue, sign flip, or continuation of `HYP-MOM-07.1`; it requires a fresh contract and untouched evidence. |
| `QQQ-S2` | `HYP-IMOM-03.1` | `STOP_HYP_IMOM_03_1_TRAIN_LEAD_LAG_GATES_FAILED` | The all-TRAIN leadership coefficient was `-0.006352`; LEADER MSE was fractionally worse than the QQQ/SPY control, the wrong-clock placebo was better, and bootstrap probability of positive loss improvement was `0.514`. DEVELOPMENT and confirmation remained unread. |
| `QQQ-S3` | `HYP-MOM-08.1` | `STOP_HYP_MOM_08_1_NO_SEARCH_ADJUSTED_TRAIN_SURFACE` | Eight of nine TRAIN cells were negative. Lone-positive `L60_H20` rho `0.075240` missed shift-maximum p90 `0.151402`; no DEVELOPMENT or confirmation read. |
| `QQQ-S4` | not yet assigned | `BOOKMARKED_POINT_IN_TIME_MEMBERSHIP_AUTHORITY_REQUIRED` | Preserve as a distinct breadth contract. Do not project current Nasdaq-100 membership backward. |
| `QQQ-S5` | `HYP-MOM-09.1` | `STOP_HYP_MOM_09_1_NO_SEARCH_ADJUSTED_TRAIN_INTERACTION` | Best `L1_H20` partial interaction rho `0.120512` missed the complete shift-maximum p90 `0.137202`; empirical upper-tail probability `0.167051`. No nominee, DEVELOPMENT, or confirmation read. |
| `QQQ-S6` | `HYP-MOM-10.1` | `STOP_HYP_MOM_10_1_NO_SEARCH_ADJUSTED_TRAIN_RANKING` | All nine TRAIN rank-IC and top-minus-bottom cells were negative. Best `L5_H1` IC `-0.009265` missed shift-maximum p90 `0.096601`; randomized-rank upper-tail probability `0.944056`. No DEVELOPMENT or confirmation read. |

## Wrong-sign follow-up boundary

`QQQ-S1-R` preserves one future question: whether the uniformly negative
`HYP-MOM-07.1` TRAIN surface reflects a reproducible relative-reversal
mechanism rather than sampling variation. The bookmark records surprise, not
evidence of a tradable reversal. It may not reuse the HYP-MOM-07.1 horizon
search as selection evidence, invert the stopped nominee, or consume the
sealed HYP-MOM-07.1 DEVELOPMENT and confirmation periods. Any execution must
receive a new identifier, a reversal-specific economic narrative, fresh
evidence partitions, independent multiplicity control, and its own baselines
before returns are queried.

## Priority versus execution order

Scientific priority and operational order are different:

1. `QQQ-S1` is the preferred first scientific question because the
   cap-weight/equal-weight spread isolates leadership inside one constituent
   universe.
2. Before reading returns for `QQQ-S1` or `QQQ-S4`, run one return-blind data
   feasibility audit for historical equal-weight index coverage and
   point-in-time Nasdaq-100 membership.
3. If `QQQ-S1` data are admissible, freeze and run it first. If they are not,
   preserve the STOP and proceed to `QQQ-S2`; do not substitute a convenient
   current-composition series.
4. Run `QQQ-S2` next as the cleanest distinct, already-supported intraday
   lead-lag proposition.
5. Run `QQQ-S3` as the simplest daily relative-strength benchmark. Its result
   provides a useful control for interpreting the more specialized lanes.
6. Run `QQQ-S5` before the data-heavy breadth test because it needs only QQQ
   OHLCV and asks a narrower incremental question.
7. Run `QQQ-S4` once point-in-time membership authority is admitted.
8. Run `QQQ-S6` last because it has the greatest risk of duplicating the
   stopped ETF cross-sectional momentum evidence.

Every data-feasibility STOP is a valid result. Approval to test all six does
not authorize changing a proposition to evade a source or construction gate.

## Shared testing spine

Each formal contract should preserve the following common spine while
freezing its exact values independently:

- predictor evidence before any trading policy, allocation, leverage, or live
  behavior;
- adjusted bars, explicit as-of timestamps, next-observation timing, and no
  future constituent or classification information;
- log-return arithmetic for additive relative spreads;
- a TRAIN-estimated intercept-only drift or clock-aware intercept baseline;
- the simplest nested predictor as an additional control, such as raw QQQ
  return, QQQ-SPY spread, or QQQ's own first-hour return;
- a small predeclared horizon surface only where the economic story does not
  identify one horizon;
- family-wise search control inside a horizon surface and false-discovery
  control only where multiple assets or basket members are tested;
- one deterministic nominee rule followed by one locked development or
  confirmation evaluation, with unread evidence preserved when possible;
- economic sign, incremental forecast loss, uncertainty, support, and
  placebo/specificity gates rather than significance alone;
- a decisive STOP when the frozen mechanism fails, without nearby-window,
  asset-subset, threshold, or proxy rescue.

The exact date partitions cannot be copied blindly across daily and intraday
tests. Each contract must inventory available history first and create
non-overlapping TRAIN, DEVELOPMENT, and, where support permits, sealed
CONFIRMATION intervals.

## Hypothesis-specific controls

| Planning label | Required controls or placebos |
|---|---|
| `QQQ-S1` | Intercept-only spread drift; QQQ and equal-weight own-return legs; sign reversal; non-overlapping holding sensitivity if the primary target overlaps. |
| `QQQ-S2` | Clock-aware intercept; QQQ first-hour return; SPY first-hour return; wrong-leader or wrong-clock placebo fixed before outcomes; exclude overnight leakage from a remainder-of-session target. |
| `QQQ-S3` | Intercept-only relative drift; QQQ and SPY own-return legs; beta or simple market-return control frozen in TRAIN if required. |
| `QQQ-S4` | QQQ return alone; breadth alone; shuffled or lag-displaced breadth placebo; minimum causal member count and coverage gates. |
| `QQQ-S5` | Drift; raw return; volume surprise alone; calendar/clock effects where intraday data are used; split-adjustment and abnormal-volume construction checks. |
| `QQQ-S6` | Randomized rank control; basket-level common return; predeclared grouping or overlap diagnostic; comparison with the original M1 result without changing either contract. |

## Artifact and review plan

Each completed slice should produce:

1. one frozen hypothesis contract and, where needed, a source-admissibility
   note;
2. a run manifest, health table, compact summary table, and readable report;
3. one or two decisive figures plus representative event/trade-style tapes
   only when timing behavior is central;
4. a concise progress-log entry with the exact PASS, STOP, or blocked state;
5. a clearly separated new section in the existing momentum predictor evidence
   deck, including transition slides between daily relative leadership,
   intraday lead-lag, participation/breadth, and cross-sectional ETF phases.

## Current boundary

All six hypotheses remain part of the approved slate. `QQQ-S1`, `QQQ-S2`,
`QQQ-S3`, `QQQ-S5`, and `QQQ-S6` have been formalized, executed, and stopped
before DEVELOPMENT. The
`QQQ-S1-R` wrong-sign question remains a separate future bookmark, not a
rescue. No strategy replay, portfolio calculation, or confirmation read is
authorized. `QQQ-S4` remains blocked on point-in-time membership authority.
`QQQ-S6` is now complete under `HYP-MOM-10.1`; its all-negative surface does
not open a reversal rule. Opening `QQQ-S4` or `QQQ-S1-R` requires a fresh
operator decision and frozen contract; neither is an automatic rescue of the
completed STOPs.
