# Gen5 L1 Long-Short Sector-Reversal POC Contract

Status: `FROZEN_APPROVED_FOR_IMPLEMENTATION`

## Decision authority

The operator approved this exact literature-grounded direction in the
conversation that followed the literature inventory:

- prior Gen5.4 designs are evidence, not architectural baggage;
- the mean-reversion strategy may short;
- the strategy must remain simple and formulaic;
- statistical properties must be tested on an earlier subset before portfolio
  performance is admitted; and
- prediction of up versus down must be measured separately from PnL.

This contract opens L1 historical research, statistical testing, conditional
portfolio replay, human-facing visuals, and a concise evidence deck. It does
not open live short advice, automated execution, leverage, or production use.

## Frozen question

Among nine long-history U.S. sector ETFs, do the two weakest trailing
five-session performers subsequently outperform the two strongest performers
over the next five sessions often, broadly, and strongly enough to survive
ordinary execution costs and justify a prospective borrow-feasibility
discussion?

## Claim boundary

L1 tests **cross-sectional reversal**:

> recent relative losers outperform recent relative winners at one fixed
> five-session horizon.

It does not claim:

- that individual ETF prices are stationary;
- that the ETFs are cointegrated;
- that a rejection of a random walk proves tradability;
- that historical short legs were borrowable;
- that absolute up/down prediction is required for relative-spread profit; or
- that a historical PASS authorizes live advice or execution.

## Frozen universe

Strategy ETFs:

`XLB,XLE,XLF,XLI,XLK,XLP,XLU,XLV,XLY`

Context-only benchmark:

`SPY`

The nine ETFs are a fixed survivor panel. Their long common history and
liquidity make them a practical retail POC universe, but the packet must not
claim a point-in-time universe-selection process or constituent-level
survivorship freedom.

## Data and time authority

- Provider: Alpaca only.
- Bars: adjusted daily OHLCV only.
- Feed: repository research default, recorded in the run manifest.
- Query start: `2016-01-04`.
- Query end: `2026-07-24`.
- Explicit `as_of_timestamp`: `2026-07-24 17:30:00 America/New_York`.
- No analytical helper may call `Sys.Date()`.
- Every required symbol must contain every reference session through the
  query end before L1 evidence is accepted.

## Frozen chronological partitions

Partitions use only cohorts whose entry and exit both fall inside the named
interval:

| Partition | Calendar interval | Authority |
|---|---|---|
| TRAIN | `2016-01-04` through `2020-12-31` | Statistical mechanism gate only |
| DEVELOPMENT | `2021-01-01` through `2023-12-31` | Replication after TRAIN passes |
| CONFIRMATION | `2024-01-01` through `2026-07-24` | Frozen confirmation and conditional portfolio replay |

Each partition has its own five-session cadence anchored to its first available
reference session. Boundary-crossing cohorts are excluded.

## Frozen signal and execution rule

For ETF \(i\) on decision session \(t\):

\[
L_{i,t} = \frac{Close_{i,t}}{Close_{i,t-5}} - 1
\]

1. Rank the nine \(L_{i,t}\) values from lowest to highest.
2. Long the two lowest-ranked ETFs.
3. Short the two highest-ranked ETFs.
4. Allocate `+0.25` to each long and `-0.25` to each short.
5. Gross exposure is `1.00`; net dollar exposure is `0.00`.
6. The signal is known only after the decision close.
7. Enter at the following session's open.
8. Exit at the open five sessions after entry.
9. Start the next cohort at that same open; return intervals do not overlap.

Ties are broken alphabetically by symbol. No volatility scaling, beta
neutralization, stop-loss, profit target, averaging, trend filter, regime
filter, parameter search, or leverage is permitted.

## Primary mechanism estimands

For each cohort:

\[
IC_t = SpearmanCorr(L_{i,t}, R^{future}_{i,t})
\]

Mean reversion expects `mean(IC) < 0`.

\[
Spread_t =
mean(R^{future}_{bottom2,t}) -
mean(R^{future}_{top2,t})
\]

Mean reversion expects `mean(Spread) > 0`.

The primary net spread subtracts the frozen round-trip implementation cost.

## Frozen costs and short assumptions

Primary:

- `5 bp` one way on total gross notional at entry;
- `5 bp` one way on total gross notional at exit;
- zero historical borrow fee, explicitly labeled an ETB-style approximation.

Stress:

- `10 bp` one way at entry and exit; and
- `100 bp` annualized borrow cost applied to the `0.50` short gross exposure
  for five sessions.

Short-sale proceeds do not increase gross exposure or create free investment
capital. Short dividends, historical locates, recalls, and point-in-time borrow
status cannot be reconstructed from adjusted OHLCV; this limitation remains
explicit.

## TRAIN-first statistical protocol

Only TRAIN cohorts may decide whether later outcomes are opened.

- Moving-block bootstrap:
  - `2,000` replicates;
  - block length `4` cohorts;
  - seed `5701`;
  - percentile `95%` confidence intervals.
- Random long-short control:
  - choose two random longs and two disjoint random shorts per cohort;
  - `2,000` seeded policies;
  - seed `5702`;
  - compare the observed mean net spread with random-policy p90.
- Calendar-year stability is calculated from cohort-equal net spreads.
- ETF concentration is reported by arithmetic long/short contribution.

### L1A mechanism gates

All gates must pass:

1. All data, timing, partition, and non-overlap integrity checks pass.
2. TRAIN mean rank IC is negative and its bootstrap upper 95% bound is below
   zero.
3. TRAIN mean primary-cost net spread is positive and its bootstrap lower 95%
   bound is above zero.
4. TRAIN spread-direction hit rate is greater than `50%`.
5. TRAIN observed mean net spread exceeds the seeded random-policy p90.
6. At least `3 / 5` TRAIN calendar years have positive mean net spread.

If any L1A gate fails, return `STOP_L1A_SECTOR_REVERSAL_MECHANISM`. DEVELOPMENT,
CONFIRMATION, portfolio replay, Sharpe, drawdown, trade PnL, and performance
claims are structurally not run.

## Conditional L1B replication and performance

L1B runs only if every L1A gate passes.

### Replication gates

1. DEVELOPMENT mean rank IC is negative and mean primary-cost net spread is
   positive.
2. CONFIRMATION mean rank IC is negative and mean primary-cost net spread is
   positive.
3. CONFIRMATION observed mean net spread exceeds its seeded random-policy p90.
4. At least `2 / 3` represented CONFIRMATION calendar years have positive mean
   net spread.
5. CONFIRMATION mean spread remains positive under stress costs.

### Portfolio gate

The CONFIRMATION portfolio must have:

- positive cumulative net return;
- positive autocorrelation-adjusted annualized Sharpe; and
- no single ETF supplying more than `35%` of positive arithmetic
  contribution.

If every L1A and L1B gate passes, return
`PASS_L1_TO_PROSPECTIVE_BORROW_SHADOW_DISCUSSION`. Otherwise return
`STOP_L1B_SECTOR_REVERSAL_REPLICATION`.

## Directional-prediction scorecard

Directional prediction is diagnostic, not a gate, because L1's primary claim
is relative.

Report separately:

- spread-direction accuracy: `long basket return > short basket return`;
- long-call precision: selected long has positive future return;
- short-call precision: selected short has negative future return;
- combined raw direction accuracy;
- balanced accuracy from up and down recall;
- a full predicted-up/predicted-down confusion matrix;
- Wilson 95% intervals;
- prediction coverage; and
- a cost-aware three-state label: up beyond friction, down beyond friction, or
  economically neutral.

An outcome can validate relative prediction while missing absolute direction.
The report and deck must show this distinction explicitly.

## Conditional portfolio and trade/bar reporting

If L1B is admitted, report:

### Cohort and leg level

- count;
- mean and median net return;
- win rate;
- average win and average loss;
- payoff ratio;
- profit factor;
- expectancy;
- best and worst cohort;
- long and short contribution separately; and
- representative best, median, and worst cohort tapes.

The cohort is the primary trade unit. Four ETF legs from one cohort are not
four independent experiments.

### Daily bar level

- daily net open-to-open return;
- wealth;
- total PnL per initial research dollar;
- CAGR;
- annualized volatility;
- naive annualized Sharpe;
- Newey-West-style autocorrelation-adjusted Sharpe;
- maximum drawdown;
- maximum drawdown duration;
- time under water;
- gross and net exposure;
- turnover; and
- primary-versus-stress cost comparison.

Cash/no-trade is the primary economic competitor. SPY is contextual only
because its directional market exposure is not comparable with L1's
dollar-neutral book.

## Required human-facing artifacts

- frozen contract and run manifest;
- data-health and session-coverage audit;
- TRAIN statistical summary and bootstrap/random controls;
- rank-IC and net-spread stability chart;
- directional confusion/accuracy chart;
- representative cohort tapes;
- conditional equity/drawdown and trade/bar tables if L1B runs;
- concise Markdown report; and
- concise PowerPoint with a `[Sources]` block in every slide's speaker notes.

## Prohibited rescue paths

After TRAIN inspection, do not:

- change the five-session lookback or holding period;
- change two longs/two shorts;
- add or delete ETFs;
- optimize the cadence anchor;
- replace dollar neutrality with fitted beta neutrality;
- change costs, bootstrap settings, random seed, percentile, or gates;
- add a trend, volatility, macro, or regime filter;
- reinterpret absolute directional accuracy as the primary spread claim; or
- inspect later outcomes after an L1A STOP.

Any successor must be a newly named, newly sourced hypothesis with a new
contract.
