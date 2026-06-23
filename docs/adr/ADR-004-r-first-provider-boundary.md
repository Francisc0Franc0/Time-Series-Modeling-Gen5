# ADR-004: R-First With Provider Boundary

## Status

Accepted.

## Context

The existing research logic and statistical workflow are R-native. Rewriting everything in Python would add migration risk before Gen5 contracts are stable. At the same time, provider-specific quirks should not leak into research modules.

## Decision

Gen5 is R-first. Alpaca is the only v0 provider, but it must live behind a provider-shaped boundary.

For Gen5 v0, the provider boundary is deliberately small:

- Alpaca credentials, base URL, data feed selection, request parameters, pagination, response parsing, and provider error messages stay in `R/alpaca_provider.R`.
- The provider module emits canonical adjusted daily OHLCV bars with the Gen5 data-contract columns.
- Downstream data-layer helpers consume canonical bars, cache plans, merge summaries, symbol coverage, and audit artifacts, not Alpaca response shapes.
- Research modules introduced after v0 should treat `provider == "alpaca"` as provenance, not as permission to depend on Alpaca-specific quirks.
- Gen5 v0 does not introduce a second provider or a broad provider abstraction before the Alpaca adjusted daily contract is stable.

## Consequences

- Research and WFA code stay close to the user's existing statistical workflow.
- Python can later consume shared artifacts if useful.
- Alpaca-specific behavior remains isolated.
- Provider changes can be tested at the boundary without asking later modules to understand Alpaca URL, feed, adjustment, pagination, or authentication details.
