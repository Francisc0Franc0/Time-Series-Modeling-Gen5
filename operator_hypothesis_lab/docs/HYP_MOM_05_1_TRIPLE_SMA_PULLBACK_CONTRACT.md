# HYP-MOM-05.1 Ordered Triple-SMA Pullback/Reclaim Contract

Status: `FROZEN_WIDE_DISCOVERY`

Evidence stage: `DISCOVERY_REUSED_WINDOW`

## Question

What happens when a stock enters only after its 15-, 30-, and 45-session
simple moving averages become bullishly ordered, exits after price loses the
30-session average, and may re-enter when price reclaims that medium anchor
while the ordered trend remains intact?

The three averages are not independent evidence. They are differently smoothed
views of the same price history. Their ordering measures recent trend shape and
persistence; the price/SMA30 rule controls participation within that state.

## Frozen signal

For completed session `t`:

`F(t) = SMA15(Close,t)`

`M(t) = SMA30(Close,t)`

`S(t) = SMA45(Close,t)`

`ORDERED(t) = F(t) > M(t) > S(t)`

Every asset begins in cash. Initial entry requires a fresh transition from not
ordered to ordered, with `Close(t) > M(t)`. Buy at `Open(t+1)`.

While long, the first `Close(t) <= M(t)` exits at `Open(t+1)`. Equality is
outside the long state. Loss of average ordering alone does not exit.

After a completed strategy exit, re-entry requires a fresh cross from
`Close(t-1) <= M(t-1)` to `Close(t) > M(t)`, while `ORDERED(t)` remains true.
Re-enter at `Open(t+1)`. A medium reclaim before the first completed exit is
not an initial entry substitute. Any open position is liquidated at the final
discovery open.

Adjusted daily bars and completed-close signals are authoritative. No same-
close fill or in-window warm start is allowed.

## Evidence boundary and universe

- discovery: 2021-01-04 through 2023-12-29;
- 2024-01-02 onward remains excluded;
- explicit as-of timestamp: `2026-08-07 17:30:00 America/New_York`;
- frozen 122-name combined stock registry used by HYP-MOM-02;
- 11 sectors and the original, diversified-core, and 2020 retail-attention
  cohorts remain visible;
- at least 60 valid prior sessions establish the three averages;
- exact SPY-session discovery coverage is required; and
- failed identities remain failed and are not replaced.

The 2021-2023 window has already been inspected in other operator-lab studies.
This is wide discovery and mechanism education, not fresh replication.

## Costs and leverage

Evaluate each asset independently from wealth 1.0 at `1.0x` and `1.8x` gross
entry exposure. Positions are long-only and fixed quantity until exit; they
are not daily reset.

At 1.8x, each entry borrows 0.8 times then-current equity. Debt compounds once
per open-to-open interval. Entry and exit friction apply to gross notional.
Idle unlevered equity earns zero.

| View | One-way trading cost | Annual borrowing rate |
|---|---:|---:|
| Gross diagnostic | 0 bp | 0% |
| Primary | 5 bp | 6% |
| Stress | 10 bp | 10% |

Report minimum equity, maximum effective leverage, sessions below a 30%
maintenance-equity proxy, and nonpositive-equity events. Do not implement a
broker-specific forced liquidation rule. Any maintenance breach makes the
uninterrupted path practically impaired and must remain visible.

No portfolio aggregation, allocation, shorting, taxes, live advice, or
execution behavior is opened.

## Frozen controls

1. `CASH`: zero return and zero risk.
2. `BUY_HOLD`: enter at the first discovery open and exit at the final open.
3. `SMA30_ONLY`: fresh in-window price cross above SMA30 enters; cross at or
   below exits; starts cash.
4. `ORDERED_STACK`: fresh in-window transition into `SMA15>SMA30>SMA45`
   enters; loss of ordering exits; starts cash.
5. `CIRCULAR_SHIFT`: 500 deterministic circular shifts of H05.1's exact
   open-to-open long/cash exposure state for each asset and leverage level.

Every direct baseline uses the same leverage, primary costs, financing, and
boundary. Thus H05.1 versus SMA30 isolates the ordering permission; H05.1
versus ordered-stack ownership isolates the price/SMA30 pullback mechanism;
and 1.8x H05.1 versus 1.8x buy-and-hold avoids crediting leverage itself as
timing skill. Circular shifts are matched timing diagnostics, not a formal
null model.

## Required readout

Report bar- and trade-level wealth, return, CAGR, Sharpe, maximum drawdown,
time underwater, exposure, turnover, hit rate, payoff asymmetry, holding time,
activation versus reclaim entries, annual/sector/cohort breadth, cost and
financing sensitivity, direct-baseline differences, circular-shift percentile,
maintenance risk, and representative success, failure, whipsaw, long-trend,
leverage-helped, and leverage-hurt tapes.

No SMA length, leverage, cost, financing rate, entry, exit, re-entry, universe,
subset, or baseline may be selected after outcomes. Any later refinement needs
a separately frozen variant and distinct evidence decision.
