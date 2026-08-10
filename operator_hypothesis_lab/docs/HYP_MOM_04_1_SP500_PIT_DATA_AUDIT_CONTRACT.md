# HYP-MOM-04.1 / SP500-PIT-DATA-AUDIT-01 Contract

Status: `FROZEN_PENDING_EXECUTION`

## Purpose

Determine whether the unchanged `HYP-MOM-04.1` quarterly Ridge experiment can
be repeated on a leakage-safe, point-in-time S&P 500 universe with the data
available to this project.

This is a data-feasibility audit, not a strategy run. It creates no authority
to fit Ridge, select lambda, inspect 2021-2023 outcomes, change the six features,
or relax the seven model gates. A strategy replication may be frozen only if
every hard data gate below passes.

## Evidence boundary

- Calendar and adjusted-daily bar evidence may end no later than
  `2020-12-31`.
- Signal quarters are the existing 15 `HYP-MOM-04.1` TRAIN quarters,
  `2017Q1` through `2020Q3`.
- Target quarters end at `2020Q4`.
- No 2021+ bar, return, model score, or outcome may be queried.
- Every request carries the explicit as-of timestamp
  `2026-08-07 17:30:00 America/New_York`.

## Frozen source roles

### Primary membership ledger

Use commit `c31ac3cc56f28cf9a02b4e694eff7ceab596a0ff` of
[`fja05680/sp500`](https://github.com/fja05680/sp500), specifically:

- `sp500_ticker_start_end.csv` for point-in-time membership intervals; and
- `S&P 500 Historical Components & Changes (Updated).csv` as an internal
  snapshot cross-check.

Membership is active when `start_date <= signal_date` and `end_date` is blank
or strictly later than `signal_date`. The ledger is public and reproducible,
but not official S&P data; the audit must preserve that limitation.

### Independent roster and sector cross-check

For each signal date, use the latest revision at or before `22:00:00 UTC` that
day of Wikipedia's `List of S&P 500 companies`. Record the revision ID and
timestamp. The revision supplies a second roster and contemporaneous GICS
sector labels. A later revision may never be used to fill an earlier quarter.

### Market bars

Use only Alpaca adjusted daily OHLCV through `2020-12-31`. Provider quirks stay
inside existing provider modules. Source tickers remain point-in-time
identities; current tickers may not backfill removed names merely because they
have better coverage.

For share-class punctuation, query the source spelling first and a deterministic
dot/slash spelling variant only when applicable. Choose the unique spelling
with data; ambiguous dual matches fail identity resolution.

## Frozen audit schedule

Quarter-end signal, next-quarter first-open entry, and next-quarter last-open
exit sessions come from the bounded SPY calendar, exactly as in
`HYP-MOM-04.1`.

For every primary member at every signal date, audit:

1. membership interval and source provenance;
2. independent Wikipedia membership agreement;
3. contemporaneous GICS sector availability;
4. deterministic provider-symbol resolution;
5. complete adjusted bars on every SPY session in the 253-session feature
   window ending on the signal date;
6. adjusted opens on the target entry and target exit sessions; and
7. whether the identity leaves the index during its target quarter, which may
   require a merger, acquisition, or delisting settlement return rather than a
   normal quarter-end bar.

No member may be dropped because its target later proved inconvenient. Missing
or terminal outcomes are audit failures, not quiet exclusions.

## Hard data gates

The point-in-time replication is feasible only if all gates pass:

1. **Provenance:** the primary commit is exact; every Wikipedia revision is at
   or before its frozen cutoff; all source hashes and URLs are recorded.
2. **Roster size:** every primary quarter-end roster contains 490-510
   securities.
3. **Roster agreement:** primary-versus-Wikipedia Jaccard similarity is at
   least 0.97 in every signal quarter.
4. **Sector coverage:** at least 98% of primary members receive a
   contemporaneous sector in every quarter, with at least 10 represented
   sectors and no future-revision fill.
5. **Identity resolution:** every analyzed row maps to no more than one Alpaca
   symbol; no current-symbol survivorship backfill or ambiguous dual match is
   accepted.
6. **Feature and ordinary target coverage:** at least 95% of primary members in
   every quarter have the complete 253-session feature window plus target
   entry and exit opens.
7. **Removed-security representation:** at least 95% of primary identities
   absent from the repository's current roster have some Alpaca history; this
   is a diagnostic against silently auditing only survivors.
8. **Terminal-event completeness:** every member that leaves during its target
   quarter has a defensible settlement/terminal return under the unchanged
   next-quarter holding rule. A final trading bar alone is not assumed to equal
   merger consideration.
9. **Boundary integrity:** no bar later than `2020-12-31`, no 2021+ outcome, and
   no unpinned membership or sector observation enters the audit.

Gates are conjunctive. The 0.97, 98%, and 95% thresholds may not be softened
after coverage is observed under this identifier.

## Outputs

The audit must retain an ignored run packet containing:

- source ledger and hashes;
- quarter/revision ledger;
- primary and Wikipedia roster comparison;
- sector coverage;
- symbol-resolution ledger;
- member-quarter bar coverage;
- removed-security and terminal-event ledgers;
- gate matrix;
- concise report and high-impact summary visuals.

The durable repository record must state either
`SP500_PIT_DATA_AUDIT_PASS_REPLICATION_MAY_BE_FROZEN` or
`STOP_SP500_PIT_DATA_GATES_FAILED_REPLICATION_NOT_RUN`.
