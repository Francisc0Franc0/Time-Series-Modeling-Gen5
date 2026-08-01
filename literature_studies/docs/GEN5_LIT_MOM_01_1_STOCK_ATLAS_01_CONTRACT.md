# LIT-MOM-01.1 Stock Atlas 01 Contract

Status: `OOS_DEVELOPMENT_COMPLETE_STOP_RECOMMENDED`

## Place in the literature-study progression

`LIT-MOM-01.1 / STOCK_ATLAS_01` is a breadth replication of the already
completed Chapter 6 interday time-series-momentum exercise. It is not a new
strategy variant and does not change the canonical `250/25` reference or the
frozen per-instrument mechanics.

The visible objective is to learn whether the source-inspired horizon screen
and causal sleeve strategy recur across a balanced panel of individual U.S.
stocks. The atlas does not select a live winner, form a multi-stock portfolio,
change provider scope, or open allocation, leverage, advice, or execution.

## Frozen registry

The registry contains 22 large, liquid U.S. stocks: exactly two from each of
the eleven broad equity sectors. Within each sector, the two names were chosen
to provide different subindustry or economic-cycle exposure where practical.

Selection used only sector coverage, economic diversity, liquidity, public
history, and practical Alpaca symbol continuity. It did not use momentum
outcomes. The order is immutable:

`literature_studies/registries/gen5_lit_mom_01_1_stock_atlas_01_registry.csv`

This is a static July 2026 survivor panel. It cannot measure an investable
point-in-time historical universe and must not be presented as free of
survivorship or membership bias.

## Per-stock mechanics

Every stock independently reuses the exact `LIT-MOM-01.1` contract except for
the explicitly authorized symbol substitution:

- adjusted daily bars only;
- warm-up from January 4, 2016;
- TRAIN from January 3, 2017 through December 31, 2020;
- DEVELOPMENT from January 4, 2021 through December 29, 2023;
- 2024+ CONFIRMATION sealed and not queried;
- the 49-cell `L,H in {1,5,10,25,60,120,250}` horizon table;
- selected holding period of at least five sessions;
- at least 20 Chan-min-step screening pairs;
- TRAIN selection by maximum Pearson t-statistic, with the frozen tie breaks;
- selected correlation above zero and nominal `p <= 0.10`;
- one causal `1/H` sleeve entered next open each session and held for `H`
  opens;
- aggregate exposure bounded to `[-1,+1]`;
- 5 bp primary one-way turnover costs;
- 10 bp stress one-way turnover costs plus 100 bp annual short borrow; and
- the same six conjunctive TRAIN gates.

The `250/25` canonical reference is calculated for every stock but cannot
replace its frozen selected row after outcomes.

## Batch interpretation

The unit of evidence is one stock, not one optimized atlas winner.

- Every stock is reported, including coverage failures and STOPs.
- DEVELOPMENT is queried only for stocks that pass all six TRAIN gates.
- Every TRAIN passer receives its one frozen DEVELOPMENT replay; no OOS winner
  is selected.
- OOS correlation, direction accuracy, primary return, stress return, Sharpe,
  and drawdown are reported as descriptive continuity evidence. No new OOS
  gate is invented after inspection.
- Aggregate counts and sector summaries describe breadth. They are not a
  multi-stock portfolio, capital allocation, or multiplicity-adjusted proof.
- The atlas is not rescued by removing weak stocks, changing sector balance,
  selecting a common horizon after results, or choosing the best OOS name.

## Required evidence

The authoritative packet must contain:

- the frozen registry and coverage audit;
- one selected horizon and six-gate row per stock;
- per-stock TRAIN direction and performance summaries;
- the canonical `250/25` comparison per stock;
- OOS summaries and bar paths for every authorized stock;
- horizon-selection frequency, gate matrix, TRAIN evidence, and TRAIN-to-OOS
  continuity visuals; and
- a concise deck with source and decision references in speaker notes.

## STOP boundary

Completing this atlas does not authorize a new horizon, a pooled stock model,
an equal-weight portfolio, stock selection, allocation, or live shorting.
Those require separate theory and operator approval after this finite breadth
readout is documented.
