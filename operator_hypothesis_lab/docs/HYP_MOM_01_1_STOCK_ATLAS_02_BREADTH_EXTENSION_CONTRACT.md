# HYP-MOM-01.1 Stock Atlas 02 Breadth Extension Contract

Status: `FROZEN_DISCOVERY_BREADTH_EXTENSION`

## Question

Does the unchanged `HYP-MOM-01.1` two-green-gap-up strategy, together with
the complete frozen `DIAGNOSTIC_ATLAS_01`, show similar behavior when applied
to the previously frozen 100-name 2020 breadth-and-attention registry and then
combined with the original 22-asset discovery panel?

## Nomenclature

This is `HYP-MOM-01.1 / STOCK_ATLAS_02_BREADTH_EXTENSION`. It increases the
breadth of the same hypothesis and does not create a decimal variant. No
signal, exit, cost, diagnostic, or live-behavior mechanic changes.

## Frozen identity source

The identity registry is reused unchanged from:

`literature_studies/registries/gen5_lit_mom_01_2_stock_atlas_02_2020_breadth_attention_registry.csv`

It contains exactly 100 names with zero overlap to the original 22:

- 75 `DIVERSIFIED_CORE` stocks selected from the June 30, 2020 SEC-filed SPY
  holdings schedule with sector-balanced, liquid, recognizable representation;
  and
- 25 `RETAIL_ATTENTION_2020` stocks documented in contemporaneous 2020
  Robinhood or Robintrack coverage.

The registry was constructed for a different literature exercise before this
test's outcomes were known. Reusing it here is an outcome-blind breadth choice,
not a search for names favorable to `HYP-MOM-01.1`.

## Coverage gate

Every registry row remains visible. A stock is eligible only when:

1. its Alpaca adjusted daily bars include every SPY discovery session from
   January 4, 2021 through December 29, 2023;
2. at least 220 adjusted daily observations exist before discovery begins, so
   both the SMA200 and its frozen 20-session prior-state comparison are
   available without shortening either lookback;
3. no duplicate symbol/session rows, future observations, or invalid OHLCV
   values appear; and
4. at least one complete causal trade is generated.

Coverage failures are not replaced. The expected combined pool is therefore
approximately 122 assets, not a promise that all 100 additional identities
will be analytically eligible.

## Unchanged parent strategy

- Signal: two consecutive completed daily sessions both open above the prior
  close and finish green.
- Observation: after the second session closes.
- Entry: next session open, long only, full capital within each independent
  asset replay.
- Exit: the open after five complete open-to-open holding intervals.
- Overlap: ignore new signals while invested; same-open re-entry is allowed.
- Costs: 5 bp per side primary and 10 bp per side stress.
- Window: January 4, 2021 through December 29, 2023.
- Controls: buy-and-hold and 1,000 matched non-overlapping random calendars per
  eligible asset.

No cross-asset portfolio is formed.

## Frozen diagnostic atlas

Every `DIAGNOSTIC_ATLAS_01` definition remains unchanged:

- two-gap and two-body strength scaled by strictly lagged 20-session
  close-return volatility;
- asset SMA200 state and normalized distance;
- prior returns over 20, 60, and 120 sessions;
- qualifying streak length, relative volume, and distance to the 60-session
  high;
- SPY SMA200 and 60-session momentum context; and
- checkpoint state and return remaining after sessions one through four.

Rank terciles are computed separately for `ORIGINAL_22`, `ATLAS_02`, and
`COMBINED` panels. This preserves the original 22-asset audit exactly while
allowing each panel's high/middle/low labels to describe its own distribution.
All continuous measures remain available so conclusions do not depend only on
tercile boundaries.

## Primary comparison views

The packet must report three panels separately:

1. `ORIGINAL_22`: the previously frozen discovery results, unchanged;
2. `ATLAS_02`: eligible names from the frozen additional registry; and
3. `COMBINED`: all eligible original and additional assets.

Primary contrasts first calculate within-asset group differences and then give
each paired asset one equal vote. Asset-level bootstrap intervals use 2,000
draws. Pooled trade counts and returns remain descriptive secondary views.

The wide atlas must also report cohort and sector summaries, but neither may be
used to select a winner after inspection.

## Representative tapes

Before individual paths are inspected, freeze six Atlas 02 tape archetypes:

1. pooled medoid primary-return trade;
2. highest primary-return trade;
3. lowest primary-return trade;
4. medoid trade while SPY is above SMA200;
5. medoid trade while SPY is below SMA200; and
6. medoid high-gap/high-body trade.

These are behavioral examples, not nominees or frequency estimates.

## Evidence boundary

This remains `DISCOVERY_REUSED_WINDOW` because 2021-2023 has already been
inspected repeatedly. Greater breadth can reveal whether a finding is broad or
concentrated, but it cannot turn the known window into independent validation.

The run may not:

- alter the parent strategy or Diagnostic Atlas 01 definitions;
- replace coverage failures;
- choose a winning stock, cohort, sector, grid cell, or filter;
- combine favorable conditions into a mined strategy;
- form a portfolio or infer allocation weights;
- query 2024+ data; or
- claim validation, deployability, or live authority.
