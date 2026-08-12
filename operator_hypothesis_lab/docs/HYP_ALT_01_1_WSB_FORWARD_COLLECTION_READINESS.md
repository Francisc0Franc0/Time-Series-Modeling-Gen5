# HYP-ALT-01.1 WSB Forward Collection Readiness

Status: `IMPLEMENTED_STOP_LIVE_REDDIT_ACCESS_NOT_CONFIGURED`

## Implemented

- OAuth application-only token flow and authenticated WSB comment listing.
- Explicit Reddit-approval, credential, user-agent, runtime, and registry
  preflight checks.
- Restart-safe pagination with comment-ID deduplication and overlap-based
  continuity diagnostics.
- High-confidence cashtag extraction plus registry-constrained bare-symbol
  extraction with an ambiguity denylist.
- A privacy-minimal observation ledger and reversible comment-to-ticker ledger;
  no comment bodies or usernames are persisted.
- Eastern-date daily ticker attention and collection-health tables.
- Incremental deletion reconciliation that purges removed contributions.
- A two-minute PowerShell polling loop with periodic reconciliation.
- Fixture tests covering ticker ambiguity, Eastern dates, comment-versus-token
  counts, restart overlap, fail-closed approval, and deletion purging.

## Symbol-registry result

The official Alpaca paper-account assets endpoint authenticated successfully
on 2026-08-12 and returned `14,227` active `us_equity` symbols after schema
normalization. Equities and ETFs share that Alpaca asset class. The registry is
stored at:

`data_cache/operator_hypothesis_lab/hyp_alt_01_1_wsb/active_us_equity_registry.csv`

That file is intentionally ignored. It is a forward recognition list, not a
historical constituent claim.

## Live Reddit gate

No live Reddit request was made. The local preflight found:

- Reddit approval attestation: missing;
- OAuth client ID: missing;
- OAuth client secret: missing;
- descriptive Reddit user agent: missing;
- required R runtime: available; and
- ticker registry: available.

This is the correct fail-closed result. Do not set the approval flag merely to
bypass the gate. Apply for Reddit access and describe the use case accurately
as a local forward-counting research collector that stores no raw content or
user profiles. If Reddit approves a different authentication or research-export
route, adapt the provider boundary before collection rather than working around
it.

## Operator setup after approval

Place these values in the ignored repo-local `.Renviron` or the process
environment; never commit them:

```text
GEN5_REDDIT_ACCESS_APPROVED=true
GEN5_REDDIT_CLIENT_ID=<approved client id>
GEN5_REDDIT_CLIENT_SECRET=<approved client secret>
GEN5_REDDIT_USER_AGENT=windows:gen5-wsb-attention:v0.1 (by /u/<reddit account>)
```

Then run:

```powershell
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' operator_hypothesis_lab/scripts/preflight_hyp_alt_01_1_reddit.R
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' operator_hypothesis_lab/scripts/run_hyp_alt_01_1_wsb_collection.R
```

The first run must report `BOOTSTRAP_NO_COVERAGE_AUTHORITY`. A second timely
run should report `PASS_FORWARD_OVERLAP`. Only after that smoke sequence should
the foreground poller be started:

```powershell
powershell -ExecutionPolicy Bypass -File operator_hypothesis_lab/scripts/run_hyp_alt_01_1_wsb_poll_loop.ps1
```

The poller remains a foreground, interruptible process. No Windows scheduled
task or hidden background process has been installed.

## Ignored output surface

The default storage root is:

`data_cache/operator_hypothesis_lab/hyp_alt_01_1_wsb/`

It will contain:

- `comment_observation_ledger.csv`;
- `comment_ticker_ledger.csv`;
- `collection_run_ledger.csv`;
- `daily_ticker_attention.csv`;
- `daily_collection_health.csv`; and
- `deletion_reconciliation_ledger.csv`.

## Decision

The implementation is ready for an approved credential smoke test, but no
healthy Reddit database exists yet. Preserve
`IMPLEMENTED_STOP_LIVE_REDDIT_ACCESS_NOT_CONFIGURED`. Do not infer historical
coverage, sentiment, predictive value, portfolio performance, or trading
authority from the fixture tests or Alpaca registry.
