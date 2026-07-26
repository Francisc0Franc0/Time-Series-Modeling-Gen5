# Gen5.4 Options Implied-Move O0/O1 Contract

## Purpose

This contract freezes a minimal options-data proof before any model, trading
policy, or options strategy is considered. The research question is whether
retail-accessible Alpaca history can support a reproducible, asset-specific
forward-risk measurement that is distinct from another transformation of
OHLCV.

The primitive is not called sentiment. An at-the-money straddle price combines
forward volatility expectations, jump/event risk, supply and demand, risk
premia, and market microstructure. It may be useful without identifying those
components separately.

## Authority Readout

Status: `STOP_O0_RECONSTRUCTION`

The account capability probe established:

- paper-host contract retrieval passed;
- `5,456` active immutable definitions were admitted across the frozen expiry
  range;
- the feed-selectable snapshot probe returned HTTP `403` for `opra` and HTTP
  `200` for `indicative`;
- the historical-bars endpoint accepted the account-default feed but rejected
  an explicit `feed` query parameter;
- the paper contract endpoint returned no expired contract definitions for the
  historical probe.

To avoid fabricating a historical contract catalog, the authority run narrowed
O0 before outcome inspection to the five sessions `2026-07-20` through
`2026-07-24`, whose selected expiries remained active at retrieval. Raw
underlying 15:45 bars and matched contract definitions were complete at
`15 / 15`. Fixed-time option-pair coverage was:

- `SPY`: `5 / 5` (`100%`, pass);
- `QQQ`: `4 / 5` (`80%`, stop);
- `IWM`: `3 / 5` (`60%`, stop).

The missing rows were individual indicative option legs at the frozen 15:45
timestamp, not missing underlying bars or contract-pair definitions. Because
the contract required at least `90%` for every ETF, O0 stops and O1 remains
closed. No outcome was joined and no missing-leg rescue was attempted.

Authority packet:

- `runs/research_workbench/gen54_ml_decision_engine/g54_options_o0_20260726/`
- `presentations/gen5_4_options_implied_move_o0_evidence.pptx`

## O0: Data And Reconstruction Gate

Scope:

- underlyings: `SPY`, `QQQ`, `IWM`;
- decision timestamp: after close, fixed at `17:30 America/New_York`;
- history: no earlier than Alpaca's documented February 2024 options-history
  boundary;
- eligible expiry: closest to 30 calendar days, constrained to `21-45` days to
  expiry;
- strike: closest available strike to the aligned underlying price;
- pair: call and put at the same strike and expiry;
- price: VWAP from the fixed final `15Min` bar ending before the regular-session
  close; close is retained only as a diagnostic;
- feature:

```text
normalized_implied_move_30d =
  (call_vwap + put_vwap) / underlying_price * sqrt(30 / DTE)
```

O0 inspects only provenance, timestamps, pagination, contract matching, feed
identity, missing/stale bars, strike distance, and reproducibility. It does not
join future outcomes.

O0 passes only if:

1. the account can retrieve immutable historical contract definitions and
   historical option bars from an explicitly identified feed;
2. every admitted row uses a same-strike, same-expiry call/put pair;
3. no request or accepted row exceeds the explicit `as_of_timestamp`;
4. valid matched straddles cover at least `90%` of eligible sessions for each
   underlying in the frozen evaluation window;
5. the feed is labeled `opra` or `indicative` in every artifact, with no claim
   that indicative data are official consolidated OPRA history;
6. representative human-facing tapes make missingness, strike selection, and
   the constructed measure visually inspectable.

If O0 fails, stop. Do not loosen the DTE window, mix timestamps, substitute a
one-sided option, interpolate a missing leg, or proceed to outcome analysis.

## O1: Incremental Forward-Risk Ordering

O1 opens only if O0 passes. The question is:

> Does the fixed implied-move proxy order next-open five-session realized path
> volatility beyond information already present in prior five-session realized
> path volatility and same-date VIX?

Frozen methodology:

- target: next-open `h5` realized path volatility, not return direction;
- controls: prior `h5` realized path volatility and same-date VIX;
- transforms: issuer-local empirical CDF fitted on the preceding eight-quarter
  TRAIN window only;
- assessment: quarterly OOS partial Spearman correlation;
- no imputation across missing options sessions;
- no threshold tuning, classifier, return replay, allocation, or PnL.

O1 is promising only if:

1. all temporal and fold leakage checks pass;
2. mean quarterly partial rank correlation is positive;
3. partial rank correlation is positive in at least `4/5` usable assessment
   quarters;
4. the result is not carried by only one ETF;
5. representative tapes show coherent forward-risk ordering rather than a
   single-event artifact.

Otherwise O1 stops as insufficient incremental evidence. A stop does not mean
options contain no information; it means this minimal construction has not
earned more complexity.

## Explicit Exclusions

- put/call volume or open-interest sentiment;
- present-day open interest or close metadata applied historically;
- skew, term structure, gamma exposure, dealer positioning, or reconstructed
  historical Greeks;
- options trading, execution, transaction-cost assumptions, or live advice;
- model fitting, exposure sizing, allocation, return replay, or performance
  claims.

## Provider Notes

Alpaca documents historical options data from February 2024. Its current
historical option-bars reference supports symbol lists, intraday timeframes,
and pagination, but does not list a feed query parameter. Feed identity in this
POC is therefore inferred from the account entitlement probe against the
feed-selectable snapshot endpoint and recorded as `indicative`. Alpaca
distinguishes the official OPRA feed from a free indicative feed, so no OPRA
claim is made.

Primary documentation:

- <https://docs.alpaca.markets/us/docs/historical-option-data>
- <https://docs.alpaca.markets/us/reference/optionbars>
- <https://docs.alpaca.markets/us/reference/get-options-contracts>
- <https://docs.alpaca.markets/us/docs/about-market-data-api>
