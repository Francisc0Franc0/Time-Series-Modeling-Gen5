# LIT-MOM-03.4 Defensible Deployment-Cohort Contract

Status: `FROZEN_BEFORE_POST_2020_OUTCOME_INSPECTION`

## Question

Does the relative-ranking clue from LIT-MOM-03.3 survive when the stock fleet is
defined by information that was public before the evaluation window rather than
by stocks known to retain long histories through 2026?

## Universe authority

The cohort is the previously audited SPDR S&P 500 ETF Trust Form N-PORT for
holdings dated `2020-09-30`, SEC accession `0001752724-20-236128`, accepted
`2020-11-18 20:32:42 America/New_York`.

The source filing contained 505 equities. The existing deployment-universe
audit resolved 502 identities using the filing plus a contemporaneous roster
and retained 481 identities with exact Alpaca adjusted-daily coverage from
`2016-01-04` through `2020-12-31`. That coverage filter uses only information
available before this study begins. The frozen registry MD5 is
`40e1f4b3b731410aed1e0249cfc92195`.

This is a fixed deployment-date cohort. It is not a claim of rolling historical
S&P 500 membership.

## Causal window

- Universe and prehistory freeze: `2020-12-31`.
- First eligible decision: completed Wednesday close on or after `2021-01-06`.
- Last requested signal date: `2026-03-25`.
- Execution: next SPY trading-session open.
- Market data: Alpaca adjusted daily OHLCV only.

No post-2020 observation may define membership, sector, the top-N rule, signal
horizons, or a gate threshold.

## Unchanged signal mechanics

- Relative ranking horizons: 10-week and 25-week simple close-to-close return.
- Weekly decision target: Wednesday close, with the existing same-week
  Monday-Wednesday holiday fallback.
- Selection fraction: one third of the causally scoreable cohort in each sleeve,
  rounded down. The opening breadth is therefore `floor(481 / 3) = 160`.
- Allocation: 50% per sleeve, equal-weight slots, overlap permitted.
- Absolute gate: selected names with non-positive sleeve return go to cash.
- Tie break: descending return, then ascending symbol.
- Costs: 5 basis points per one-way traded notional.
- Controls: equal-weight eligible cohort, relative-only, absolute-only, SPY,
  and cash/no trade.

No horizon, breadth, cost, filter, or universe search is authorized.

## Causal availability and terminal events

A source-cohort identity is scoreable on a decision date only when its current,
10-week-lag, and 25-week-lag adjusted closes are all present. Missing histories
are never replaced by current constituents or successful survivors.

If a selected identity has no next-session open, the attempted allocation
remains in cash. If a held identity lacks the next rebalance open, its last
observable adjusted close between the two rebalance dates is used as a visible
terminal-value proxy. Every such event and affected target weight must be
reported. The study stops before economic interpretation if terminal proxies
exceed 5% of aggregate one-way held notional.

## Data-admission gates

All gates are conjunctive:

1. the exact 481-row registry and MD5 match;
2. all 11 contemporaneous sectors are present;
3. the universe source and prehistory freeze precede the evaluation window;
4. SPY supplies a complete trading calendar and open/close observations;
5. at least 95% of the frozen cohort is scoreable on the first decision;
6. median weekly scoreable breadth is at least 90% of 481;
7. minimum weekly scoreable breadth is at least 80% of 481;
8. each weekly sleeve selects exactly `floor(scoreable / 3)` identities;
9. terminal-proxy held notional is no more than 5%; and
10. no inference, parameter search, leverage, or live authority is opened.

If a cache warning reflects incomplete requested coverage, refresh the affected
Alpaca range before evaluating these gates. A genuine post-2020 disappearance
remains in the evidence and is not a refresh failure after that attempt.

## Interpretation boundary

This slice is a chronological, ex-ante-universe replay and a substantial repair
of static survivor selection. It is still one source cohort and one later market
period. A favorable point estimate would nominate robustness work; it would not
establish a deployable edge. An unfavorable result stops or redirects this
particular stock-fleet translation without contradicting momentum as a broader
phenomenon.
