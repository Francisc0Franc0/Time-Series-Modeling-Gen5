# HYP-MOM-04.1 S&P 500 Point-in-Time Data Audit Results

Status: `STOP_SP500_PIT_DATA_GATES_FAILED_REPLICATION_NOT_RUN`

## Question

Can the unchanged `HYP-MOM-04.1` quarterly Ridge experiment be repeated across
the S&P 500 without defining the historical universe from today's survivors or
backfilling historical identities with future ticker information?

## Frozen boundary

This was a data-feasibility audit, not a strategy run.

- Signal quarters: `2017Q1` through `2020Q3`.
- Last target quarter: `2020Q4`.
- Last permissible adjusted bar: `2020-12-31`.
- Explicit as-of timestamp: `2026-08-07 17:30:00 America/New_York`.
- Primary membership source: commit
  `c31ac3cc56f28cf9a02b4e694eff7ceab596a0ff` of `fja05680/sp500`.
- Independent check: the latest Wikipedia `List of S&P 500 companies`
  revision at or before `22:00 UTC` on each signal date.
- Price source: Alpaca adjusted daily OHLCV only.

The audit did not fit Ridge, select lambda, compute model scores, inspect a
top quartile, query a 2021+ bar, or run OOS.

## Population

- `15` signal-quarter rosters.
- `505-506` primary securities per roster.
- `591` unique primary source tickers.
- `7,580` member-quarter observations.
- `185` source identities absent from the pinned current roster.

## Gate readout

| Gate | Frozen requirement | Result | Status |
|---|---|---:|---|
| Provenance | Exact commit, hashes, URLs, and revision cutoffs | Three pinned source hashes and all 15 revision cutoffs recorded | `PASS` |
| Roster size | 490-510 every quarter | 505-506 | `PASS` |
| Roster agreement | Primary/Wikipedia Jaccard at least 0.97 every quarter | Worst `0.9555`; 2017Q1-Q3 failed | `FAIL` |
| Sector coverage | At least 98% and 10 sectors every quarter | Worst `97.63%`; 2017Q1-Q2 failed; 11+ sectors throughout | `FAIL` |
| Identity resolution | No ambiguous provider symbol | No ambiguous dual match | `PASS` |
| Feature + ordinary target coverage | At least 95% every quarter | Worst `97.63%` | `PASS` |
| Removed-security representation | At least 95% have some Alpaca history | `184 / 185` (`99.46%`) | `PASS` |
| Terminal-event completeness | Every frozen target has a defensible exit | `53 / 92` index departures had both scheduled opens; `39` remained unresolved | `FAIL` |
| Boundary integrity | No 2021+ or unpinned evidence | Last bar `2020-12-31`; no model/OOS run | `PASS` |

Six of nine gates passed. The contract is conjunctive, so three failures stop
the replication.

## What the failures mean

### 1. The public primary ledger is not a clean historical identity ledger

The primary interval file and its own historical snapshots agree exactly, but
early rows use later ticker aliases. For example, the 2017Q1 primary roster
contains `BKNG`, `TPR`, and `WELL`, while the contemporaneous revision contains
`PCLN`, `COH`, and `HCN`. Similar differences include `AABA/YHOO`,
`ANDV/TSO`, `APTV/DLPH`, and `KDP/DPS`.

This does not imply that the underlying companies were absent from the index.
It means the labels have been normalized with information learned later. That
is unsuitable as the sole point-in-time identity authority for a leakage-safe
replication.

The later 2020 mismatches are different: contemporaneous revisions can lag
effective index changes. This is why neither public source is accepted alone;
the frozen cross-source agreement gate was useful.

### 2. Strong bar coverage does not solve corporate-action outcomes

Alpaca represented `184 / 185` non-current identities and every quarter cleared
the ordinary 95% feature-plus-target coverage gate. Price history itself was
therefore much stronger than a current-survivor screen would suggest.

However, `92` quarter-end members left the index during their frozen target
quarter. `53` continued trading with both scheduled entry and exit opens, so
the unchanged rule still had an ordinary return. `39` lacked one of those
frozen opens. A final pre-merger bar cannot be assumed to equal cash, stock,
mixed consideration, or the value of a spun-off security. Alpaca daily bars
alone cannot construct those terminal returns defensibly.

## Decision

Record:

`STOP_SP500_PIT_DATA_GATES_FAILED_REPLICATION_NOT_RUN`

The sub-lane succeeded as an audit. It demonstrated that a large provider
history and plausible public membership table are not, by themselves, enough
to support a point-in-time cross-sectional training panel.

Do not rescue the inspected audit by:

- using today's S&P 500 constituents;
- treating later aliases as if they were contemporaneous tickers;
- dropping names with missing exits;
- using the last printed bar as merger consideration;
- lowering the 0.97, 98%, or terminal-completeness gates; or
- fitting the model on the subset that happens to be easy to price.

## Reopen conditions

A future replication discussion should begin with a new data-source decision,
not a model change. The recommended minimum is:

1. a licensed or otherwise authoritative point-in-time constituent history
   that preserves original identifiers and effective dates;
2. contemporaneous sector classifications or a documented point-in-time
   sector history; and
3. corporate-action/event data sufficient to value mergers, acquisitions,
   delistings, spin-offs, and other missing frozen exits.

Only after a separately frozen data audit passes should the unchanged Ridge
replication be authorized.

A subsequent accessible-source repair attempt is documented in
`HYP_MOM_04_1_SP500_PIT_SOURCE_REPAIR_RESULTS.md`. Alpaca's official
corporate-actions endpoint returned relevant records for only `8 / 39`
unresolved identities. Even if every returned event were valued successfully,
at least 31 targets would remain unresolved. No available local entitlement
closed the identity, sector, and terminal-return gaps, so this STOP remains
authoritative.

## Artifacts

- Contract:
  `operator_hypothesis_lab/docs/HYP_MOM_04_1_SP500_PIT_DATA_AUDIT_CONTRACT.md`
- Runner:
  `operator_hypothesis_lab/scripts/run_hyp_mom_04_1_sp500_pit_data_audit.R`
- Audit packet:
  `runs/research_workbench/operator_hypothesis_lab/hyp_mom_04_1_sp500_pit_data_audit_20260810`
- Evidence deck:
  `operator_hypothesis_lab/presentations/hyp_mom_04_1_sp500_pit_data_audit_evidence.pptx`
- Source-repair results:
  `operator_hypothesis_lab/docs/HYP_MOM_04_1_SP500_PIT_SOURCE_REPAIR_RESULTS.md`
