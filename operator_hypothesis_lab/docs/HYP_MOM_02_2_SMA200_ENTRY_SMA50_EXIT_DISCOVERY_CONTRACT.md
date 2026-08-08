# HYP-MOM-02.2 SMA200 Entry / SMA50 Exit Discovery Contract

Status: `FROZEN_WIDE_DISCOVERY`

## Question

What happens when a stock must demonstrate a fresh, qualified cross above its
200-session simple moving average before entry, but a faster 50-session average
governs exit?

The hypothesis is deliberately asymmetric. The slow average demands evidence
of a major upward transition. The faster average then asks whether trend
deterioration can be recognized earlier than a return below SMA200.

This is not a golden-cross strategy. Price is compared with each average;
SMA50 is not compared with SMA200.

## Nomenclature and lineage

Register `HYP-MOM-02.2`, **Fresh SMA200 Entry / SMA50 Exit**. The change from
`02.1` is substantive because it changes exit timing and re-entry opportunity.

The `HYP-MOM-02` investigation retains two valuable `02.1` estimands:

- state ownership: causally warm-start long when already above SMA200;
- authoritative event ownership: start cash and require a fresh in-window
  SMA200 cross.

`02.2` uses the authoritative fresh-cross entry as its control and changes only
the confirmation and exit/re-entry state machine described below.

## Frozen rule

For asset `i` after completed session `t`:

`SMA200(i,t) = mean(Close(i,t-199), ..., Close(i,t))`

`SMA50(i,t) = mean(Close(i,t-49), ..., Close(i,t))`

A qualified entry signal requires both:

1. `Close(t-1) <= SMA200(t-1)` and `Close(t) > SMA200(t)`;
2. `Close(t) > SMA50(t)`.

The strategy buys at `Open(t+1)`. A cross above SMA200 that finishes at or
below SMA50 is recorded as a skipped signal and does not create a position.

While long, the first completed close satisfying `Close(t) <= SMA50(t)` creates
an exit at `Open(t+1)`. Equality is treated as outside the long state.

After an SMA50 exit, recovery above SMA50 does not re-enter. The asset remains
in cash until a new qualified cross above SMA200 occurs. This strict lockout is
part of the hypothesis, not an implementation accident.

Adjusted daily bars are authoritative. Both averages include the completed
signal close. No same-close fills are allowed.

## Boundary initialization

At least 220 pre-discovery sessions establish both moving averages. Every asset
starts the discovery path in cash, even if already above one or both averages.
Only an entry signal completed on or after January 4, 2021 is admissible.

An asset with no qualified entry remains in the eligible panel with zero
trades, return, drawdown, and exposure. Any position still open at the final
discovery open is liquidated there and labeled `BOUNDARY_EXIT`.

## Evidence boundary and universe

- stage: `DISCOVERY_REUSED_WINDOW`;
- discovery: January 4, 2021 through December 29, 2023;
- confirmation: January 2, 2024 and later remains excluded;
- explicit as-of timestamp: `2026-08-07 17:30:00 America/New_York`;
- source identities: the frozen 22-name Operator Hypothesis Lab registry plus
  the previously frozen 100-name breadth-attention registry;
- registered breadth: 122 unique stocks across 11 sectors;
- no failed identity is replaced.

Eligibility requires every SPY discovery session, at least 220 earlier valid
adjusted daily bars, no duplicates, and positive finite OHLC with finite
nonnegative volume.

## Costs and accounting

- primary: 5 bp per side;
- stress: 10 bp per side;
- initial wealth: 1.0 per independently evaluated asset;
- proceeds are reinvested in the same asset path;
- idle cash earns zero;
- long-only, full-capital single-asset accounting;
- no portfolio aggregation, leverage, shorting, taxes, live advice, or
  execution behavior is opened.

## Frozen comparisons

Compare `02.2` with the authoritative cross-only `02.1` path on the same asset
and window. Retain the earlier state-ownership `02.1` headline only as a clearly
labeled alternative estimand; do not use it as the primary causal comparator.

Report the existing return, cost, exposure, Sharpe, drawdown, trade, and 500
circular-shift diagnostics, plus:

- qualified and skipped SMA200 entry counts;
- SMA50 exit count and strict-lockout sessions;
- per-asset changes in return, drawdown, exposure, trade count, and holding
  duration versus cross-only `02.1`;
- matched-entry exit timing: sessions exited earlier and the return from the
  `02.2` exit open to the corresponding `02.1` exit open;
- saved-downside exits, where the later `02.1` exit price was lower;
- foregone-upside exits, where the later `02.1` exit price was higher;
- paired representative tapes selected mechanically by median return change,
  largest improvement, largest deterioration, largest drawdown improvement,
  largest exposure reduction, and most lockout sessions.

Matched-exit labels are retrospective diagnostics, not tradeable foresight.

## Interpretation gates

This discovery can show whether the faster exit changes the return/protection
tradeoff. It cannot establish that SMA50 is optimal, because the reused window
was already inspected and only one operator-proposed exit length is admitted.

Do not tune the 50-session or 200-session lengths, add buffers, select favorable
assets or sectors, allow SMA50-recovery re-entry, add stops, form a portfolio,
or inspect 2024+ after seeing this packet. Any such mechanics change requires a
new frozen decimal variant and separately declared evidence boundary.
