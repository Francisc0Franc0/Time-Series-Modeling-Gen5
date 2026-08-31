# EDL-MS-01 Attention-Stock Distinction Falsification

## Question

The wide-atlas replication suggested that attention stocks supplied most of
the apparent five-session recovery after a Rule 201 proxy breach followed by a
strong same-session reclaim. Does that distinction remain when attention-stock
events are compared with core-stock events from the same calendar year that
look similar before the outcome is observed?

## Frozen comparison

- Source packet: the 2018-2023 Rule 201 wide atlas.
- Event state: stocks only; Rule 201 proxy triggered; strong reclaim.
- Treatment cohort: `ATTENTION_SUPPLEMENT`.
- Comparator cohort: `GICS_CORE`.
- Matching: deterministic one-to-one matching without replacement within
  calendar year.
- Pre-outcome matching variables: minimum intraday return, close-location
  value, log abnormal dollar volume, and event date.
- Sole inferential outcome: cumulative next-open log return through session
  five.
- Test: exact one-sided paired sign-flip test of whether the mean
  attention-minus-core difference is positive.
- Matching-validity gate: maximum absolute post-match standardized mean
  difference at or below 0.25.
- Sensitivity: every leave-one-year-out and leave-one-attention-symbol-out mean
  must remain positive.

The matcher was constructed before forward returns were attached. No outcome,
horizon, cost assumption, or post-2023 observation was used to form pairs.

## Plain-English Rule 201 recap

The complete investigation now tells a simple story:

1. The initial idea was that a stock which fell at least 10% intraday but then
   closed near its session high might continue rebounding after the signal day.
   The 10% daily-low rule was a price-based Rule 201 proxy, not confirmed
   exchange status.
2. The original ten-stock pilot looked interesting. Its triggered,
   strong-reclaim events had a median return near +3.7% by the fifth session
   after next-open entry, but the median faded below zero by session ten, the
   mean was negative, and AMC plus CVNA supplied most of the observations.
3. The frozen 129-instrument expansion did not reproduce that result in the
   balanced 88-stock core. The corresponding core day-five median was roughly
   -0.24% across 21 qualifying events. Most of the positive all-stock result
   came from the separate attention-stock cohort.
4. The attention-stock explanation then failed its frozen matched follow-up.
   Attention events performed 3.34 log-percentage-points worse than matched
   core events at day five, with a one-sided p-value of 0.818.
5. That final comparison was not clean enough for a definitive matched
   rejection because breach severity and event timing remained imbalanced.
   The attention label therefore fails as an explanation, while the different
   event environments become the next research question.

Current conclusion: the Rule 201 work produced a useful temporary-rebound clue
and a clearer description of where it failed, but no tradable Rule 201 rule.
Do not trade the cohort label or alter the matcher after seeing outcomes.

## What happened

Twenty pairs were available: one in 2018, ten in 2020, five in 2022, and four
in 2023. The 2021 attention events had no same-year core events, and additional
attention events were excluded by comparator capacity.

The positive attention-stock distinction did not reproduce in those pairs:

- Mean attention-minus-core day-five log-return difference: **-3.34 percentage
  points**.
- Median paired difference: **-3.67 percentage points**.
- Attention events won **45%** of pairs.
- Exact one-sided sign-flip p-value: **0.818244** across all 1,048,576 sign
  assignments.
- Matched attention median simple return: **-1.89%**; matched core median:
  **-0.32%**.
- Every leave-one-year-out and leave-one-attention-symbol-out mean remained
  negative, not positive.

## Why the formal status is inconclusive

The maximum absolute post-match standardized mean difference was **0.421**,
above the frozen 0.25 limit. Breach severity remained imbalanced at 0.421 and
event date at 0.331; close location and abnormal dollar volume were within the
limit.

That means the observed negative paired result is strong evidence against the
simple claim that an attention label alone explains the earlier recovery hump,
but it is not a clean matched-estimand rejection. The available attention and
core target events occupy different pre-outcome environments, and the frozen
matcher could not make them sufficiently comparable.

## Decision

Status: `INCONCLUSIVE_MATCH_BALANCE_FAILED`.

Do not reinterpret the wide-atlas attention hump as an edge, and do not modify
the matcher after seeing outcomes. The next rational slice is a separately
frozen separator investigation: quantify which pre-outcome event and asset
characteristics distinguish attention-stock target events from core-stock
events. Breach severity and calendar/event timing are the first demonstrated
separators; any additional asset-level characteristics must be selected before
testing their relationship with forward outcomes.

No costs, strategy replay, holding-period search, post-2023 outcomes, intraday
data, or live behavior are opened by this result.

## Evidence

- Packet: `runs/research_workbench/edge_discovery_lab/edl_ms_01_attention_falsification_20260831`
- Runner: `scripts/inspect/run_edl_ms_01_attention_falsification.R`
- Helper: `edge_discovery_lab/R/edl_ms_01_attention_falsification.R`
- Tests: `edge_discovery_lab/tests/testthat/test_edl_ms_01_attention_falsification.R`
- Deck: `edge_discovery_lab/presentations/edl_ms_01_attention_falsification.pptx`
