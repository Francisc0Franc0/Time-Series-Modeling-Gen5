# Gen5 System Design

## Mission

Gen5 is a clean rebuild of the WFA trading research and advice-only execution system. It should preserve the modular scientific discipline of Gen4 while reducing redundant artifacts, hidden state, plotting bloat, and late-phase ambiguity.

## Objective Language

Gen5 targets a long-only, rolling walk-forward, regime-conditioned tactical equity/ETF system seeking aggressive capital growth from volatile but structurally tradeable assets, with explicit controls for drawdown, concentration, leverage value-add, and out-of-sample robustness.

## Current Decisions

These are architectural decisions and later build-order constraints, not a claim that downstream modules are already implemented. The current v0 implementation target remains the market-data layer.

- Core language: R-first.
- Provider: Alpaca only for v0.
- Bars: adjusted daily OHLCV only.
- Trading posture: long-only.
- Live posture: advice-only.
- Signal timing: after-close analysis for next-open manual market orders.
- Initial strategy vertical slice: `ema_cross` plus `no_trade`.
- Initial state benchmark: asset-specific PCA, added after data layer and minimal WFA are stable.
- Max default simultaneous positions: 5, with future tests at 1, 2, 3, 5, 8, and 10.
- Leverage reports: always compare 1.0x baseline with 1.8x leveraged variant.
- Drawdown discomfort threshold: 25% is a major design warning level.
- Local heavy cache: ignored repo-local `data_cache/` is acceptable for v0.1 simplicity; outside-OneDrive cache roots remain an optional operator optimization.

## Semantic Modules

1. `market_data`: provider access, session resolution, adjusted daily bars, local cache, data audits.
2. `features`: deterministic feature construction from canonical bars.
3. `asset_taxonomy`: later causal universe screens and optional behavior grouping.
4. `state_model`: asset-specific PCA first, with simpler baselines and other models later.
5. `strategy_lab`: strategy event generation, starting with `ema_cross` and `no_trade`.
6. `trade_policy`: native and overlay exit-policy mechanics bound to trade identity.
7. `walk_forward`: rolling train/OOS fold engine and frozen selection authority.
8. `capital_allocator`: portfolio construction tested inside WFA, not only after the fact.
9. `decision_pack`: frozen quarterly or period-specific execution evidence package.
10. `live_advisor`: advice-only dashboard and console output for manual orders.

## Data-Layer Rules

No analytical module should decide what latest means. The data layer alone resolves the latest completed session from an explicit as-of timestamp and records why.

Provider quirks stay inside the provider module. In v0, `R/alpaca_provider.R` owns Alpaca credentials, URL construction, feed selection, adjusted daily request parameters, pagination, response parsing, and provider error interpretation. Everything outside that boundary should consume canonical adjusted daily bars plus cache/audit artifacts.

Every bar bundle should preserve:

- `symbol`
- `session_date`
- `open`
- `high`
- `low`
- `close`
- `volume`
- `adjusted`
- `timeframe`
- `provider`
- `as_of_timestamp`
- `latest_completed_session`
- `fetch_start_date`
- `fetch_end_date`
- `data_version_hash`

Every data refresh should export an audit of requested symbols, resolved session, missing symbols, duplicates, gaps, stale symbols, cache hits, and provider query timestamp.

## What Gen5 Intentionally Does Not Preserve From Gen4

- Massive default plot generation.
- All-candidate artifact dumps.
- Hidden latest-date decisions scattered across phases.
- Intraday/daily branching throughout the core pipeline.
- Strategy declared/enabled/suite/grid registry complexity.
- Post-hoc allocation as the only serious portfolio evaluation layer.
- Fold-local versus stitched artifact ambiguity.
- Pipeline behavior controlled by large global side effects.
- Live runner logic that reinterprets research authority.

## Build Order

- Data layer and cache contract.
- Research Data Workbench: small basket/date-range query, universe registry, severity-labeled data health, static candlestick inspection, and research handoff manifest.
- Minimal WFA engine.
- Asset universe/taxonomy studies.
- Feature engine.
- PCA state model.
- Strategy vertical slice with explicit cash/no-position and buy-and-hold baselines.
- Trade-scoped exit policy layer.
- Allocation inside WFA.
- Frozen decision pack.
- Advice-only dashboard/live runner.
