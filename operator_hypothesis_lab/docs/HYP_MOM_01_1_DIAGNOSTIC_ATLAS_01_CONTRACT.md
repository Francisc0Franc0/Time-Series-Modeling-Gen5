# HYP-MOM-01.1 Diagnostic Atlas 01 Contract

Status: `FROZEN_BEFORE_CONDITIONAL_OUTCOME_INSPECTION`

Evidence stage: `DISCOVERY_REUSED_WINDOW`

Parent strategy: `HYP-MOM-01.1`

## Question

Which causally observable properties distinguish stronger and weaker outcomes
inside the already inspected two-green-gap-up discovery sample, and which one
narrow question—if any—is coherent enough to justify a separately frozen
`HYP-MOM-01.2` strategy variant?

This atlas explains behavior. It does not change the signal, execution, exit,
costs, position semantics, universe, or dates of `HYP-MOM-01.1`.

## Unchanged parent mechanics

- Two consecutive completed sessions must each open above the prior close and
  close above their own open.
- Observe the signal after the second session closes.
- Enter long at the next adjusted open and exit after five open-to-open
  intervals.
- Use one fixed-quantity, fully invested position per asset; reinvest completed
  proceeds; ignore signals while invested; permit eligible same-open re-entry.
- Charge 5 bp per side in the primary view and 10 bp per side under stress.
- Evaluate 22 stocks independently from 2021-01-04 through 2023-12-29.
- Use Alpaca adjusted daily bars with explicit
  `as_of_timestamp = 2026-07-30 17:30:00 America/New_York`.
- Exclude every observation beginning 2024-01-02.

Only the 821 trades executed by the frozen parent policy are authoritative for
conditional trade summaries. Ignored overlapping signals may be counted for
support diagnostics but may not be substituted into the strategy result.

## Causal feature definitions

Let the second completed pattern session be `t`. Define daily close-to-close
log return as `r[j] = log(C[j] / C[j-1])`.

### 1. Volatility-scaled candle properties

Use a strictly lagged 20-session close-return volatility scale:

```text
sigma1 = sd(r[t-21], ..., r[t-2])  # known before the first pattern candle
sigma2 = sd(r[t-20], ..., r[t-1])  # known before the second pattern candle

gap1_z  = log(O[t-1] / C[t-2]) / sigma1
gap2_z  = log(O[t]   / C[t-1]) / sigma2
body1_z = log(C[t-1] / O[t-1]) / sigma1
body2_z = log(C[t]   / O[t])   / sigma2
```

Primary composites:

```text
gap_strength_z  = gap1_z + gap2_z
body_strength_z = body1_z + body2_z
```

Also retain the minimum of the two standardized gaps and bodies, plus the
second-minus-first total-strength change, so one extreme candle cannot silently
stand in for two strong candles.

For visualization only, assign pooled rank terciles `LOW`, `MID`, and `HIGH`
after all executed discovery trades are assembled. Terciles are sample-defined
descriptive bins, not executable thresholds. Show the full 3 x 3 gap/body grid,
including cell counts.

### 2. Slow-anchor location

At the signal close, compute `SMA200[t]` from closes `t-199` through `t`.
Classify:

- `ESTABLISHED_ABOVE`: `C[t] > SMA200[t]` and the asset was also above its
  corresponding SMA200 20 sessions earlier;
- `RECENT_RECLAIM`: `C[t] > SMA200[t]` but it was not above 20 sessions earlier;
- `BELOW_ANCHOR`: `C[t] <= SMA200[t]`.

Also retain the continuous volatility-scaled distance
`log(C[t] / SMA200[t]) / sigma2` and the simpler above-versus-below split.

### 3. Prior momentum

Compute close-to-close log returns ending at `t` over fixed `L` values of 20,
60, and 120 sessions:

```text
mom_L = log(C[t] / C[t-L])
```

For each horizon, expose the continuous value and the predeclared sign split
`POSITIVE` versus `NONPOSITIVE`. All three horizons remain visible; this atlas
may not select the best one and call it confirmed.

### 4. Pattern maturity

Count the consecutive run of qualifying green gap-up sessions ending at `t`.
Compare `EXACTLY_TWO` with `THREE_OR_MORE`. This asks whether the entry follows
a fresh two-session pattern or an already extended run.

### 5. Participation and price location

- `volume_ratio20 = Volume[t] / median(Volume[t-20], ..., Volume[t-1])`, split
  at the fixed value 1.0.
- Compute the 60-session closing high through `t`, and standardize
  `log(C[t] / High60[t])` by `sigma2`. Group it as `NEAR_HIGH` (at least
  `-1 sigma`), `MID_RANGE` (between `-3` and `-1 sigma`), or `FAR_BELOW_HIGH`
  (below `-3 sigma`).

### 6. Broad-market context

Join SPY only by the signal date. Compute SPY's same causal SMA200 state and
60-session return sign. These are context diagnostics, not market filters.

### 7. Within-trade path

For each executed trade, calculate cumulative gross open-to-open return at
checkpoints 1 through 5 after entry. At checkpoints 1 through 4, split trades
by whether cumulative return is positive and report the remaining gross return
from that checkpoint open to the frozen day-five exit open.

This can reveal early failure, recovery, or giveback. It does not simulate or
select a stop, target, or adaptive exit.

## Predeclared readouts

For every categorical cell report:

- trade count and distinct-asset count;
- mean, median, hit rate, 5th percentile, and 95th percentile of primary-cost
  trade return;
- mean maximum adverse and favorable excursion;
- mean peak-to-exit giveback and trough-to-exit recovery; and
- mean first-session return.

For each primary two-group contrast, first calculate a within-asset difference
for assets represented in both groups, then summarize those paired-asset
differences with:

- paired-asset count;
- mean and median asset contrast;
- fraction of asset contrasts above zero; and
- a 2,000-draw seeded asset bootstrap 95% interval.

The bootstrap is descriptive under a reused window and is not a promotion
p-value. Continuous features receive per-asset Spearman correlations with
primary trade return, summarized across assets; pooled regression significance
is not authoritative.

## Frozen comparison order

The registry order is authoritative:

1. gap strength;
2. candle-body strength;
3. the 3 x 3 gap/body grid;
4. SMA200 state;
5. 20-, 60-, and 120-session return signs;
6. qualifying-run maturity;
7. volume participation;
8. 60-session-high proximity;
9. SPY SMA200 and 60-session return states; and
10. within-trade checkpoint behavior.

All cells and horizons must remain in the packet and deck even when they are
null, inconvenient, or low support.

## Representative tapes

Before conditional outcomes are inspected, select one trade nearest the median
primary return within each slow-anchor state, breaking ties by `trade_id`.
Also select one trade nearest the median return within each joint
`LOW/LOW` and `HIGH/HIGH` gap/body cell when those cells exist. These tapes are
state illustrations, not frequency estimates or best/worst examples.

## Interpretation boundary

This atlas may:

- identify coherent behavioral differences worth discussing;
- reject ideas that show no useful separation or support;
- motivate one narrowly specified `01.2` contract; and
- recommend a later frozen replication on distinct assets or time.

It may not:

- rank cells and promote the winner;
- tune SMA length, volatility lookback, momentum horizon, bin edge, or market
  state after seeing outcomes;
- combine several favorable cells into a mined rule;
- claim independent evidence, alpha, or validation;
- form a portfolio or alter live behavior; or
- query 2024+ data.
