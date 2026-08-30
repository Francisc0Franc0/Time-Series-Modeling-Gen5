# EDL-MS-01 — Rule 201 Reclaim

## Narrative Hypothesis

When a volatile stock trades at least 10% below its previous close but absorbs
the selling and closes strongly, the combination of demonstrated demand and the
next-session short-sale price restriction may create a temporary long-side
rebound or continuation environment.

This is not the hypothesis that every 10% decline should be bought. The proposed
interaction is:

`severe decline + Rule 201 threshold + strong same-session reclaim`

## Mechanism

Regulation SHO Rule 201 is triggered when the listing market determines that a
covered security has declined at least 10% from its prior regular-session close.
The price test then generally prevents short sales from executing at or below
the current national best bid for the remainder of the trigger day and the next
trading day. It restricts aggressive short selling; it does not ban shorting.

Primary references:

- SEC Rule 201 FAQ:
  https://www.sec.gov/rules-regulations/staff-guidance/trading-markets-frequently-asked-questions-7
- Nasdaq Short Sale Circuit Breaker files:
  https://nasdaqtrader.com/trader.aspx?id=ShortSaleCircuitBreaker

## Frozen Discovery Slice

- Study period: 2018-01-02 through 2023-12-29 only.
- Discovery basket: TSLA, AMD, NVDA, GME, AMC, CVNA, PLTR, COIN, SOFI, and
  RIVN.
- The basket is intentionally operator-style and illustrative. It is not a
  representative atlas and cannot support universe-level claims.
- Preliminary daily-bar proxy: adjusted daily low divided by prior adjusted
  close minus one.
- Fixed threshold: -10%.
- Visual neighborhood: -12% through -8% minimum intraday return.
- Reclaim measurement: close location within the daily high-low range.
- Point size: dollar volume relative to its strictly prior 20-session median.
- Forward display: next-open entry with descriptive 1-, 3-, and 5-session
  open-to-open outcomes.
- No significance tests, optimized thresholds, costs, portfolio replay, or OOS.

The daily-low rule is a proxy, not exact regulatory authority. Exact status is
determined from eligible regular-hours last-sale trades by the listing market.
Official exchange trigger files must be added before any executable study.

## First Operator Questions

1. Is there a visible discontinuity around the fixed -10% boundary?
2. Does strong close location separate the visual outcomes more clearly than
   the threshold itself?
3. Do abnormal-volume points behave differently enough to justify a later
   explicit volume slice?
4. Do deterministic tapes support the proposed absorption story, or reveal
   that the daily bar is too coarse?

## Status

`DISCOVERY_SLICE_COMPLETE_NO_EDGE_CLAIM`

## First Visual Readout

The frozen band contains 646 events: 239 daily-low proxy triggers and 407 near
misses. Strong-reclaim events are uncommon: 24 proxy-triggered observations and
31 near misses close in the top quarter of their daily range.

The scatterplot does not show an obvious visual discontinuity at -10%. Outcomes
are widely dispersed on both sides of the line, and high close-location points
also contain positive and negative following-session returns. This is not a
statistical conclusion; it is the first visual reason to avoid treating the
regulatory threshold as a stand-alone buy signal.

The first chronological tape in each of the four threshold/reclaim categories
has a negative following-session return. Three of those four paths are positive
by the descriptive five-session mark. Four examples cannot establish a holding
horizon, but they make the immediate-next-session and slower-recovery theses
visibly distinct.

Artifacts:

- `runs/research_workbench/edge_discovery_lab/edl_ms_01_rule201_reclaim_discovery_20260830`
- `visuals/rule201_threshold_scatter.png`
- `visuals/rule201_deterministic_event_tapes.png`

The next decision will be made after inspecting the first scatterplot and event
tapes. Do not widen the universe, add inference, or query post-2023 outcomes
automatically.
