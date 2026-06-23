# Gen5 v0 Data-Layer Freeze Evidence

## Scope

This note documents the market-data-layer freeze evidence from the bounded live Alpaca refresh smoke. It covers adjusted daily OHLCV ingestion, local cache planning/merge behavior, audit output, symbol coverage, and local validation status only.

It does not add or validate WFA, strategy, state modeling, allocation, dashboard, execution, or live-order logic.

## Evidence Artifacts

The bounded live Alpaca smoke evidence is recorded in ignored local run artifacts under `runs/data_refresh/`. These CSVs are generated audit artifacts, not source files.

The date suffixes identify the inspected refresh snapshots used for the freeze note. Operators should regenerate these artifacts through the data refresh and validation scripts rather than editing the CSVs by hand.

For repeatable comparisons, regenerate evidence with explicit `GEN5_AS_OF_TIMESTAMP`, `GEN5_FETCH_START_DATE`, and `GEN5_FETCH_END_DATE` values. Generated CSVs stay ignored; source-controlled documentation should record only the interpretation needed for closeout.

Latest covered-range snapshot:

- `runs/data_refresh/alpaca_daily_audit_20260622.csv`
- `runs/data_refresh/alpaca_daily_refresh_plan_20260622.csv`
- `runs/data_refresh/alpaca_daily_merge_summary_20260622.csv`
- `runs/data_refresh/alpaca_daily_symbol_coverage_20260622.csv`

Follow-up stale-tail snapshot:

- `runs/data_refresh/alpaca_daily_audit_20260623.csv`
- `runs/data_refresh/alpaca_daily_refresh_plan_20260623.csv`
- `runs/data_refresh/alpaca_daily_merge_summary_20260623.csv`
- `runs/data_refresh/alpaca_daily_symbol_coverage_20260623.csv`

Local non-network validation evidence is recorded under `runs/validation/`, especially:

- `runs/validation/data_layer_validation_results.csv`
- `runs/validation/data_layer_validation_audit.csv`
- `runs/validation/data_layer_validation_refresh_plan.csv`
- `runs/validation/data_layer_validation_merge_summary.csv`
- `runs/validation/data_layer_validation_symbol_coverage.csv`

## Explicit Timestamp And Bounds

The latest `20260622` freeze snapshot carries an explicit provider query timestamp:

- `provider_query_timestamp`: `2026-06-23 12:54:35`
- `requested_start_date`: `2026-02-23`
- `requested_end_date`: `2026-06-22`
- `latest_completed_session`: `2026-06-22`
- `observed_start_date`: `2026-02-23`
- `observed_end_date`: `2026-06-22`

The follow-up stale-tail snapshot carries a later explicit provider query timestamp:

- `provider_query_timestamp`: `2026-06-23 17:30:00`
- `requested_start_date`: `2026-02-23`
- `requested_end_date`: `2026-06-23`
- `latest_completed_session`: `2026-06-23`
- `observed_start_date`: `2026-02-23`
- `observed_end_date`: `2026-06-22`

The later snapshot is important because it shows the data layer did not silently treat missing June 23 provider bars as complete coverage. It recorded the bounded stale-tail request and surfaced the availability gap.

Operator interpretation:

- The `20260622` snapshot is covered-range evidence: the requested date range matches the observed cached range.
- The `20260623` snapshot is the stale-tail evidence.
- The stale-tail gap is acceptable data-layer evidence because the gap is explicit, symbol-level, and auditable.
- The stale-tail gap is not a trading signal and does not imply strategy, live-advice, or execution readiness.

## Refresh Plan Summary

Latest covered-range snapshot, `alpaca_daily_refresh_plan_20260622.csv`:

- Requested symbols: `SPY`, `QQQ`, `TSLA`, `NVDA`
- Cache path root: `C:/Users/Franc/TradingDataCache/Time-Series-Modeling-Gen5/alpaca/1D/`
- Cache files existed for all four symbols.
- Each symbol had `cached_row_count = 83`.
- Each symbol covered `first_cached_session = 2026-02-23` through `latest_cached_session = 2026-06-22`.
- Each symbol had `needs_fetch = FALSE`.
- Each symbol had `refresh_decision = fully_cached`.
- Fetch start/end dates were `NA`, confirming no provider call was needed for the already covered bounded range.

Follow-up stale-tail snapshot, `alpaca_daily_refresh_plan_20260623.csv`:

- Requested symbols: `SPY`, `QQQ`, `TSLA`, `NVDA`
- Each symbol started with 83 cached rows through `2026-06-22`.
- Each symbol had `needs_fetch = TRUE`.
- Each symbol had `refresh_decision = stale_cache`.
- Each symbol selected the bounded provider fetch range `2026-06-23` to `2026-06-23`.

## Merge Summary

Latest covered-range snapshot, `alpaca_daily_merge_summary_20260622.csv`:

- Each symbol remained at `merged_row_count = 83`.
- Each symbol had `first_merged_session = 2026-02-23`.
- Each symbol had `latest_merged_session = 2026-06-22`.
- Each symbol had `returned_bar_count = 0`.
- Each symbol had `no_returned_bars = FALSE`.
- Each symbol had `wrote_cache = TRUE`.

Follow-up stale-tail snapshot, `alpaca_daily_merge_summary_20260623.csv`:

- Each symbol kept `merged_row_count = 83`.
- Each symbol retained `first_merged_session = 2026-02-23`.
- Each symbol retained `latest_merged_session = 2026-06-22`.
- Each symbol had `returned_bar_count = 0`.
- Each symbol had `no_returned_bars = TRUE`.
- Each symbol had `wrote_cache = TRUE`, preserving deterministic cache write/read behavior while keeping the audit trail explicit.

## Audit Summary

Latest covered-range audit, `alpaca_daily_audit_20260622.csv`:

- `requested_symbol_count = 4`
- `present_symbol_count = 4`
- `missing_symbol_count = 0`
- `row_count = 332`
- `row_counts_by_symbol = SPY=83;QQQ=83;TSLA=83;NVDA=83`
- `duplicate_symbol_session_count = 0`
- `empty_symbol_count = 0`
- `partial_history_symbol_count = 0`
- `stale_symbol_count = 0`
- `availability_warning_count = 0`
- `refresh_skip_symbol_count = 4`
- `refresh_fetch_ranges_by_symbol = SPY=NA;QQQ=NA;TSLA=NA;NVDA=NA`
- `no_returned_bar_symbol_count = 0`
- `refresh_decisions_by_symbol = SPY=fully_cached;QQQ=fully_cached;TSLA=fully_cached;NVDA=fully_cached`

Follow-up stale-tail audit, `alpaca_daily_audit_20260623.csv`:

- `requested_symbol_count = 4`
- `present_symbol_count = 4`
- `missing_symbol_count = 0`
- `row_count = 332`
- `duplicate_symbol_session_count = 0`
- `empty_symbol_count = 0`
- `partial_history_symbol_count = 4`
- `partial_history_symbols = SPY,QQQ,TSLA,NVDA`
- `stale_symbol_count = 4`
- `stale_symbols = SPY,QQQ,TSLA,NVDA`
- `refresh_fetch_symbol_count = 4`
- `refresh_fetch_ranges_by_symbol = SPY=2026-06-23:2026-06-23;QQQ=2026-06-23:2026-06-23;TSLA=2026-06-23:2026-06-23;NVDA=2026-06-23:2026-06-23`
- `no_returned_bar_symbol_count = 4`
- `no_returned_bar_symbols = SPY,QQQ,TSLA,NVDA`
- `availability_warnings = partial_history_symbols=SPY,QQQ,TSLA,NVDA;no_returned_bars=SPY,QQQ,TSLA,NVDA`

This is acceptable freeze evidence for the data layer because the stale-tail gap is explicit, bounded, and auditable. It is not evidence of strategy readiness or live-trading readiness.

## Symbol Coverage Results

Latest covered-range coverage, `alpaca_daily_symbol_coverage_20260622.csv`:

- Symbols covered: `SPY`, `QQQ`, `TSLA`, `NVDA`
- Per-symbol `row_count`: 83
- Per-symbol `empty_status`: `has_rows`
- Per-symbol `partial_history_status`: `covers_requested_range`
- Per-symbol `stale_status`: `current`
- Per-symbol observed range: `2026-02-23` through `2026-06-22`
- Per-symbol bounded requested range: `2026-02-23` through `2026-06-22`

Follow-up stale-tail coverage, `alpaca_daily_symbol_coverage_20260623.csv`:

- Symbols covered: `SPY`, `QQQ`, `TSLA`, `NVDA`
- Per-symbol `row_count`: 83
- Per-symbol `empty_status`: `has_rows`
- Per-symbol `partial_history_status`: `partial_history`
- Per-symbol `stale_status`: `stale`
- Per-symbol observed range: `2026-02-23` through `2026-06-22`
- Per-symbol bounded requested range: `2026-02-23` through `2026-06-23`

The coverage artifacts show that all requested symbols are represented and that the June 23 gap is reported at symbol granularity.

## Terminology Reference

The freeze evidence uses the same literal artifact labels as the validation and refresh scripts:

- `fully_cached`: requested bounded range is already covered by cache.
- `stale_cache`: cache starts early enough but ends before the requested bounded end.
- `partial_history`: cache reaches the requested bounded end but starts after the requested start.
- `partial_history_stale`: cache misses both the requested start and bounded end.
- `cold_cache`: no symbol cache file exists.
- `cold_cache_empty_file`: a symbol cache file exists but contains no rows.
- `no_returned_bars`: a symbol needed a fetch but the provider payload supplied no bars for that symbol/range.
- `covers_requested_range`: observed bars cover the bounded requested range in symbol coverage output.
- `stale`: observed bars exist but end before `latest_completed_session`.

## Local Validation Status

The local validation artifact `runs/validation/data_layer_validation_results.csv` reports PASS for:

- example-plus-local config loading
- explicit latest completed session resolution from `as_of_timestamp`
- explicit requested date range clipping by latest completed session
- bounded Alpaca adjusted daily request construction
- rejection of unbounded future end dates
- mapping provider payloads to canonical adjusted daily OHLCV bars
- explicit incremental cache planning
- deterministic incremental cache merge behavior
- audit availability, cache refresh decisions, and provider query timestamp fields
- empty provider payload reporting
- duplicate symbol/session detection
- validation artifact writing under `runs/validation`
- refresh artifact writing under `runs/validation`
- symbol coverage artifact writing under `runs/validation`

The same validation artifact reports `SKIP` for `live Alpaca fetch smoke` because the validation script is intentionally non-network. This SKIP is not a hidden PASS for Alpaca connectivity; it means the credentialed live fetch path was not exercised by validation. The operator must run the data refresh script separately for the live network smoke.

For routine local validation, run the repository wrapper from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1
```

For a live Alpaca smoke refresh, run `scripts/run_data_refresh.R` with explicit credentials in the local environment and, when needed, explicit `GEN5_FETCH_START_DATE` and `GEN5_FETCH_END_DATE` bounds. Live refresh artifacts remain generated local evidence under ignored output folders.

The closeout checklist and non-network coverage map are maintained in `docs/GEN5_V0_DATA_LAYER_CLOSEOUT_CHECKLIST.md`.

## Freeze Interpretation

Gen5 v0 market-data-layer behavior is documented as frozen for the current contract:

- Alpaca-only provider boundary.
- Adjusted daily OHLCV as the canonical bar type.
- Explicit `as_of_timestamp` and bounded requested date windows.
- Session resolution and provider query timestamp retained in audit output.
- Local symbol cache planning is deterministic and auditable.
- Cache merge behavior is keyed by `symbol` and `session_date`.
- Missing or delayed provider bars are surfaced as symbol-level availability warnings, not silently accepted as complete data.
- Heavy caches and generated run artifacts remain outside source control.

This freeze does not authorize downstream analytical modules. WFA, strategy, allocation, dashboard, and execution work remain out of scope until they are introduced through later milestones.
