# HYP-MOM-04.1 / DEPLOYMENT-UNIVERSE-DATA-AUDIT-01 Contract

Status: `FROZEN_EXECUTED`

## Purpose

Determine whether the unchanged `HYP-MOM-04.1` Ridge experiment can be
repeated on a much broader, externally defined stock cohort that was publicly
knowable before the retrospective `2021-2023` OOS interval.

This is not a repair of historical S&P 500 membership. The failed
`SP500-PIT-DATA-AUDIT-01` remains authoritative. This lane asks whether a fixed
deployment-date cohort generalizes forward; it does not claim to represent the
stocks that were investable members of the index in each 2017-2020 TRAIN
quarter.

## Point-in-time source correction

The SPDR S&P 500 ETF Trust Form N-PORT for holdings dated `2020-12-31` was not
accepted by the SEC until `2021-02-26`. It is therefore inadmissible for a
universe supposedly frozen before January 2021.

The primary universe source is instead:

- filer: SPDR S&P 500 ETF Trust, CIK `0000884394`;
- report date: `2020-09-30`;
- SEC accession: `0001752724-20-236128`;
- accepted: `2020-11-18 20:32:42`;
- primary document:
  `https://www.sec.gov/Archives/edgar/data/884394/000175272420236128/primary_doc.xml`.

The accepted timestamp is the SEC index timestamp in New York time. The SEC's
flattened bulk row records the filing date as `2020-11-19`; these are consistent
because the acceptance occurred after 20:30 New York time. The official
`2020 Q4` N-PORT bulk archive is the reproducible acquisition surface because
the accession was disseminated in November. The archive is named by
dissemination quarter, not the `2020-09-30` holdings report quarter:

- bulk archive:
  `https://www.sec.gov/files/dera/data/form-n-port-data-sets/2020q4_nport.zip`;
- retained tables: `SUBMISSION`, `FUND_REPORTED_INFO`,
  `FUND_REPORTED_HOLDING`, and `IDENTIFIERS` rows for the exact accession; and
- provenance: hash the complete archive plus every retained accession extract.

The full source document must be retained with its cryptographic hash. Every
reported common-stock holding is in scope. No holding may be removed or
replaced because its history, later outcome, or model behavior is inconvenient.

## Sector cross-check

Use the latest revision at or before `22:00:00 UTC` on `2020-09-30` of
Wikipedia's `List of S&P 500 companies`. Record the revision ID, timestamp,
URL, and source hash.

The resolved source is revision `980783480`, timestamped
`2020-09-28T12:34:09Z`. A pinned, reviewable crosswalk may resolve deterministic
name aliases and share classes between the two contemporaneous tables. It must
use the filing title/CUSIP and the exact Wikipedia symbol/security label; it
may not use later membership, future returns, or current-successor lookup.
Unresolved filing holdings remain distinct identities in the roster union.

The revision supplies a contemporaneous ticker and GICS sector cross-check.
It may not be filled with a later revision. Security-name normalization may be
used only as a deterministic diagnostic; ambiguous mappings fail.

## Evidence sequence and hard boundary

The source and TRAIN audit may use only:

- the two pinned universe/sector sources above;
- Alpaca adjusted daily OHLCV from `2016-01-04` through `2020-12-31`;
- explicit as-of timestamp `2026-08-07 17:30:00 America/New_York`; and
- the unchanged SPY trading-session calendar through `2020-12-31`.

No `2021+` bar, corporate action, return, model score, or coverage observation
may be queried unless both the universe audit and every original
`HYP-MOM-04.1` TRAIN gate pass.

## Identity and TRAIN-eligibility rules

1. Parse source issuer name, title, CUSIP, ticker identifier, balance, value,
   asset category, and issuer category when present.
2. Keep every common-stock/equity holding. Cash, derivatives, and non-equity
   instruments are excluded only by filing classification, never by outcome.
3. Preserve the filing ticker. A deterministic dot/slash share-class spelling
   challenger is allowed; current-symbol or successor backfill is not.
4. A holding maps to at most one Alpaca symbol. Ambiguous dual matches fail.
5. Every holding remains in the audit ledger. TRAIN eligibility requires exact
   adjusted-bar coverage on every SPY session from `2016-01-04` through
   `2020-12-31`, matching the original engine's frozen coverage rule.
6. Ticker changes, IPOs, mergers, delistings, and incomplete histories receive
   explicit coverage statuses and are not replaced.

This full-history rule intentionally produces a deployment-eligible subset of
the filed cohort. It is a causal availability rule as of `2020-12-31`, not a
claim that the excluded identities were absent from the source universe.

## Hard universe gates

The unchanged Ridge TRAIN may run only if all gates pass:

1. **Provenance:** exact SEC accession, acceptance timestamp, source URLs,
   hashes, and Wikipedia revision cutoff are recorded.
2. **Source timing:** every universe-defining source was public before
   `2021-01-01`; the later `2020-12-31` N-PORT filing is explicitly excluded.
3. **Roster size:** the filing contains `490-510` unique common-stock holdings.
4. **Identity completeness:** at least `98%` of in-scope holdings have a
   nonblank filing ticker or one unambiguous contemporaneous source mapping;
   no duplicate filing ticker/CUSIP pair or ambiguous provider mapping exists.
5. **Roster agreement:** filing-versus-contemporaneous-Wikipedia ticker
   Jaccard similarity is at least `0.97` after deterministic share-class
   punctuation normalization only.
6. **Sector coverage:** at least `98%` of filed holdings receive a
   contemporaneous GICS sector, at least 10 sectors are represented, and no
   later-revision fill is used.
7. **Provider representation:** at least `95%` of filed identities have some
   Alpaca history on or before `2020-12-31`.
8. **Complete TRAIN retention:** at least `80%` of filed identities satisfy the
   unchanged exact-session `2016-01-04` through `2020-12-31` eligibility rule.
9. **Boundary integrity:** no `2021+` observation, event, score, or outcome
   enters the audit or TRAIN query.

Gates are conjunctive and may not be softened after inspection under this
identifier.

## Conditional model sequence

If and only if every universe gate passes:

1. run the existing six features, relative target, five-lambda grid,
   expanding time-ordered CV folds, one-standard-error rule, permutation
   control, and seven original TRAIN gates unchanged;
2. retain every coverage-eligible identity and its contemporaneous sector;
3. stop without querying `2021+` if any original TRAIN gate fails; and
4. only after TRAIN nomination, query the frozen `2021-2023` OOS interval and
   apply the existing OOS coverage, execution, cost, comparator, and reporting
   rules without retuning.

## Required outputs

The ignored evidence packet must include:

- source ledger and raw-source hashes;
- complete parsed filing ledger;
- contemporaneous sector and roster reconciliation;
- provider-symbol resolution and TRAIN coverage ledgers;
- universe gate matrix;
- conditional TRAIN artifacts if authorized;
- explicit evidence that `2021+` remained unqueried unless TRAIN nominated;
- concise report and high-impact visuals; and
- a durable result of either audit STOP, TRAIN STOP, or conditional OOS.

Prepare the official archive extracts with
`operator_hypothesis_lab/scripts/prepare_hyp_mom_04_1_deployment_universe_sources.R`,
then run
`operator_hypothesis_lab/scripts/run_hyp_mom_04_1_deployment_universe_data_audit.R`.
