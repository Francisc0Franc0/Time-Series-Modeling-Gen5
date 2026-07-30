# LIT-MR-06.1 Recent Wide Stock Atlas 02 Contract

Status: `FROZEN_APPROVED_IMPLEMENTATION`

## Place in the literature-study progression

`LIT-MR-06.1 / RECENT_WIDE_ATLAS_02` is a fresh replication batch under the
unchanged causal buy-on-gap mechanics. It answers the operator's request to
inspect newer data with a materially wider, rationally selected stock panel.

It is not `LIT-MR-06.2`: no signal formula, direction, timing, position sizing,
cost, control, or gate changes. The completed 2019-2020
`BUY_ON_GAP_ATLAS_01` result remains immutable evidence.

## Question

Across a broad, sector-balanced stock universe, did Chan's source-inspired
negative-gap rule show causal 09:32-to-close reversal during 2023-2024 strongly
enough to earn one predeclared 2025-June 2026 DEVELOPMENT replay?

## Frozen windows

- Registry source date: State Street daily holdings as of `2026-07-28`.
- Explicit research as-of timestamp:
  `2026-07-30 03:55:00 America/New_York`.
- Daily warm-up query begins: `2022-08-01`.
- TRAIN: `2023-01-03` through `2024-12-31`.
- DEVELOPMENT: `2025-01-02` through `2026-06-30`.
- CONFIRMATION: `2026-07-01` onward remains sealed.

DEVELOPMENT may be queried only for an instance that passes all eight
unchanged TRAIN gates. Every full TRAIN pass receives one frozen OOS replay;
instances are not ranked against each other to select a preferred outcome.

## Universe construction

The eleven State Street Select Sector SPDR ETFs define the stock categories
and matched benchmarks:

`XLK, XLF, XLE, XLV, XLP, XLI, XLY, XLC, XLU, XLB, XLRE`.

For each official holdings workbook:

1. retain USD common-equity ticker rows;
2. order securities by published fund weight;
3. collapse duplicate share classes using the first six CUSIP characters and
   retain the higher-weight class;
4. screen the first 40 issuer-ranked candidates only for adjusted-daily
   coverage from August 2022 through December 2024;
5. retain the first 30 issuers with at least 90% coverage, or every eligible
   issuer if the sector contains fewer than 30; and
6. make the combined wide-US panel the union of all selected sector stocks.

No price response, gap event, return, hit rate, gate, or other strategy outcome
entered selection. The coverage screen completed before strategy execution.

The frozen registry is
[the Atlas 02 registry](../registries/gen5_lit_mr_06_1_recent_wide_atlas_02_registry.csv).
The ignored registry-build packet records the raw workbooks, source URLs,
candidate ledger, coverage table, and final-constituent audit under:

`runs/research_workbench/literature_grounded/lit_mr_06_1_recent_wide_atlas_02_registry`

## Frozen panels

| Instance | Role | Stocks | Benchmark |
|---|---|---:|---|
| `W01_WIDE_US` | Combined cross-sector primary panel | 305 | `SPY` |
| `W02_TECHNOLOGY` | Sector diagnostic | 30 | `XLK` |
| `W03_FINANCIALS` | Sector diagnostic | 30 | `XLF` |
| `W04_ENERGY` | All eligible issuers | 21 | `XLE` |
| `W05_HEALTH_CARE` | Sector diagnostic | 30 | `XLV` |
| `W06_CONSUMER_STAPLES` | Sector diagnostic | 30 | `XLP` |
| `W07_INDUSTRIALS` | Sector diagnostic | 30 | `XLI` |
| `W08_CONSUMER_DISCRETIONARY` | Sector diagnostic | 30 | `XLY` |
| `W09_COMMUNICATION_SERVICES` | All eligible issuers | 18 | `XLC` |
| `W10_UTILITIES` | Sector diagnostic | 30 | `XLU` |
| `W11_MATERIALS` | All eligible issuers | 26 | `XLB` |
| `W12_REAL_ESTATE` | Sector diagnostic | 30 | `XLRE` |

All 305 selected identities have complete adjusted-daily coverage across the
warm-up/TRAIN interval. Financials, consumer staples, and industrials each
used one lower-ranked candidate after a higher-ranked current holding failed
the coverage rule. Communication services retained 18 of 20 candidate
issuers after two coverage failures.

## Unchanged strategy mechanics

- Candidate gap:
  \(g_{i,t}=O_{i,t}/L_{i,t-1}-1\).
- Gap threshold:
  \(g_{i,t}<-\sigma_{i,t}^{90}\), using only lagged close-to-close returns.
- Trend filter:
  \(O_{i,t}>MA_{20}(C_{i,t-20},\ldots,C_{i,t-1})\).
- Rank most-negative qualifying gaps and buy at most ten.
- Signal complete at `09:31`; causal entry proxy is the adjusted `09:32`
  minute-bar open.
- Each selected stock receives one fixed 10% sleeve. Unused sleeves remain
  cash.
- Exit proxy is the adjusted daily close.
- Primary/stress round-trip costs remain 10/20 bp.
- The same-open curve remains `NONCAUSAL_REFERENCE`.

The short mirror remains out of scope.

## Unchanged eight TRAIN gates

1. Integrity and causal timing.
2. At least 95% selected-entry coverage.
3. At least 60 stock-events across at least 30 portfolio days.
4. Positive mean primary-cost stock-event return.
5. Positive one-sided 90% block-bootstrap lower bound for mean portfolio-day
   return.
6. Positive matched-benchmark excess.
7. Mean portfolio-day return above the seeded random-stock control p90.
8. Positive stress cumulative return and no more than 50% of positive gross
   P&L from one symbol.

Passage remains conjunctive. The combined and sector panels overlap and are
not twelve independent hypotheses. Every result must be published; no panel
may be dropped, substituted, or promoted by a weighted near-pass score.

## Interpretation boundary

The registry uses July 2026 current holdings to inspect earlier dates. It
therefore remains survivor- and membership-biased, even though its selection
is objective and outcome-blind. It omits stocks removed from the sector funds
before the registry date and may include companies that entered after part of
the test interval.

This is a pedagogical recent-data breadth study, not a historical S&P 500
reconstruction or a deployable scanner. A stronger replication would require
point-in-time constituent membership, delisted securities, quote-aware fills,
and closing-auction validation.

## STOP rules

Do not change the registry, dates, source-weight order, coverage rule, entry
minute, costs, signal mechanics, controls, or gates after seeing TRAIN.

If no panel passes all eight gates, stop without DEVELOPMENT. Do not select the
best point estimate, add another panel, or use the recent window to revise the
completed Atlas 01 interpretation.

Do not open a short strategy, ETF-candidate variant, another provider, live
scanner, order path, allocation rule, or production behavior from this batch.

## Universe sources

The official State Street sector overview identifies the eleven sector funds:

`https://www.ssga.com/us/en/institutional/capabilities/equities/sector-investing/select-sector-etfs`

Each registry input uses the corresponding official daily holdings workbook:

`https://www.ssga.com/library-content/products/fund-data/etfs/us/holdings-daily-us-en-{ticker}.xlsx`
