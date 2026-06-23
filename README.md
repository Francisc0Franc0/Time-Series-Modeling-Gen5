# Time-Series-Modeling-Gen5

Gen5 is a clean R-first rebuild of the WFA trading research and advice-only execution system.

The first milestone is intentionally narrow: a daily adjusted Alpaca market-data layer with explicit date resolution, reproducible cache behavior, and auditable data-quality outputs. Strategy research, PCA state modeling, WFA, exits, allocation, and live dashboards will sit on top only after the data contract is stable.

## Gen5 v0 Scope

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

From this repository root:

```r
source("tests/smoke_test.R")
```

Or from a shell with R installed:

```powershell
Rscript tests/smoke_test.R
```

## Alpaca Data Refresh Smoke

The data scripts load `config/data_layer.example.yml` first, then overlay ignored local settings from `config/data_layer.local.yml` when present. Use the local file for paths and symbols, not secrets. The live Alpaca refresh path expects `httr` and `jsonlite` plus Alpaca credentials named `ALPACA_KEY` and `ALPACA_SECRET`. The scripts quietly load ignored local `.Renviron` values before calling Alpaca.

```powershell
Rscript scripts/run_data_refresh.R
```

The script fetches adjusted daily bars for the configured symbols, writes ignored local cache files, reads them back, and writes an ignored audit CSV under `runs/`.

The refresh path is incremental and deterministic. For each requested symbol it first inspects the local symbol cache, then records one refresh decision:

- `cold_cache`: no symbol cache exists, so the requested bounded range is fetched.
- `fully_cached`: the requested bounded range is already covered, so no provider request is made.
- `stale_cache`: cached history starts early enough but ends before the requested bounded end date.
- `partial_history`: cached history reaches the requested bounded end date but starts after the requested start date.
- `partial_history_stale`: cached history misses both the requested start and bounded end.
- `cold_cache_empty_file`: a cache file exists but contains no rows, so it is treated as a cold cache.

Fetched rows are merged with existing symbol caches using `symbol` plus `session_date` as the deterministic key, with fetched rows taking precedence on overlap. Merged cache files are sorted by `symbol` and `session_date`.

Each refresh also writes two ignored inspection artifacts under `runs/data_refresh/`:

- `alpaca_daily_refresh_plan_YYYYMMDD.csv`: the pre-fetch plan by symbol. Use this to see whether each symbol was fully cached, needed a cold fetch, needed a stale tail fetch, or had partial history.
- `alpaca_daily_merge_summary_YYYYMMDD.csv`: the post-fetch cache merge result by symbol. Use this to see how many bars came back, how many rows ended up in the cache, whether a cache file was written, and whether a symbol needed a fetch but returned no bars.
- `alpaca_daily_symbol_coverage_YYYYMMDD.csv`: the per-symbol cache coverage view after the refresh. Use this to scan requested dates, observed first/latest sessions, row counts, empty status, partial-history status, and stale status in one row per requested symbol.

These CSVs are generated artifacts, not source files. They are intentionally covered by the ignored `runs/` folder.

## Data-Layer Validation

Run the operator-facing validation script without Alpaca credentials:

```powershell
Rscript scripts/validate/validate_data_layer.R
```

It prints minimal PASS/FAIL/SKIP checks for config loading, explicit session resolution, adjusted daily request construction, cache write/read behavior, requested versus missing symbols, stale symbols, duplicate rows, row counts, cache hits, and provider query timestamp audit fields. Validation outputs are written under the ignored `runs/validation/` folder, separate from future experiment artifacts.

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
Rscript scripts/run_data_refresh.R
```

Cache and audit outputs remain under ignored local cache paths and `runs/`.

## Design Principle

No downstream analytical module should decide what "latest" means. The data layer resolves sessions, records the as-of timestamp, and exports the audit trail.
