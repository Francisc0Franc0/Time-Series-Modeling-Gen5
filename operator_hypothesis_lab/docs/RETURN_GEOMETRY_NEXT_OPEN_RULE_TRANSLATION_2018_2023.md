# Return-Geometry Next-Open Rule Translation (2018-2023 TRAIN)

## Purpose

The incremental decomposition showed that signed-ER20 down-state loss-rebound
geometry continued into approximately sessions 41-60 before fading. This slice
asks a narrower practical question: does a clean event rule retain enough of
that behavior when signals are known at a completed close and trades execute at
the next open?

This is the first executable translation of the descriptive finding. It is a
TRAIN mechanics study, not temporal confirmation or a portfolio backtest.

## Frozen Rule

- Universe: all 129 instruments in the frozen wide atlas.
- Primary aggregation: the 88 full-history stocks, summarized asset first,
  sector second, and equal-sector third.
- Diagnostic cohorts: 16 attention names, 15 equity ETFs, and 10 non-equity
  proxies.
- Evidence window: adjusted daily bars from 2018 through 2023. Earlier bars
  may initialize causal history; post-2023 outcomes remain sealed.
- Signal at completed close `t`:
  - signed ER20 is `DOWN_TREND` (`signed ER20 <= -0.30`); and
  - the current 20-session log return is at or below the causal 20th percentile
    of that asset's previously observed negative 20-session returns.
- At least 100 earlier negative 20-session returns are required before the
  severity threshold exists.
- Execution: enter at adjusted open `t+1`; exit at adjusted open `t+21`.
- Position policy: one active position per asset; ignore intervening signals;
  allow a new signal at the close of the exit session.
- Cost descriptor: 10 bp round trip.
- Comparator: the same timing and non-overlap policy without the bottom-quintile
  severity gate, plus same-asset unconditional 20-session open-to-open drift.

## Construction Audit

All 14 checks passed. The run processed all 129 frozen instruments and all 88
core stocks. Every primary signal met the signed-down and causal severity rules,
every entry occurred at the next open, every exit followed 20 held sessions,
and no asset held overlapping positions. The latest exit was 2023-12-26;
post-2023 outcomes were not queried or calculated.

## TRAIN Readout

- Primary rule: 2,221 trades across 129/129 active instruments.
- Core: 1,548 trades across 88/88 active stocks.
- Equal-sector median asset mean net return: `+0.82%` per trade.
- Equal-sector median asset mean net excess over unconditional drift: `+0.17%`
  per trade.
- Median core-asset mean net excess: `+0.019%` per trade.
- Event-pooled core mean net excess: `-0.25%` per trade.
- Positive-excess sector medians: `6/11`.
- Equal-sector median difference versus the signed-down state-only rule:
  `+0.06%` per trade.
- State-only comparator: 2,768 trades.

The aggregation lenses conflict. Giving each sector and then each asset equal
weight produces a modestly positive typical result, while giving every core
event equal weight produces a negative result. This means the rule's apparent
support is not invariant to how repeated signals and heterogeneous assets are
weighted.

## Close-to-Open Translation

For the 1,548 core events:

- mean research close-to-close return: `+0.60%`;
- mean executable gross open-to-open return: `+0.55%`; and
- mean translation difference: `-0.04%`.

The execution-clock change therefore does not explain the rule's failure. The
descriptive and executable returns are closely aligned event by event. The
failure arises primarily from weak excess return, uneven sector breadth, and
cross-asset/event heterogeneity.

## Cohort and Calendar Shape

- GICS core median asset mean net return: `+0.75%`.
- Equity ETF controls: `+0.64%`.
- Attention supplement: `-1.78%`.
- Non-equity controls: `-0.16%`.

Core event-pooled mean net returns were positive in 2018, 2019, 2021, and 2023,
but negative in 2020 and 2022. The strong 2019 and 2021 results coexist with a
large 2020 loss and a smaller 2022 loss. The pattern is not a smooth,
period-invariant response.

## Frozen TRAIN Disposition

The predeclared mechanics check required:

1. at least 70 active core assets — passed with 88;
2. at least 7 positive-excess sectors — failed with 6;
3. positive equal-sector median net excess — passed; and
4. positive median core-asset net excess — passed.

Status:

`TRAIN_RULE_TRANSLATION_DOES_NOT_RETAIN_MECHANICAL_SUPPORT_STOP_OOS`

The event-pooled negative excess, calendar instability, and weak incremental
benefit from the severity filter strengthen the STOP interpretation, although
they were not added retroactively to the frozen four-part rule.

## Evidence Surface

- Packet: `runs/research_workbench/operator_hypothesis_lab/return_geometry_next_open_rule_translation_20260828`
- Script: `scripts/inspect/run_return_geometry_next_open_rule_translation.R`
- R helper: `operator_hypothesis_lab/R/return_geometry_next_open_rule_translation.R`
- Deck: `operator_hypothesis_lab/presentations/return_geometry_edge_promotion_huddle.pptx`

The packet includes the primary and state-only trade ledgers, asset/sector/cohort
summaries, calendar slices, average paths, construction checks, representative
trade tapes, and the frozen TRAIN disposition.

## STOP

Do not open OOS. Do not rescue this rule by changing the 20th percentile,
minimum history, ER cutoff, hold period, overlap policy, costs, aggregation,
cohorts, or universe after inspection. Any future executable rule must begin as
a separately motivated and frozen variant.
