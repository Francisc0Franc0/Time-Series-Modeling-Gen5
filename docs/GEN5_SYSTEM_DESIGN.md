# Gen5 System Design

## Mission

Gen5 is a clean rebuild of the WFA trading research and advice-only execution system. It should preserve the modular scientific discipline of Gen4 while reducing redundant artifacts, hidden state, plotting bloat, and late-phase ambiguity.

## Objective Language

Gen5 targets a long-only, rolling walk-forward, regime-conditioned tactical equity/ETF system seeking aggressive capital growth from volatile but structurally tradeable assets, with explicit controls for drawdown, concentration, leverage value-add, and out-of-sample robustness.

## Current Decisions

These are architectural decisions and desired capability areas, not a claim that downstream modules are production-ready. The current Gen5.1 base is the completed v0/v0.1 market-data layer, research workbench, diagnostic strategy proofs, a multi-signal single-asset WFA POC, and an independent multi-asset WFA batch report wrapper.

- Core language: R-first.
- Provider: Alpaca only for v0.
- Bars: adjusted daily OHLCV only.
- Trading posture: long-only.
- Live posture: advice-only.
- Signal timing: after-close analysis for next-open manual market orders.
- Current strategy/WFA POC: a small Gen4-inspired candidate set can compete inside each TRAIN fold, with stitched OOS reporting. Current candidates are `ema_cross`, `ema_trend`, `bollinger_touch`, `bollinger_mid_reversion`, `rsi_mr`, `zret_mr`, `breakout`, and `pullback_in_uptrend`; SMA variants are deferred.
- Current trade-policy POC: close-based exit stacks composed with entry/native signal model instances into complete `strategy_spec_id` candidates.
- Possible state benchmark: asset-specific PCA, added only if and when the operator opens that slice.
- Max default simultaneous positions: 5, with future tests at 1, 2, 3, 5, 8, and 10.
- Leverage reports: always compare 1.0x baseline with 1.8x leveraged variant.
- Drawdown discomfort threshold: 25% is a major design warning level.
- Local heavy cache: ignored repo-local `data_cache/` is acceptable for v0.1 simplicity; outside-OneDrive cache roots remain an optional operator optimization.
- Research handoff: future WFA or research code should consume workbench handoff artifacts and must not call Alpaca directly unless the operator explicitly opens a provider/data-layer change.

## Semantic Modules

1. `market_data`: provider access, session resolution, adjusted daily bars, local cache, data audits.
2. `features`: deterministic feature construction from canonical bars.
3. `asset_taxonomy`: later causal universe screens and optional behavior grouping.
4. `state_model`: asset-specific PCA first, with simpler baselines and other models later.
5. `strategy_lab`: entry and native-exit event generation, currently proven with a small Gen4-inspired candidate set. `bollinger_touch` and `bollinger_mid_reversion` are kept as separate families because their native exits differ.
6. `trade_policy`: composes entry/native event streams with close-based exit stacks into complete `strategy_spec_id` candidates and trade ledgers.
7. `walk_forward`: rolling train/OOS fold engine and frozen selection authority over complete model or strategy specs.
8. `capital_allocator`: future portfolio construction, position sizing, exposure management, and allocation-policy simulation over WFA trade ledgers.
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

The v0.1 Research Data Workbench adds a handoff manifest and gate checklist for later WFA consumers. That handoff is still market-data-only: canonical bars, manifest, health rows, audit, symbol coverage, refresh plan, and universe metadata. It reserves cash/no-position and buy-and-hold as later baseline concepts without implementing returns, folds, strategy evaluation, or allocation.

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

## Flexible Capability Map

The data layer and research workbench are complete enough to serve as the base. Everything after that is a capability backlog, not a rigid build order:

- Better data inspection reports.
- Feature engine.
- Asset universe/taxonomy studies.
- Walk-forward evaluation methodology.
- Strategy vertical slices with explicit cash/no-position and buy-and-hold baselines.
- PCA or other state/regime models.
- Trade-scoped exit policy layer.
- Allocation and concentration controls.
- Leverage comparison reports.
- Frozen decision packs.
- Advice-only dashboard/live runner.

The operator may choose the next slice organically. Codex should translate that direction into scoped, validated increments with tangible outputs rather than forcing the entire capability map into a predetermined sequence.

## Current Prototype Path

Gen5.1 currently has a multi-signal single-asset WFA POC with close-based exit-stack composition, plus a multi-asset batch runner that executes that POC independently per symbol and aggregates reports only. An entry/native model instance plus an exit stack becomes a `strategy_spec_id`, and WFA ranks complete specs rather than only entry models. The current broadened candidate set is intentionally modest and excludes SMA until the operator opens that slice. Portfolio construction should follow once per-asset WFA trade ledgers carry stable exit attribution. State/regime filters remain deferred until trade generation and portfolio accounting surfaces are stable.
