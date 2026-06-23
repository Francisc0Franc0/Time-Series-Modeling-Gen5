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

## Design Principle

No downstream analytical module should decide what "latest" means. The data layer resolves sessions, records the as-of timestamp, and exports the audit trail.
