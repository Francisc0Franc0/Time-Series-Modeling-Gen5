# Gen5 v0 Operator Runbook

## Scope

This runbook covers the Gen5 v0 market-data layer only: Alpaca adjusted daily OHLCV ingestion, deterministic local cache behavior, validation artifacts, and audit review. It does not cover WFA, strategy research, allocation, dashboards, execution, or live orders.

## Local Setup

1. Confirm R is available at the expected Windows path or pass an override to the test wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1
```

2. Keep repo-local R packages under ignored `.codex_r_libs/` when local package installs are needed. The validation and refresh entry points add that directory to `.libPaths()` automatically when it exists.

3. Copy `config/data_layer.example.yml` to ignored `config/data_layer.local.yml` only when local settings need to override the example.

4. Use `config/data_layer.local.yml` for operator-local paths, feed selection, and symbols. Do not put Alpaca credentials in YAML.

5. Set Alpaca credentials through environment variables or ignored `.Renviron`:

```text
ALPACA_KEY=your_key_here
ALPACA_SECRET=your_secret_here
```

6. Keep heavy data caches outside OneDrive when practical by setting `cache.root` in `config/data_layer.local.yml` or by setting `GEN5_CACHE_ROOT` for one run.

The repository does not migrate or delete existing cache files. Cache root changes only affect subsequent reads/writes for that run or local config.

## Configuration Rules

The v0 config must remain Alpaca-only, adjusted daily, and `1D`:

```yaml
provider: alpaca
timeframe: 1D
adjusted: true
```

The loader reads `config/data_layer.example.yml` first, then overlays ignored `config/data_layer.local.yml` if present. Environment variables can override cache root, market calendar fields, Alpaca feed, and symbols for one run:

- `GEN5_CACHE_ROOT`
- `GEN5_MARKET_TIMEZONE`
- `GEN5_MARKET_CLOSE_TIME`
- `ALPACA_DATA_FEED`
- `GEN5_SYMBOLS`

## Validation Order

Run the local non-network validation wrapper before any credentialed refresh:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1
```

This wrapper runs the scaffold smoke test, data-layer validation script, and non-network `testthat` suite. Interpret `PASS` as local data-layer contract coverage only. A `SKIP` for the live Alpaca fetch smoke is expected here; it means the validation script did not make a network call, even if credentials and runtime packages are present.

When credentials and runtime packages are available, run a live Alpaca adjusted daily smoke with explicit bounds:

```powershell
$env:GEN5_AS_OF_TIMESTAMP="2026-06-23 17:30:00"
$env:GEN5_FETCH_START_DATE="2026-02-23"
$env:GEN5_FETCH_END_DATE="2026-06-23"
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' scripts/run_data_refresh.R
```

The refresh script resolves the latest completed session from the explicit or runtime `as_of_timestamp`, clips provider requests to completed sessions, writes ignored cache files, and writes audit artifacts under `runs/data_refresh/`.

## Artifact Review

Review generated CSVs rather than editing them:

- `runs/validation/data_layer_validation_results.csv`
- `runs/validation/data_layer_validation_audit.csv`
- `runs/validation/data_layer_validation_refresh_plan.csv`
- `runs/validation/data_layer_validation_merge_summary.csv`
- `runs/validation/data_layer_validation_symbol_coverage.csv`
- `runs/data_refresh/alpaca_daily_audit_YYYYMMDD.csv`
- `runs/data_refresh/alpaca_daily_refresh_plan_YYYYMMDD.csv`
- `runs/data_refresh/alpaca_daily_merge_summary_YYYYMMDD.csv`
- `runs/data_refresh/alpaca_daily_symbol_coverage_YYYYMMDD.csv`

Generated caches, validation output, refresh output, local config overlays, credentials, and repo-local package libraries are ignored by git.

For closeout gates and the current non-network invariant coverage map, see `docs/GEN5_V0_DATA_LAYER_CLOSEOUT_CHECKLIST.md`.
