# Gen5.4 Alpaca Context Capability POC

Status: `PARTIAL_PASS_NEWS_AVAILABLE_INDEX_NOT_AUTHORIZED`

## Question

Can the existing authenticated Alpaca plumbing retrieve and audit two simple
non-OHLCV context streams before any feature or predictive research begins?

## Frozen N0 News Scope

- Endpoint: Alpaca historical news (`/v1beta1/news`).
- Symbols: `AAPL,AMD,NVDA,TSLA,MSTR`.
- Window: `2024-01-02T00:00:00Z` through `2024-01-08T23:59:59Z`.
- Page size: 50; traverse every returned page token.
- Normalized fields: article ID, headline, summary, author, source, associated
  symbols, `created_at`, `updated_at`, URL, and whether content was present.
- Full content and images are excluded from the normalized table. Raw responses
  remain in the ignored local packet for provenance.

N0 passes when authentication succeeds, every page is traversed, at least one
article is returned, article IDs are unique, timestamps and headlines are
auditable, and the packet includes a readable sample and simple count charts.

## Frozen I0 Index Scope

- Endpoint: Alpaca historical index values (`/v1beta1/indices/values`).
- Candidate identifiers: `VIX,SPX,NDX`.
- Same historical window and explicit `as_of_timestamp` as N0.

I0 is a capability probe. HTTP 200 establishes account access; HTTP 403 records
an entitlement boundary. It does not justify substituting an ETF for an index or
changing the accepted C2 evidence provider.

## Hard Boundary

This POC computes no sentiment, embeddings, features, labels, returns, risk,
correlations, portfolio results, or model fits. It does not join news or index
data to OHLCV and cannot influence live advice.

## Implementation Surface

- Provider: `R/alpaca_context_provider.R`
- Tests: `tests/testthat/test_alpaca_context_provider.R`
- Wrapper: `scripts/inspect/run_gen54_alpaca_context_capability_poc.R`
- Packet: `runs/research_workbench/gen54_ml_decision_engine/g54_alpaca_context_n0_i0_20260721/`

## Readout

N0 retrieved 239 normalized article records across five fully traversed HTTP 200
pages totaling 209,710 raw bytes. Article IDs were unique; headlines,
`created_at`, and `updated_at` were complete; every creation date fell inside the
requested week. Normalized tables exclude article content and images.

I0 returned HTTP 403 with `not authorized for index data`. Alpaca's index
endpoint therefore exists, but the current account cannot use it. This does not
alter C2's accepted Cboe evidence or authorize an ETF substitution.

No sentiment, representation, feature, outcome, OHLCV join, or model was
created. The next gate is a theory discussion about whether a point-in-time news
representation is justified at all.
