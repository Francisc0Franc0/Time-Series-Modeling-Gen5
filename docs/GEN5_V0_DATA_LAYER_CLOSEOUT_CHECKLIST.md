# Gen5 v0 Data-Layer Closeout Checklist

## Scope

This checklist defines when the Gen5 v0 market-data layer is stable enough to support the next milestone. It covers Alpaca adjusted daily OHLCV ingestion, explicit session/date handling, local cache behavior, audit artifacts, validation, and operator guidance only.

It does not authorize WFA, PCA/state modeling, strategy research, exits, allocation, dashboards, execution, live orders, or decision-pack logic.

## Closeout Gates

Treat the data layer as ready to move on only when all gates below are satisfied:

- Provider scope remains Alpaca-only for v0.
- Canonical bars remain adjusted daily OHLCV only, with `adjusted == TRUE`, `timeframe == "1D"`, and `provider == "alpaca"`.
- Every provider request and artifact path preserves an explicit `as_of_timestamp`; no analytical module independently infers the latest session.
- Requested date ranges are explicit, auditable, and clipped to `latest_completed_session` before provider fetches.
- Cache planning is deterministic and records `refresh_decision`, `needs_fetch`, and fetch ranges by symbol before any provider call.
- Cache merges are deterministic by `symbol` plus `session_date`, with fetched rows taking precedence on overlap.
- Audit artifacts report requested/present/missing symbols, duplicate symbol-session rows, stale symbols, empty symbols, partial history, provider query timestamp, cache hits/misses, refresh decisions, and `no_returned_bars`.
- Symbol coverage artifacts expose one row per requested symbol with requested dates, observed first/latest sessions, row counts, `empty_status`, `partial_history_status`, and `stale_status`.
- Generated caches, validation artifacts, refresh artifacts, local config overlays, credentials, repo-local package libraries, and heavyweight data files stay out of git.
- Operator documentation explains local config overlays, credentials outside YAML, local cache placement outside OneDrive when configured, non-network validation, and the separate credentialed live Alpaca smoke.
- `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passes before closeout evidence is refreshed.
- Credentialed live Alpaca smoke evidence, when regenerated, uses explicit `GEN5_AS_OF_TIMESTAMP`, `GEN5_FETCH_START_DATE`, and `GEN5_FETCH_END_DATE` values and leaves generated artifacts ignored.

## Non-Network Test Coverage Map

| Invariant | Current coverage |
| --- | --- |
| Canonical bar schema includes required data-layer fields | `tests/smoke_test.R`; `tests/testthat/test_data_contract.R`; `scripts/validate/validate_data_layer.R` |
| Latest completed session requires explicit `as_of_timestamp` | `tests/testthat/test_calendar_resolution.R`; `scripts/validate/validate_data_layer.R` |
| Requested dates are bounded by `latest_completed_session` | `tests/testthat/test_alpaca_provider.R`; `scripts/validate/validate_data_layer.R` |
| Alpaca adjusted daily requests reject unbounded future end dates | `tests/testthat/test_alpaca_provider.R`; `scripts/validate/validate_data_layer.R` |
| Provider payloads map to canonical adjusted daily OHLCV bars | `tests/testthat/test_alpaca_provider.R`; `scripts/validate/validate_data_layer.R` |
| Empty provider payloads remain canonical and auditable | `tests/testthat/test_alpaca_provider.R`; `tests/testthat/test_data_audit.R`; `scripts/validate/validate_data_layer.R` |
| Config loader overlays ignored local config without storing secrets | `tests/testthat/test_config_loader.R`; `scripts/validate/validate_data_layer.R` |
| Cache root preflight reports unusable local paths clearly | `tests/testthat/test_cache_store.R` |
| Cache reads expose partial hits without hiding misses | `tests/testthat/test_cache_store.R` |
| Incremental cache planning covers every v0 `refresh_decision` label | `tests/testthat/test_cache_store.R`; `scripts/validate/validate_data_layer.R` |
| Incremental cache writes merge deterministically and report `no_returned_bars` | `tests/testthat/test_cache_store.R`; `scripts/validate/validate_data_layer.R` |
| Audit artifacts report missing, stale, duplicate, cache, availability, and provider timestamp fields | `tests/testthat/test_data_audit.R`; `scripts/validate/validate_data_layer.R` |
| Symbol coverage artifacts report per-symbol availability status | `tests/testthat/test_data_audit.R`; `scripts/validate/validate_data_layer.R` |
| Generated artifacts and local machine files stay ignored | `tests/testthat/test_generated_artifact_ignores.R` |
| Live Alpaca fetch is not run by default validation | `scripts/validate/validate_data_layer.R`; operator docs |

## Data-Layer-Only Gaps To Watch

These are acceptable to leave as operator-reviewed closeout items rather than default tests:

- Live Alpaca connectivity depends on credentials, runtime packages, and network access, so it remains a separate smoke run through `scripts/run_data_refresh.R`.
- Evidence snapshots are date-specific; future operators should regenerate comparable snapshots with explicit timestamps and bounded dates rather than editing old generated CSVs.
- Cache placement is operator-local by design. The example config and runbook support outside-OneDrive cache roots, but the repository must not migrate or delete existing caches automatically.

## Cache Path Closeout Notes

Cache root selection is ergonomic enough for v0 when:

- `config/data_layer.example.yml` documents an outside-OneDrive default-style path.
- Ignored `config/data_layer.local.yml` can override `cache.root` for a durable local machine path.
- `GEN5_CACHE_ROOT` can override the cache root for one run.
- `g5_require_writable_cache_root()` fails loudly when the configured path is unusable.
- Generated cache files remain ignored and are not moved or deleted by closeout work.

## Evidence Regeneration Notes

For comparable closeout evidence:

1. Run the non-network validation wrapper from the repository root.
2. Run the credentialed Alpaca refresh smoke only when credentials and runtime packages are available.
3. Set explicit values before the live refresh:

```powershell
$env:GEN5_AS_OF_TIMESTAMP="2026-06-23 17:30:00"
$env:GEN5_FETCH_START_DATE="2026-02-23"
$env:GEN5_FETCH_END_DATE="2026-06-23"
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' scripts/run_data_refresh.R
```

4. Review the generated audit, refresh plan, merge summary, and symbol coverage CSVs under `runs/data_refresh/`.
5. Keep generated artifacts ignored; record closeout interpretation in source-controlled documentation only.
