# Return-Geometry Edge-Promotion Huddle

## Purpose

The 123-slide descriptive microscope deck is closed. This huddle starts a new
deck for the narrower question that follows the wide-atlas milestone: how can a
broad, transported return behavior be falsified or promoted toward a candidate
trading edge without mistaking cumulative-window geometry for response timing?

## The Nested-Window Intuition

A rebound that occurs only during sessions 6-10 after a negative prior return
can appear in every cumulative following-return window that contains those
sessions. In log-return notation:

`R(1:100) = R(1:10) + R(11:100)`

Therefore a relationship visible at 100 following sessions does not, by
itself, mean that conditional return continued to arrive for 100 sessions. It
may be an early response inherited by the larger cumulative target. The 5-day
target would miss a rebound beginning after day 5; the 10-day target would
capture it; and the 20-, 50-, and 100-day targets would continue to contain it.

## Why a 100-Session Effect Could Still Be Actionable

Long horizon is not disqualifying. If conditional excess return continues to
accrue in later, non-overlapping blocks, the behavior could describe a
medium-term position rather than a swing trade. Actionability would still
require the rule to improve a decision after accounting for unconditional
drift, state-only expected return, matched long exposure, overlapping signals,
risk, costs, and opportunity cost.

## Recommended Next Slice

Retain the original 20-session negative-prior anchor and decompose the future
target into non-overlapping blocks:

- sessions 1-5;
- sessions 6-10;
- sessions 11-20;
- sessions 21-40;
- sessions 41-60; and
- sessions 61-100.

This measurement distinguishes an early rebound that echoes through nested
cumulative targets from genuinely persistent conditional accrual. Freeze the
anchor, blocks, states, aggregation, estimand, baselines, and failure rule
before opening later data. Do not query post-2023 evidence in this slice.

## Evidence Surface

- New deck: `operator_hypothesis_lab/presentations/return_geometry_edge_promotion_huddle.pptx`
- Closed descriptive deck: `operator_hypothesis_lab/presentations/tsla_descriptive_microscope_evidence.pptx`
- Workflow roadmap: `operator_hypothesis_lab/docs/OWN_ASSET_RETURN_GEOMETRY_WORKFLOW_ROADMAP.md`

## Executed Incremental Slice

The frozen decomposition has now been run on the 2018-2023 atlas evidence. All
six future blocks use the same anchors with a complete 100-session future path.
The `21-40` and `41-60` blocks retain negative relationship breadth and positive
conditional return above same-asset unconditional drift. The `61-100` block
does not retain positive drift-adjusted accrual.

This falsifies the simplest early-echo explanation: the response is not
confined to the first 5-10 sessions. It also rejects a stronger 100-session
duration interpretation. The defensible descriptive summary is that the
response continues into approximately sessions 41-60 and then fades.

See `RETURN_GEOMETRY_INCREMENTAL_FORWARD_DECOMPOSITION_2018_2023.md` and slides
8-14 of the huddle deck.

## Stop State

`LATE_INCREMENTAL_DURATION_RETAINS_DESCRIPTIVE_SUPPORT`

Do not infer a holding rule, retune blocks, or open post-2023 outcomes before a
new gate is designed.

## Executable Rule Translation

The operator then opened one causal TRAIN rule on all 129 atlas instruments.
The 88-stock, 11-sector core remained the primary equal-sector surface; the
attention, ETF, and non-equity cohorts remained visible diagnostics. The rule
required signed ER20 DOWN plus a 20-session loss at or below the causal 20th
percentile of the asset's prior negative 20-session returns. It entered at the
next open, exited 20 held sessions later, ignored overlapping signals, and
included a 10 bp round-trip cost descriptor.

All 14 construction checks passed. The rule produced 2,221 TRAIN trades across
all 129 instruments, including 1,548 trades across all 88 core stocks. The
close-to-open translation cost was small: mean core research return was +0.60%
versus +0.55% gross executable return. The failure was cross-sectional and
temporal. Only 6/11 sector medians had positive excess, the event-pooled core
was -0.25% per trade below unconditional drift, attention names were negative,
and 2020 and 2022 were losing calendar slices.

Current status:

`TRAIN_RULE_TRANSLATION_DOES_NOT_RETAIN_MECHANICAL_SUPPORT_STOP_OOS`

See `RETURN_GEOMETRY_NEXT_OPEN_RULE_TRANSLATION_2018_2023.md`. Do not tune or
open post-2023 outcomes.
