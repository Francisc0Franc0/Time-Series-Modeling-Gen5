# Time-Series-Modeling-Gen5

Gen5 is a clean R-first rebuild of the WFA trading research and advice-only execution system.

The first milestone is intentionally narrow: a daily adjusted Alpaca market-data layer with explicit date resolution, reproducible cache behavior, and auditable data-quality outputs. Strategy research, PCA state modeling, WFA, exits, allocation, and live dashboards will sit on top only after the data contract is stable.

## Gen5 v0 Scope

This scope records contract constraints and future build direction; the current implementation target is still the market-data layer only.

- Long-only daily trading research and advice-only live signals.
- Alpaca provider only.
- Adjusted daily OHLCV bars only.
- After-close analysis for next-open manual market orders.
- Initial strategy vertical slice later: `ema_cross` plus `no_trade`.
- Initial benchmark state model later: asset-specific PCA.
- Portfolio baseline later: equal-weight top-N with 1.0x and 1.8x leverage reports.

## Current Scaffold

```text
R/                  Base-R data-layer contracts and helpers
scripts/            Runnable smoke/data-refresh entry points
tests/              Lightweight smoke tests plus future testthat tests
docs/               System design and architecture decision records
config/             Example configuration files
```

## First Smoke Test

For normal local validation, prefer the checked-in test runner in the next section. For a narrow scaffold-only smoke check from this repository root:

```r
source("tests/smoke_test.R")
```

Or from PowerShell with the known local R installation:

```powershell
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' tests\smoke_test.R
```

## Local Test Runner

For day-to-day local validation on Windows, use the checked-in test runner:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1
```

The wrapper uses `C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe` when it is available, falling back to `Rscript` on `PATH`. To override the R executable for one run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1 -RscriptPath "C:\Path\To\Rscript.exe"
```

The R runner adds ignored `.codex_r_libs/` to `.libPaths()` when present, then runs the scaffold smoke test, data-layer validation, and non-network testthat tests.

For the full local operator setup sequence, including config overlays, credentials, local cache roots, repo-local R libraries, validation order, and the credentialed Alpaca refresh smoke, see `docs/GEN5_V0_OPERATOR_RUNBOOK.md`.

## Alpaca Data Refresh Smoke

The data scripts load `config/data_layer.example.yml` first, then overlay ignored local settings from `config/data_layer.local.yml` when present. The default cache root is the ignored repo-local `data_cache/alpaca_daily_adjusted/` folder; use the local file or `GEN5_CACHE_ROOT` only when an operator-specific override is needed. Use local config for paths and symbols, not secrets. The live Alpaca refresh path expects `httr` and `jsonlite` plus Alpaca credentials named `ALPACA_KEY` and `ALPACA_SECRET`. The scripts quietly load ignored local `.Renviron` values before calling Alpaca.

Before a credentialed refresh, operators can run an explicit no-network credential readiness preflight:

```powershell
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' scripts/preflight_alpaca_credentials.R
```

The preflight checks credential presence, rejects placeholder-like values, checks live-fetch runtime packages by default, and prints only non-secret PASS/FAIL/SKIP rows. It does not store credentials, print credential values, or contact Alpaca. Set `GEN5_ALPACA_PREFLIGHT_REQUIRE_RUNTIME=false` only when you want to inspect credential presence without checking optional runtime packages.

```powershell
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' scripts/run_data_refresh.R
```

The script fetches adjusted daily bars for the configured symbols, writes ignored local cache files, reads them back, and writes an ignored audit CSV under `runs/`.
When the ignored repo-local `.codex_r_libs/` directory exists, the refresh script adds it to `.libPaths()` before checking runtime packages.

The refresh path is incremental and deterministic. For each requested symbol it first inspects the local symbol cache, then records one refresh decision:

- `cold_cache`: no symbol cache exists, so the requested bounded range is fetched.
- `fully_cached`: the requested bounded range is already covered, so no provider request is made.
- `stale_cache`: cached history starts early enough but ends before the requested bounded end date.
- `partial_history`: cached history reaches the requested bounded end date but starts after the requested start date.
- `partial_history_stale`: cached history misses both the requested start and bounded end.
- `cold_cache_empty_file`: a cache file exists but contains no rows, so it is treated as a cold cache.

Artifact terminology is intentionally literal:

- `refresh_decision` uses `fully_cached`, `stale_cache`, `partial_history`, `partial_history_stale`, `cold_cache`, or `cold_cache_empty_file`.
- `no_returned_bars == TRUE` means a symbol needed a provider fetch but the provider payload supplied no bars for that symbol/range.
- `partial_history_status == "covers_requested_range"` means observed bars cover the bounded requested range.
- `partial_history_status == "partial_history"` means observed bars exist but do not cover the bounded requested range.
- `stale_status == "stale"` means observed bars exist but end before `latest_completed_session`.

Fetched rows are merged with existing symbol caches using `symbol` plus `session_date` as the deterministic key, with fetched rows taking precedence on overlap. Merged cache files are sorted by `symbol` and `session_date`.

Each refresh also writes three ignored inspection artifacts under `runs/data_refresh/`:

- `alpaca_daily_refresh_plan_YYYYMMDD.csv`: the pre-fetch plan by symbol. Use this to see whether each symbol was fully cached, needed a cold fetch, needed a stale tail fetch, or had partial history.
- `alpaca_daily_merge_summary_YYYYMMDD.csv`: the post-fetch cache merge result by symbol. Use this to see how many bars came back, how many rows ended up in the cache, whether a cache file was written, and whether a symbol needed a fetch but returned no bars.
- `alpaca_daily_symbol_coverage_YYYYMMDD.csv`: the per-symbol cache coverage view after the refresh. Use this to scan requested dates, observed first/latest sessions, row counts, empty status, partial-history status, and stale status in one row per requested symbol.

These CSVs are generated artifacts, not source files. They are intentionally covered by the ignored `runs/` folder.

## Data-Layer Validation

Run the full local validation wrapper first:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1
```

To run only the operator-facing validation script without a live Alpaca fetch:

```powershell
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' scripts/validate/validate_data_layer.R
```

It prints minimal PASS/FAIL/SKIP checks for config loading, explicit session resolution, adjusted daily request construction, cache write/read behavior, requested versus missing symbols, stale symbols, duplicate rows, row counts, cache hits, and provider query timestamp audit fields. Validation outputs are written under the ignored `runs/validation/` folder, separate from future experiment artifacts.
When the ignored repo-local `.codex_r_libs/` directory exists, the validation script adds it to `.libPaths()` before checking optional Alpaca runtime packages.

Interpret validation status literally: `PASS` means the local non-network data-layer contract checks passed, `FAIL` means the local data-layer check failed, and `SKIP live Alpaca fetch smoke` means no network fetch was attempted. A skipped live smoke can still appear when credentials and runtime packages are present; the operator must run `scripts/run_data_refresh.R` separately to exercise the credentialed Alpaca path.

Validation also writes deterministic inspection CSVs:

- `runs/validation/data_layer_validation_refresh_plan.csv`
- `runs/validation/data_layer_validation_merge_summary.csv`
- `runs/validation/data_layer_validation_symbol_coverage.csv`
- `runs/validation/data_layer_validation_symbol_coverage.png`

The symbol coverage CSVs are the fastest operator view of cache/data availability by symbol:

- `empty_status == "empty"` means the requested symbol has no observed bars in the inspected cache payload.
- `partial_history_status == "partial_history"` means the symbol has bars, but its observed first/latest sessions do not cover the bounded requested range.
- `stale_status == "stale"` means the symbol has bars, but its latest observed session is before the resolved latest completed session.
- `coverage_end_date` is the requested end clipped to `latest_completed_session`, so a future requested end remains auditable without implying a provider fetch past the completed session.

The validation PNG is a simple data-layer coverage chart. It shows requested date span versus observed cache span by symbol only; it does not show signals, returns, strategies, allocation, or WFA evidence.

The validation output also reports the exact script path and command to rerun. Its audit CSV includes availability/date-range fields:

- requested and observed start/end dates
- first/latest available session by symbol
- empty symbol counts and symbol lists
- partial-history symbol counts and symbol lists
- availability warnings, including requested end dates clipped to the latest completed session

Interpret `empty_symbols` as requested symbols with no returned bars in the audited payload or cache read. Interpret `partial_history_symbols` as symbols that returned bars but did not cover the bounded requested date range. A requested end date after the latest completed session is not fetched directly; the data layer records the requested date, clips the provider request to `latest_completed_session`, and emits an availability warning.

For incremental refresh audits, read:

- `refresh_decisions_by_symbol` for the per-symbol cache decision.
- `refresh_fetch_symbols` and `refresh_skip_symbols` for symbols fetched versus satisfied from cache.
- `refresh_fetch_ranges_by_symbol` for the exact provider date ranges selected by the cache planner.
- `no_returned_bar_symbols` for symbols that needed a fetch but returned no bars.
- `returned_bar_counts_by_symbol` and `merged_row_counts_by_symbol` for provider payload size versus final cache size.

For a live Alpaca smoke refresh, optionally bound the historical range explicitly:

```powershell
$env:GEN5_FETCH_START_DATE="2020-01-01"
$env:GEN5_FETCH_END_DATE="2026-06-23"
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' scripts/run_data_refresh.R
```

Cache and audit outputs remain under ignored local cache paths and `runs/`.

## Research Workbench Query

Gen5 v0.1 adds a research-plumbing query wrapper only. It reads the manual universe registry in `config/universe_registry.csv`, resolves the latest completed session from explicit `GEN5_AS_OF_TIMESTAMP`, reads or optionally refreshes adjusted daily bars through the existing data-layer/cache/provider helpers, and writes ignored query artifacts under `runs/research_workbench/`.

Default use is non-network cache read:

```powershell
$env:GEN5_AS_OF_TIMESTAMP="2026-06-23 17:30:00"
$env:GEN5_WORKBENCH_START_DATE="2026-02-23"
$env:GEN5_WORKBENCH_END_DATE="2026-06-23"
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' scripts/query_research_data.R
```

Set `GEN5_WORKBENCH_SYMBOLS="NVDA,AMD"` for an explicit small basket, or use `GEN5_WORKBENCH_UNIVERSE` and `GEN5_WORKBENCH_ROLES` to select registry labels such as `research_universe` or `context_universe`. Set `GEN5_WORKBENCH_REFRESH=true` only when a credentialed Alpaca refresh is intended.

The query output includes canonical adjusted daily bars, a manifest, audit CSV, symbol coverage CSV, refresh plan CSV, and severity-labeled health CSV with `ERROR`, `WARN`, and `INFO` rows. It does not compute indicators, returns, labels, regimes, strategy signals, WFA folds, allocation, execution, or live-order advice.

The future research handoff contract and gate checklist live in `docs/GEN5_V0_1_RESEARCH_HANDOFF_CHECKLIST.md`. Future WFA code must consume the workbench handoff artifacts rather than calling Alpaca or inferring latest sessions directly.

## Static Candlestick Inspection

The workbench includes a separate static chart script for one-symbol visual inspection of canonical adjusted daily bars. By default it reads cache through the same workbench query/cache helpers and writes a PNG plus companion query artifacts under ignored `runs/research_workbench/`.

```powershell
$env:GEN5_AS_OF_TIMESTAMP="2026-06-23 17:30:00"
$env:GEN5_CHART_SYMBOL="NVDA"
$env:GEN5_CHART_START_DATE="2026-02-23"
$env:GEN5_CHART_END_DATE="2026-06-23"
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' scripts/inspect/render_candlestick_png.R
```

Set `GEN5_CHART_REFRESH=true` only when a credentialed Alpaca refresh is intended before plotting. The PNG is an inspection artifact only; it does not add indicators, returns, labels, regimes, strategy signals, WFA folds, allocation, execution, or live-order advice.

## Symbol Data Proof Packet

Gen5.1 adds a friendlier one-symbol data proof launcher. It wraps the workbench query and static chart helper, then writes a tidy packet under ignored `runs/research_workbench/data_proofs/`.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/inspect/render_symbol_data_proof.ps1 `
  -Symbol AMD `
  -StartDate 2024-01-01 `
  -EndDate 2026-06-23 `
  -AsOfTimestamp "2026-06-23 17:30:00"
```

Use `-Refresh` only when a credentialed Alpaca refresh is intended before rendering:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/inspect/render_symbol_data_proof.ps1 `
  -Symbol AMD `
  -StartDate 2024-01-01 `
  -EndDate 2026-06-23 `
  -AsOfTimestamp "2026-06-23 17:30:00" `
  -Refresh
```

Each packet includes canonical bars, manifest, audit, symbol coverage, refresh plan, health CSV, candlestick PNG, and summary CSV/Markdown outputs. It is an inspection/data-proof workflow only; it does not compute indicators, returns, strategy signals, WFA folds, allocation, execution, live advice, or performance claims.

For repeated inspection, use `-LookbackDays` instead of typing a start date:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/inspect/render_symbol_data_proof.ps1 `
  -Symbol AMD `
  -LookbackDays 500 `
  -EndDate 2026-06-23 `
  -AsOfTimestamp "2026-06-23 17:30:00"
```

## Multi-Symbol Data Report

For a small basket, the multi-symbol report writes one packet under ignored `runs/research_workbench/multi_symbol_reports/`, including a multi-pane candlestick PNG plus the same bars, manifest, audit, coverage, refresh-plan, health, and summary artifacts.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/inspect/render_multi_symbol_report.ps1 `
  -Symbols "NVDA,SPY,QQQ,TSLA" `
  -LookbackDays 120 `
  -EndDate 2026-06-23 `
  -AsOfTimestamp "2026-06-23 17:30:00"
```

Use `-Refresh` only when a credentialed Alpaca refresh is intended before rendering. If a symbol is stale, partial, empty, or missing from cache, the report keeps that visible in the health and coverage outputs. It charts symbols with available canonical bars and fails only when no requested symbol has chartable bars.

The shared chart aesthetic is documented in `docs/GEN5_1_CHART_AESTHETIC.md`. It defines the standard candlestick colors, future trade marker colors/symbols, round-trip connector colors, backgrounds, and multi-pane layout rules.

## Generated Local Files

Generated caches, audit outputs, validation artifacts, local R libraries, local config overlays, and credential files are intentionally kept out of source control. The checked-in ignore rules cover `data_cache/`, `runs/`, `artifacts/`, `logs/`, `.codex_r_libs/`, `config/*.local.yml`, `.Renviron`, `.env`, and heavyweight data file formats such as `*.parquet`, `*.duckdb`, and `*.rds`.

## Gen5 v0 Freeze Evidence

The current market-data-layer freeze evidence is summarized in `docs/GEN5_V0_DATA_LAYER_FREEZE_EVIDENCE.md`. It is an operator audit note for adjusted daily Alpaca ingestion, deterministic cache planning/merge behavior, validation output, and symbol coverage only.

The freeze evidence does not certify strategy, WFA, allocation, dashboard, execution, or live-order readiness. It records that the Gen5 v0 data layer exposes bounded requests, explicit `as_of_timestamp` handling, cache coverage, duplicate detection, stale/partial history warnings, and generated audit artifacts under ignored local output folders.

The v0 closeout checklist and non-network coverage map live in `docs/GEN5_V0_DATA_LAYER_CLOSEOUT_CHECKLIST.md`.

## Gen5.1 Planning

Gen5.1 planning lives in `docs/GEN5_1_VERTICAL_SLICE_PLAN.md` and `docs/GEN5_TASK_QUEUE.md`. The v0/v0.1 data layer and workbench are the completed base; post-data-layer capabilities are now treated as an operator-directed backlog rather than a rigid build order.

Current Gen5.1 work does not implement WFA, PCA/state modeling, strategy logic, exits, allocation, dashboards, execution, live orders, or non-Alpaca providers unless the operator explicitly opens that slice. Future WFA or research code should consume the workbench handoff contract rather than calling Alpaca directly.

## Design Principle

No downstream analytical module should decide what "latest" means. The data layer resolves sessions, records the as-of timestamp, and exports the audit trail.

Alpaca-specific behavior is contained in the provider module. Downstream Gen5 modules should consume canonical adjusted daily bars, cache plans, merge summaries, symbol coverage, and audit artifacts rather than Alpaca response shapes, URL details, authentication details, feed quirks, or pagination behavior.
