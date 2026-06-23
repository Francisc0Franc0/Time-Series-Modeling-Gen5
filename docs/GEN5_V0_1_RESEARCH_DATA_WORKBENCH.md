# Gen5 v0.1 Research Data Workbench

## Context

This milestone follows the Gen5 v0 market-data-layer closeout. Gen5 v0 proved the adjusted daily Alpaca bar contract, explicit as-of timestamp handling, deterministic cache behavior, and audit outputs. Gen5 v0.1 should make that data layer easier to query, inspect, and hand off to later research without implementing WFA, strategy, allocation, dashboard, execution, or live-order logic.

The visible operator behavior should be simple:

- choose a small basket of symbols and date range;
- refresh or read adjusted daily bars through the existing data layer;
- review data health with severity levels;
- render a basic static candlestick PNG for one symbol/date range;
- produce a clear research-readiness handoff artifact for later milestones.

## Scope

Gen5 v0.1 is a research-plumbing milestone, not a modeling milestone.

In scope:

- reuse the existing ignored `data_cache/` folder for local adjusted daily bar caches;
- provide a front-facing operator path for small basket/date-range research queries;
- define manual universe roles and a first proof-of-concept universe;
- improve data-health reporting around missing, stale, partial, duplicate, empty, and future-clipped data;
- add a separate chart-oriented validation/inspection path for static candlestick PNGs;
- define the canonical research input contract that future WFA code will consume;
- add an opt-in Alpaca credential/preflight path;
- add a research gate checklist before the first WFA milestone begins.

Out of scope:

- WFA fold construction;
- PCA/state modeling;
- strategy signals or event generation;
- exits, trade policies, or allocation;
- dashboards;
- execution or order routing;
- live-order automation;
- provider expansion beyond Alpaca;
- corporate-actions ingestion unless separately authorized after the core workbench is stable.

## Decisions

### Cache

Use the existing gitignored `data_cache/` folder as the default working cache for now. It already contains the current adjusted daily cache layout:

```text
data_cache/alpaca_daily_adjusted/alpaca/1D/
```

Outside-OneDrive cache roots remain an optional future operator optimization, but v0.1 should prioritize a simpler local path and clear instructions.

### Universe Roles

Start with manually curated universes. Rule-built universes can come later, but the interface should not care whether a universe was manual or rule-generated.

Use four roles:

- `candidate_universe`: broad list eligible for review or future rules.
- `research_universe`: tighter set used by early research plumbing and later transforms.
- `context_universe`: benchmark or reference symbols that help interpretation but do not automatically enter every transform.
- `live_basket`: later advice-facing basket, usually around `N = 5`; not implemented in v0.1.

Keep inverse ETFs, leveraged ETFs, short exposure, crypto, options, and futures out of the v0.1 equity/ETF universe.

### First Manual POC Universe

Use a tight volatile growth core plus separate benchmarks/context. This avoids making the future research set too scattered while still giving the operator enough context.

Research core candidates:

- `NVDA`
- `AMD`
- `TSLA`
- `PLTR`
- `META`
- `COIN`
- `SMCI`
- `MSTR`

Context/benchmark candidates:

- `SPY`
- `QQQ`
- `SMH`
- `XLK`

Final symbol selection can be adjusted during the universe-registry task. The important rule is to keep research symbols and context symbols labeled separately.

The first source-controlled registry scaffold lives at `config/universe_registry.csv`. It uses explicit rows for `candidate_universe`, `research_universe`, and `context_universe`; `live_basket` is an allowed later label but has no selected symbols in this foundation chunk.

### Baselines

Future research should compare active decisions against at least:

- cash/no-position;
- buy-and-hold.

Gen5 v0.1 should only reserve these as downstream research contract concepts. It should not implement strategy evaluation.

### Session Resolution

All query, refresh, validation, and chart paths must consume a shared latest-complete-session helper driven by explicit `as_of_timestamp`. No analytical or inspection path should call `Sys.Date()` or independently infer the latest session.

### Charting

The first chart deliverable should be a static candlestick PNG for one symbol/date range. It should live in a separate validation/inspection script so the core refresh/query path stays boring and fast.

### Corporate Actions And Earnings

Alpaca has a corporate-actions endpoint for events such as splits, dividends, mergers, spin-offs, name changes, and reorganizations. Alpaca warns that those actions may not be available immediately after announcement. See: https://docs.alpaca.markets/reference/corporateactions-1

No structured Alpaca earnings calendar or earnings-surprise endpoint is planned for v0.1. Alpaca news can be queried by symbol/date, but news articles are not a clean earnings-beat data source. See: https://docs.alpaca.markets/us/reference/news-3

Corporate-actions metadata is eligible for later Gen5 data-layer scope only as an explicitly authorized Alpaca sidecar. It should not be mixed into the canonical adjusted daily bar table, used to recompute adjusted OHLCV, or treated as a research signal in v0.1.

If later authorized, corporate-actions caching should preserve the provider boundary:

- use explicit `as_of_timestamp`, `start`, and `end` inputs rather than endpoint defaults;
- store corporate-actions snapshots separately from adjusted daily bars under an ignored cache path;
- keep provider request shape, pagination, type names, CUSIP handling, and response quirks inside the Alpaca provider module;
- include enough cache metadata to replay or audit the request scope, including provider, endpoint version, region, symbols or CUSIPs, requested action types, process-date range, query timestamp, row counts, pagination evidence, and a deterministic content hash;
- expose only a documented sidecar artifact or manifest link to future research consumers after a separate scope decision.

The main risks are lookahead leakage from late-arriving or restated events, accidental double-adjustment of already adjusted bars, symbol identity drift around name changes and reorganizations, extra cache invalidation complexity, and quietly turning event metadata into labels or signals before WFA authority exists.

## Research Input Contract

Future WFA code should not call Alpaca directly. It should consume a canonical query result and manifest produced by the data layer/workbench.

The current canonical bar columns are:

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

The manifest should record:

- script or wrapper used;
- explicit `as_of_timestamp`;
- requested start/end dates;
- bounded provider start/end dates;
- universe name and role filters;
- symbols requested;
- symbols returned;
- missing/empty/partial/stale/duplicate status;
- cache root;
- provider/feed;
- git SHA when available;
- generated artifact paths.

## Health Report Shape

The workbench should produce console output plus a durable CSV or Markdown report. Recommended severity levels:

- `ERROR`: unsafe to use for research handoff, such as duplicate symbol-session rows, impossible dates, missing required columns, or future data.
- `WARN`: usable only with explicit operator awareness, such as stale cache, partial history, empty symbol response, clipped future requested end date, or missing optional context symbols.
- `INFO`: normal audit facts, such as cache hits, row counts, bounded dates, and chart paths.

The report should answer:

- which symbols were requested;
- which symbols have data;
- which symbols are stale, empty, partial, duplicated, or missing;
- whether the requested end was clipped to the latest completed session;
- whether the data came from cache or provider refresh;
- where the artifacts were written.

The foundation implementation writes query health rows as CSV with:

- `severity`
- `category`
- `symbol`
- `detail`

`ERROR` rows remain reserved for hard contract failures such as duplicate symbol/session rows, missing required bar columns, or future rows. `WARN` rows cover clipped requested end dates, stale/partial/empty/missing symbols, cache misses, and refresh-needed symbols. `INFO` rows record row counts, cache hits, and per-symbol coverage facts.

## Operator Commands To Plan

The exact script names can be adjusted during implementation, but v0.1 should converge on clear wrapper behavior:

- `refresh`: credentialed Alpaca update into `data_cache/`.
- `validate`: non-network data/cache health checks.
- `query`: small basket/date-range canonical data pull.
- `chart`: static candlestick PNG for one symbol/date range.
- `credentials`: opt-in Alpaca credential/preflight check.

Default validation should remain non-network. Credentialed checks should be explicit.

Implemented foundation query command:

```powershell
$env:GEN5_AS_OF_TIMESTAMP="2026-06-23 17:30:00"
$env:GEN5_WORKBENCH_START_DATE="2026-02-23"
$env:GEN5_WORKBENCH_END_DATE="2026-06-23"
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' scripts/query_research_data.R
```

Implemented static candlestick inspection command:

```powershell
$env:GEN5_AS_OF_TIMESTAMP="2026-06-23 17:30:00"
$env:GEN5_CHART_SYMBOL="NVDA"
$env:GEN5_CHART_START_DATE="2026-02-23"
$env:GEN5_CHART_END_DATE="2026-06-23"
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' scripts/inspect/render_candlestick_png.R
```

The chart path queries one symbol through the existing workbench cache/provider helpers, writes companion query artifacts under ignored `runs/research_workbench/`, and renders a base-R PNG from canonical adjusted daily OHLC bars. `GEN5_CHART_REFRESH` defaults to `false`; set it to `true` only for an explicit credentialed refresh before plotting.

Implemented opt-in credential preflight command:

```powershell
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' scripts/preflight_alpaca_credentials.R
```

The preflight checks credential presence, rejects placeholder-like values, checks live-fetch runtime packages by default, and prints only non-secret PASS/FAIL/SKIP rows. It does not make a network request. Set `GEN5_ALPACA_PREFLIGHT_REQUIRE_RUNTIME=false` only when checking credential presence without checking optional runtime packages.

## Research Handoff Gate

The handoff contract for future research consumers is defined in `docs/GEN5_V0_1_RESEARCH_HANDOFF_CHECKLIST.md`.

Future WFA code must consume the workbench bars, manifest, health, audit, symbol coverage, refresh plan, and source-controlled universe registry. It must not call Alpaca directly, infer the latest session, or require credentials as part of default research validation.

The handoff gate reserves cash/no-position and buy-and-hold as later baseline concepts only. It does not implement returns, benchmark performance, WFA folds, strategy evaluation, allocation, dashboard behavior, execution, or live orders.

The first minimal WFA contract planning record lives in `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md`. It defines the next milestone boundary without adding WFA code or downstream research behavior to v0.1.

## Acceptance Criteria

Gen5 v0.1 is ready to hand off to the first research milestone when:

- the operator can run a documented small-basket query without touching low-level provider code;
- query output uses canonical adjusted daily bars and an explicit manifest;
- universe roles are documented and represented in source-controlled config or data files;
- `data_cache/` remains ignored and is the documented working cache;
- data-health reports use severity levels and identify stale, missing, partial, empty, duplicate, and clipped-future conditions;
- one static candlestick PNG can be generated from pulled/cached bars without adding charting to the core pipeline;
- Alpaca credential presence can be checked explicitly without making default tests depend on the network;
- future WFA code has a documented no-Alpaca-direct-call contract;
- cash/no-position and buy-and-hold are documented as later research baselines;
- the research gate checklist confirms no WFA, strategy, allocation, dashboard, execution, or live-order logic has been added.
