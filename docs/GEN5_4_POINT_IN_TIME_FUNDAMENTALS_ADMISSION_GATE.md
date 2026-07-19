# Gen5.4 Point-in-Time Fundamentals Admission Gate

Status: F0 provider scope opened; `BLOCKED_EXTERNAL_SEC_ACCESS`

Decision date: 2026-07-19

Branch: `codex/Gen5.4-ml-decision-engine-plan`

## Purpose

The completed cross-sectional X1 screen found only one independent OHLCV
primitive. This document asks whether earnings and filed financial statements
are a sufficiently distinct, retail-accessible, point-in-time information
family to justify a minimal data-feasibility POC.

It does not authorize a new provider, data pipeline, feature table, model,
portfolio policy, allocation method, or live behavior.

## Professional Design Principle

A fundamental value must not be assigned to its fiscal-period end date. The
market could not know the reported value then. It becomes eligible only after
the filing or release was publicly disseminated and before the system's
declared decision timestamp.

The research table must therefore distinguish:

- the economic period the value describes;
- the filing accession that disclosed it;
- the original acceptance timestamp;
- the timestamp at which the research system first permits its use;
- later amendments or restatements;
- the retrieval timestamp and raw-source checksum.

Without these fields, a historically attractive fundamental feature is not
credible evidence.

## Decision-Layer Fit

| Information family | Primary system role | Why |
|---|---|---|
| Filed company fundamentals | Cross-sectional asset ranking | Values differ by company and can describe changes in growth, profitability, cash generation, and balance-sheet quality. |
| Earnings-event timing | Ranking context and conditional interaction | A new filing changes the age and relevance of the latest company information. Timing alone is not an earnings-surprise measure. |
| Macro and credit data | Broad exposure permission | Most macro observations are shared by every asset on a date and therefore cannot directly change same-date ranks without predeclared company or sector sensitivities. |
| Historical news | Event discovery or later text POC | News is company-specific but noisy, editable, and materially harder to standardize than filed numeric facts. |
| Analyst estimate revisions | Cross-sectional ranking | Economically strong candidate, but credible testing requires a historical as-of consensus archive rather than today's reconstructed history. |
| Options-implied data | Ranking and risk context | Potentially rich, but historical chain depth, contract survivorship, liquidity, and subscription cost make it a poor first plumbing POC. |

## Documentation Audit

### SEC EDGAR and XBRL

The SEC's `data.sec.gov` APIs provide submissions history and standardized XBRL
company facts without authentication or API keys. The APIs update throughout
the day as filings are disseminated, and nightly bulk archives are available.
The documented filing metadata includes accession identifiers, filing dates,
and acceptance date-times. XBRL coverage begins in the modern filing era and is
appropriate for the 2018-2024 X0/X1 research window.

Strengths:

- authoritative public filings rather than vendor-derived snapshots;
- no data-subscription cost;
- accession-level provenance;
- filing and acceptance metadata suitable for an as-known reconstruction;
- standardized US-GAAP concepts for many common statement items;
- long enough history for the current fixed panel.

Material limitations:

- companies use different fiscal calendars;
- standard concepts can change, and company-specific extensions are common;
- the same economic fact can appear in multiple filings or amendments;
- current company-facts responses contain historical filings and must be
  reconstructed by acceptance time rather than treated as one timeless table;
- post-acceptance corrections or removals require immutable local raw snapshots
  and explicit amendment handling;
- SEC facts do not supply a historical analyst-consensus estimate.

Admission status: `PASS_TO_F0_SAMPLE_AUDIT`.

### Alpaca historical news

Alpaca documents historical Benzinga news back to 2015. The API supports symbol
filters, RFC-3339 start/end timestamps, pagination, and optional article
content. Records expose creation and update times.

This is useful as a future event or text family, and it stays close to the
existing account. It is not a substitute for standardized financial statements
or an analyst-consensus archive. Article edits, coverage variation, duplicated
stories, symbol tagging, content availability, and any sentiment model would
need their own leakage and robustness contract.

Admission status: `HOLD_AS_SECONDARY_EVENT_SOURCE`.

### Alpaca corporate actions

Alpaca's corporate-actions endpoint covers splits, dividends, mergers,
spin-offs, symbol changes, and related events. It is not an earnings or
financial-statement endpoint. Alpaca also warns that corporate-action creation
time is not guaranteed and may be delayed.

Admission status for the present hypothesis: `NOT_THE_REQUIRED_INFORMATION`.

### Current-snapshot fundamental services

A consumer API that returns historical fiscal periods but cannot prove what
value, estimate, or revision was available at each historical decision time
must not become research authority. Convenient schemas do not compensate for
look-ahead or restatement leakage.

Admission status: `REJECT_UNLESS_AS_OF_HISTORY_IS_PROVEN`.

## Proposed F0 Sample Audit

If the operator opens SEC as a research-only provider, F0 should fetch a small
sample rather than build the full pipeline. The sample should include companies
with different fiscal calendars and reporting complexity:

- `AAPL`: large platform company with a non-calendar fiscal year;
- `AMD`: semiconductor company;
- `JPM`: financial company with materially different statement structure;
- `WMT`: retailer with a non-calendar fiscal year;
- `MSTR`: special-situation company whose accounting profile changed over time.

F0 would inspect only filings and facts needed to answer data feasibility. It
would not compute predictive outcomes.

Required outputs:

- frozen symbol-to-CIK registry;
- 10-Q, 10-K, and relevant amendment manifest;
- filing accession, form, fiscal period, filed date, and acceptance timestamp;
- candidate-concept coverage matrix by symbol and fiscal period;
- duplicate/restatement examples and deterministic as-known resolution;
- raw-response manifest with retrieval timestamp and checksum;
- human-facing filing timeline and coverage heatmap;
- explicit `PASS`, `REVIEW_REQUIRED`, or `STOP` recommendation.

## Proposed Point-in-Time Contract

1. Every request carries an explicit research `as_of_timestamp` and declared
   user agent.
2. Store raw SEC responses immutably outside git with request URL, retrieval
   timestamp, response checksum, and accession identifiers.
3. Map symbols to a frozen CIK registry; do not infer historical membership from
   the current SEC ticker file.
4. A fact is unavailable before its filing acceptance timestamp.
5. Convert acceptance time to `America/New_York` and compare it with the
   after-close decision timestamp and the Gen5 trading calendar.
6. If exact acceptance time cannot be established, delay availability until the
   next completed market session rather than assuming an intraday release.
7. Amendments and restatements become visible only after their own acceptance;
   they never rewrite earlier feature rows.
8. Resolve multiple facts using only filings accepted by the historical as-of
   time, with deterministic accession, form, fiscal-period, unit, and duration
   rules.
9. Compare like fiscal periods year over year; do not force company quarters
   into calendar-quarter identities.
10. Missing concepts remain missing. Do not silently substitute custom tags,
    zeroes, later values, or cross-company medians.
11. Keep units and scale explicit and fail on ambiguous currency or duplicate
    authority.
12. No outcome, IC, portfolio return, or model is computed in F0.

## Candidate Concept Families For Coverage Only

F0 should test whether the raw materials exist consistently; it should not yet
freeze predictive formulas.

- revenue or sales;
- operating income;
- net income attributable to the registrant;
- operating cash flow;
- total assets and liabilities;
- diluted weighted-average shares.

Banks and other financial firms may require different economically meaningful
concepts. The sample includes `JPM` specifically to reveal whether one universal
feature contract would create false comparability. If so, the correct response
is a narrower eligible universe or predeclared industry-specific feature roles,
not silent imputation.

## Frozen F0 Admission Gates

F0 may recommend a full 24-stock fundamentals-ingestion POC only if:

- exact or conservatively lagged availability can be reconstructed for every
  admitted filing;
- accession-level amendment handling is deterministic;
- at least four of the five sample companies have usable quarterly histories
  across 2018-2024 for at least three economically meaningful concept families;
- the filing timeline has no fact dated before public availability;
- missingness and concept substitutions are visible in the operator artifacts;
- raw-source provenance can be cached audibly outside git;
- financial-sector comparability is either defensible or explicitly separated;
- no current-snapshot data is allowed to rewrite historical state.

Any failure in timestamp reconstruction or amendment handling is a hard `STOP`.
Partial concept coverage may be `REVIEW_REQUIRED`, not automatically a failure,
provided it is honest and does not require outcome-informed exclusions.

## Feasibility Recommendation

Earnings and filed fundamentals pass the theory and documentation gate. SEC
EDGAR is the recommended authority for the first research-only F0 sample audit.
Alpaca remains the authority for adjusted daily OHLCV; its news feed should be
reserved as a later, separately admitted information family.

The operator opened SEC as a research-only provider for this frozen F0 sample.
The first request nevertheless returned Akamai HTTP 403 from the execution
environment, both through the R provider and a direct contact-bearing command-
line header check. No filing payload entered research authority.

Do not route around this blocker with an unofficial mirror or current-snapshot
vendor. Retry from a compliant network path or use operator-controlled SEC bulk
downloads with retained provenance. Predictive features, outcomes, and the
full-panel ingestion gate remain closed.

## Authoritative References

- SEC EDGAR API documentation: `https://www.sec.gov/search-filings/edgar-application-programming-interfaces`
- SEC EDGAR data access guidance: `https://www.sec.gov/search-filings/edgar-search-assistance/accessing-edgar-data`
- SEC Financial Statement Data Sets documentation: `https://www.sec.gov/files/financial-statement-data-sets.pdf`
- Alpaca historical news documentation: `https://docs.alpaca.markets/us/docs/historical-news-data`
- Alpaca news endpoint: `https://docs.alpaca.markets/us/reference/news-3`
- Alpaca corporate-actions endpoint: `https://docs.alpaca.markets/us/reference/corporateactions-1`
