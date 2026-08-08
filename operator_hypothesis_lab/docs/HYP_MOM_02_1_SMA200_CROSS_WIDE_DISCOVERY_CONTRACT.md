# HYP-MOM-02.1 SMA200 Cross Wide Discovery Contract

Status: `FROZEN_WIDE_DISCOVERY`

## Question

What is the consequence of owning a stock after its completed adjusted close
crosses above its 200-session simple moving average, remaining long while the
close stays above that anchor, and returning to cash after a completed close
crosses below it?

This is a classic long-only time-series trend filter. It tests trades initiated
by a newly observed cross above the lagging anchor; it does not claim that
SMA200 independently predicts the next return.

Correction note: the first implementation allowed a warm-start entry when an
asset was already above SMA200 at the discovery boundary. That causal state was
observable, but it answered the broader question of owning whenever above the
anchor. The authoritative `HYP-MOM-02.1` estimand is the operator's narrower
cross-triggered question, so warm-start ownership is excluded rather than
renamed as a new decimal variant.

## Nomenclature

Register `HYP-MOM-02.1`, **SMA200 Cross Long/Cash**. It is a new concept rather
than a revision of the two-green-gap-up hypothesis.

## Frozen rule

For asset `i` after completed session `t`:

`SMA200(i,t) = mean(Close(i,t-199), ..., Close(i,t))`

After the strategy has observed an in-window cross above, the desired position
for the next open is:

`position(i,t+1 open) = 1` until an in-window cross below occurs.

Equivalently:

- cross above: `Close(t-1) <= SMA200(t-1)` and
  `Close(t) > SMA200(t)`; buy at `Open(t+1)`;
- cross below: `Close(t-1) > SMA200(t-1)` and
  `Close(t) <= SMA200(t)`; sell at `Open(t+1)`;
- exact equality is treated as not above;
- exposure is long-only, fully invested within each separately evaluated
  asset, with cash otherwise;
- adjusted daily bars are authoritative; one session means one market bar.

The SMA includes the completed signal close. No same-close fill is permitted.

## Boundary initialization

At least 220 pre-discovery sessions establish the state before January 4,
2021 and make the first in-window cross test well-defined. Every asset begins
the discovery path in cash, even when it is already above SMA200. A trade is
admitted only when a cross above is completed on or after January 4, 2021; the
entry occurs at the following open and is labeled `CROSS_ABOVE`. Being above
the average at the boundary is not itself a signal.

An asset with no in-window cross above remains in the registered and eligible
panel with zero trades, zero strategy return, zero drawdown, and zero exposure.
It is excluded only from statistics that require an executed trade or a
nonzero exposure schedule. This preserves opportunity frequency without
silently conditioning the asset-level result on participation.

Any position still open at the final discovery open is liquidated there, pays
the normal exit cost, and is labeled `BOUNDARY_EXIT`. Signal exits and boundary
exits remain distinguishable in the trade tape.

## Evidence boundary and universe

- stage: `DISCOVERY_REUSED_WINDOW`;
- discovery: January 4, 2021 through December 29, 2023;
- confirmation: January 2, 2024 and later remains excluded;
- explicit as-of timestamp: `2026-08-07 17:30:00 America/New_York`;
- source identities: the 22-name Operator Hypothesis Lab registry plus the
  previously frozen 100-name breadth-attention registry;
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
- no portfolio aggregation, leverage, shorting, dividends outside adjusted
  prices, taxes, borrow, live advice, or execution is opened.

## Frozen evaluation surface

Per asset and across equal-weighted asset summaries, report:

- compounded primary and stress return;
- buy-and-hold return under the same boundary costs;
- excess return versus buy-and-hold;
- exposure fraction and trade count;
- trade mean, median, hit rate, duration, and maximum adverse excursion;
- annualized open-to-open Sharpe with zero cash return;
- maximum drawdown and drawdown improvement versus buy-and-hold;
- fraction of completed trades lasting 20 sessions or fewer, labeled a
  whipsaw diagnostic rather than a strategy gate;
- percentile versus 500 deterministic circular shifts of the same
  cross-triggered binary exposure state; zero-exposure assets have no timing
  percentile because every shift is identical.

The circular-shift control preserves each asset's exposure fraction and the
serial structure of its long/cash state while breaking alignment with the
realized open-to-open returns. It is a matched timing diagnostic, not an
independence claim or a formal p-value.

Representative tapes are selected mechanically after calculation as: median
excess return, highest excess return, lowest excess return, greatest drawdown
improvement, highest trade count, and longest median holding duration. Ties
resolve alphabetically. These are audit archetypes, not candidate assets.

## Interpretation gates

This wide discovery is informative when it reveals the tradeoff among return,
drawdown, exposure, and whipsaw cost. It has no promotion authority because
the dates and much of the universe have already been inspected in other lanes.

Do not select sectors, assets, volatility bands, alternate SMA lengths,
confirmation filters, stops, or cost assumptions after seeing this packet.
Any such mechanics change requires a substantive decimal variant and a new
frozen contract.
