# HYP-MOM-01.1 Two Consecutive Green Gap-Ups: Discovery Contract

Status: `FROZEN_BEFORE_OUTCOME_INSPECTION`

Evidence stage: `DISCOVERY_REUSED_WINDOW`

## Question

After two consecutive daily sessions each gap above the prior close and finish
green, what happens if a long position is entered at the next session's open
and held for five open-to-open intervals?

The goal is mechanical and behavioral discovery. This contract cannot validate
alpha because it deliberately reuses the already inspected 2021-2023 window.

## Signal

For consecutive completed sessions `t-1` and `t`, require:

```text
Open[t-1] > Close[t-2]
Close[t-1] > Open[t-1]
Open[t]   > Close[t-1]
Close[t]  > Open[t]
```

All inequalities are strict. There is no minimum gap size, minimum candle-body
size, volume rule, trend filter, sector filter, or market-state filter.

The signal becomes observable only after session `t` closes.

## Execution

- Direction: long only.
- Entry: adjusted open of session `t+1`.
- Exit: adjusted open five trading intervals after entry.
- Capital semantics: one fully invested fixed-quantity position per asset.
- Overlap: no overlapping positions within an asset; signals while invested
  are ignored.
- Same-open re-entry: allowed when a new eligible signal was completed before
  an existing trade's exit open.
- Reinvestment: each completed trade begins with the asset path's current
  equity.
- Primary friction: 5 bp at entry and 5 bp at exit.
- Stress friction: 10 bp at entry and 10 bp at exit.
- Borrow: none.

The POC evaluates each asset independently. It does not create a cross-asset
portfolio, allocation rule, or live recommendation.

## Discovery data

- Window: 2021-01-04 through 2023-12-29.
- Confirmation exclusion begins: 2024-01-02.
- Universe: the previously frozen 22-stock, eleven-sector Atlas 01 panel, copied
  into an Operator Hypothesis Lab registry before outcomes are inspected.
- Benchmark/context: SPY adjusted daily bars.
- Bar source: the existing Alpaca adjusted-daily Atlas 01 packet, queried with
  explicit `as_of_timestamp = 2026-07-30 17:30:00` and bounded at 2023-12-29.

Reusing this universe and window is a declared convenience for discovery, not
independent evidence.

## Required readout

For every asset and for the pooled descriptive trade set, report:

- signal count, executed-trade count, ignored-overlap signal count, and
  participation;
- gross, primary-cost, and stress-cost compounded return;
- mean, median, hit rate, maximum drawdown, and time under water;
- buy-and-hold return over the same window;
- unconditional five-session open-to-open forward-return control;
- 1,000 seeded matched-random non-overlapping schedules preserving the asset's
  trade count, holding period, and cost convention;
- calendar-year behavior; and
- representative strategy and individual-trade tapes.

Before individual outcomes are viewed, the strategy-path tape set is frozen as
five unique assets: the robust multivariate medoid, highest primary return,
lowest primary return, highest matched-random percentile, and highest executed
trade count, with alphabetical ticker tie-breaks and the next eligible asset
used when an archetype duplicates an earlier selection. The individual-trade
set is frozen as the best primary trade, worst primary trade, trade nearest the
pooled median, largest peak-to-exit giveback, and largest trough-to-exit
recovery. These are outcome-aware descriptive examples, not frequency or
selection evidence.

Matched-random results are descriptive because the discovery window and
universe are already known. Nominal p-values, if shown, must be labeled naive
under cross-asset and temporal dependence.

## Interpretation boundary

This run may answer:

- whether the exact rule fires often enough to study;
- whether outcomes look like continuation, ordinary exposure, or noise;
- whether losses occur immediately or after initial follow-through;
- which exit or filter questions are worth discussing next.

It may not:

- select the best asset as a trading candidate;
- choose a different holding period from this window and call it validated;
- promote a gap-size, trend, volume, sector, market, stop, or target filter;
- form a portfolio;
- query or reinterpret 2024+ confirmation data; or
- alter live advice or execution.

Any substantive follow-up remains `HYP-MOM-01.1` only if the trading
proposition is unchanged. A changed signal or exit mechanic requires a newly
justified decimal variant and a fresh contract.
