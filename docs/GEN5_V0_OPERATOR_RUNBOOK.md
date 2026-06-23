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

6. Use the ignored repo-local `data_cache/alpaca_daily_adjusted/` folder as the simple default cache for v0.1 workbench runs. Keep heavy data caches outside OneDrive only when practical by overriding `cache.root` in `config/data_layer.local.yml` or by setting `GEN5_CACHE_ROOT` for one run.

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

Relative cache roots are resolved under the repository root, so `data_cache/alpaca_daily_adjusted` maps to the ignored repo-local cache folder.

## Validation Order

Run the local non-network validation wrapper before any credentialed refresh:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1
```

This wrapper runs the scaffold smoke test, data-layer validation script, and non-network `testthat` suite. Interpret `PASS` as local data-layer contract coverage only. A `SKIP` for the live Alpaca fetch smoke is expected here; it means the validation script did not make a network call, even if credentials and runtime packages are present.

When credentials are configured, run the opt-in no-network credential preflight before a live refresh:

```powershell
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' scripts/preflight_alpaca_credentials.R
```

The preflight loads ignored `.Renviron` values, checks credential presence, rejects placeholder-like values, checks the live-fetch runtime packages by default, and prints only non-secret PASS/FAIL/SKIP rows. It does not store credentials, print credential values, or contact Alpaca. Set `GEN5_ALPACA_PREFLIGHT_REQUIRE_RUNTIME=false` only when inspecting credential presence without checking optional runtime packages.

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

## v0.1 Workbench Query

For a non-network small-basket/date-range query from the existing cache:

```powershell
$env:GEN5_AS_OF_TIMESTAMP="2026-06-23 17:30:00"
$env:GEN5_WORKBENCH_START_DATE="2026-02-23"
$env:GEN5_WORKBENCH_END_DATE="2026-06-23"
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' scripts/query_research_data.R
```

The default universe is `gen5_v0_1_poc_growth` with `research_universe` rows from `config/universe_registry.csv`. Override with `GEN5_WORKBENCH_SYMBOLS`, `GEN5_WORKBENCH_UNIVERSE`, or `GEN5_WORKBENCH_ROLES`. Set `GEN5_WORKBENCH_REFRESH=true` only for an intentional credentialed Alpaca refresh.

Workbench artifacts are written under ignored `runs/research_workbench/`: bars, manifest, audit, symbol coverage, refresh plan, and severity-labeled health CSVs.

The future research handoff manifest and gate checklist live in `docs/GEN5_V0_1_RESEARCH_HANDOFF_CHECKLIST.md`. Future WFA consumers must read the workbench handoff artifacts and must not call Alpaca directly.

For closeout gates and the current non-network invariant coverage map, see `docs/GEN5_V0_DATA_LAYER_CLOSEOUT_CHECKLIST.md`.
