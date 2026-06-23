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

## Data-Layer Validation

Run the operator-facing validation script without Alpaca credentials:

```powershell
Rscript scripts/validate/validate_data_layer.R
```

It prints minimal PASS/FAIL/SKIP checks for config loading, explicit session resolution, adjusted daily request construction, cache write/read behavior, requested versus missing symbols, stale symbols, duplicate rows, row counts, cache hits, and provider query timestamp audit fields. Validation outputs are written under the ignored `runs/validation/` folder, separate from future experiment artifacts.

## Design Principle

No downstream analytical module should decide what "latest" means. The data layer resolves sessions, records the as-of timestamp, and exports the audit trail.
