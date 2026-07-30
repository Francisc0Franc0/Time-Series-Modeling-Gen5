# LIT-MR-02.1 Relationship Atlas 01 Contract

## Status

`COMPLETED_STOP`

This is a higher-throughput hypothesis-generation demonstration for the
unchanged `LIT-MR-02.1` mechanics. It is an instance batch, not a new strategy
variant. Panels A and B, the canonical USO-GLD example, and both positive
controls remain immutable.

## Completed Readout

The frozen TRAIN screen completed with
`STOP_LIT_MR_02_1_RELATIONSHIP_ATLAS_01_NO_FULL_PASS`.

- All 25 predeclared pair instances had complete requested TRAIN coverage.
- No pair cleared all eight gates.
- Only `A23_SIL_SLV` had a positive primary-cost mean net trade return:
  `+56.8 bp/trade`, with a 95% moving-block-bootstrap interval of
  `[-19.3, +143.3] bp`.
- `A23_SIL_SLV` cleared six gates, but its return interval included zero and
  its forward-convergence 95% upper bound remained slightly positive.
- The median pair result was `-22.59 bp/trade`; only three of 25
  forward-convergence point estimates were negative.
- No pair was nominated, DEVELOPMENT was not queried for strategy evaluation,
  and CONFIRMATION remains sealed.

The generated packet is
`runs/research_workbench/literature_grounded/lit_mr_02_1_relationship_atlas_01_20260729`.

## Research Question

Can a transparent economic-relationship atlas generate a finite,
category-balanced set of pair hypotheses, and does any predeclared pair clear
the existing eight TRAIN gates strongly enough to justify one genuinely OOS
DEVELOPMENT replay?

The purpose is not to keep generating pairs until one works. The purpose is to
demonstrate a repeatable, auditable hypothesis-generation mechanism and report
all of its outcomes.

## Frozen Generator

The generator has two axes:

1. **Instrument topology:** ETF-ETF, ETF-component, stock-stock, or
   producer/asset-proxy.
2. **Economic mechanism:** duplicate claim, overlapping basket, constituent
   containment, peer economics, or shared commodity driver.

Five candidates are fixed in each of five cells. The first symbol is \(Y\); the
second is \(X\) in \(S_t=Y_t-\beta_tX_t\).

| Index | Pair ID | Pair | Topology | Economic mechanism | Ex-ante rationale |
|---:|---|---|---|---|---|
| 201 | `A01_SPY_IVV` | SPY-IVV | ETF-ETF | duplicate claim | Two S&P 500 index implementations |
| 202 | `A02_GLD_IAU` | GLD-IAU | ETF-ETF | duplicate claim | Two physically backed gold exposures |
| 203 | `A03_XLK_VGT` | XLK-VGT | ETF-ETF | overlapping basket | Two broad US technology-sector portfolios |
| 204 | `A04_VOO_SPY` | VOO-SPY | ETF-ETF | duplicate claim | Two S&P 500 index implementations with different sponsors |
| 205 | `A05_MDY_IJH` | MDY-IJH | ETF-ETF | overlapping basket | Two US mid-cap index implementations |
| 206 | `A06_QQQ_XLK` | QQQ-XLK | ETF-ETF | common factor | Growth-heavy Nasdaq versus US technology |
| 207 | `A07_TLT_IEF` | TLT-IEF | ETF-ETF | curve linkage | Long- versus intermediate-duration Treasuries |
| 208 | `A08_HYG_LQD` | HYG-LQD | ETF-ETF | credit linkage | High-yield versus investment-grade corporate credit |
| 209 | `A09_XBI_IBB` | XBI-IBB | ETF-ETF | overlapping basket | Differently weighted biotechnology portfolios |
| 210 | `A10_ITA_XAR` | ITA-XAR | ETF-ETF | overlapping basket | Differently weighted aerospace and defense portfolios |
| 211 | `A11_XLE_XOM` | XLE-XOM | ETF-component | constituent containment | Energy-sector basket versus a large component |
| 212 | `A12_XLF_JPM` | XLF-JPM | ETF-component | constituent containment | Financial-sector basket versus a large component |
| 213 | `A13_XLV_JNJ` | XLV-JNJ | ETF-component | constituent containment | Health-care basket versus a diversified component |
| 214 | `A14_XLP_PG` | XLP-PG | ETF-component | constituent containment | Staples basket versus a large component |
| 215 | `A15_SMH_NVDA` | SMH-NVDA | ETF-component | constituent containment | Semiconductor basket versus a major component |
| 216 | `A16_KO_PEP` | KO-PEP | stock-stock | peer economics | Global non-alcoholic beverage peers |
| 217 | `A17_V_MA` | V-MA | stock-stock | peer economics | Global card-network peers |
| 218 | `A18_HD_LOW` | HD-LOW | stock-stock | peer economics | US home-improvement retail peers |
| 219 | `A19_JPM_BAC` | JPM-BAC | stock-stock | peer economics | Diversified US bank peers |
| 220 | `A20_UPS_FDX` | UPS-FDX | stock-stock | peer economics | Global parcel-delivery peers |
| 221 | `A21_GDX_GLD` | GDX-GLD | producer/asset proxy | shared commodity driver | Gold miners versus physical gold |
| 222 | `A22_XLE_USO` | XLE-USO | producer/asset proxy | shared commodity driver | Energy equities versus oil-futures proxy |
| 223 | `A23_SIL_SLV` | SIL-SLV | producer/asset proxy | shared commodity driver | Silver miners versus physical silver |
| 224 | `A24_FCX_CPER` | FCX-CPER | producer/asset proxy | shared commodity driver | Copper producer versus copper-futures proxy |
| 225 | `A25_XOP_USO` | XOP-USO | producer/asset proxy | shared commodity driver | Oil-and-gas producers versus oil-futures proxy |

Some pairs intentionally overlap prior panels as anchors. Atlas results are
reported as a separate sequential batch and are not pooled into a single
discovery p-value.

## Unchanged Pair Mechanics

Every candidate uses the exact `LIT-MR-02.1` rule:

- Alpaca adjusted daily OHLCV;
- explicit as-of `2026-07-24 17:30:00`;
- 20-session rolling OLS of \(Y\) on \(X\);
- raw-price spread \(S_t=Y_t-\beta_tX_t\);
- 20-session rolling spread z-score;
- long spread below \(-1z\), short spread above \(+1z\);
- exit at the zero crossing;
- signal after close and execute at next open;
- daily causal rehedging, one gross-normalized unit;
- 5 bp per one-way weight change plus the existing stress-cost diagnostic; and
- the same seeded inference and eight TRAIN gates.

Changing the lookback, transform, entry, exit, costs, orientation, or gates
would require `LIT-MR-02.2` or another substantive variant.

## Partitions And Leakage Boundary

- TRAIN: `2016-01-04` through `2020-12-31`.
- DEVELOPMENT: `2021-01-01` through `2023-12-29`.
- CONFIRMATION: begins `2024-01-01` and remains sealed.

All 25 identities, orientations, categories, rationales, mechanics, seeds, and
gates are frozen before TRAIN outcomes.

1. Query and analyze TRAIN only for all candidates.
2. If no candidate passes all eight gates, stop without requesting later bars.
3. If one or more pass, select the first full pass in frozen registry order.
4. Freeze that identity and run only its unchanged causal rule in DEVELOPMENT.
5. Report DEVELOPMENT without replacing the selected pair, changing mechanics,
   or opening CONFIRMATION.

The first-pass rule is a deterministic tie-break, not a claim that earlier
registry entries are economically superior.

## TRAIN Gates

The exact eight `LIT-MR-02.1` gates remain:

1. integrity;
2. at least 95% positive-beta coverage;
3. at least 30 completed trades with at least 10 in each direction;
4. positive primary-cost mean net trade return with a 95% moving-block
   bootstrap lower bound above zero;
5. completed-trade hit rate above 50%;
6. observed mean net return above matched random-sign p90;
7. positive primary-cost return in at least three of five TRAIN years; and
8. negative z-score/forward-five-session spread-return correlation with the
   95% bootstrap upper bound below zero.

The literature motivates the mechanics and several evaluation concepts. This
exact checklist and its thresholds are Gen5-designed.

## Conditional DEVELOPMENT Readout

If TRAIN nominates a pair, DEVELOPMENT reports:

- completed trades and direction counts;
- bar-by-bar cumulative primary- and stress-cost return;
- naive and autocorrelation-adjusted Sharpe;
- maximum drawdown;
- mean net trade return and hit rate; and
- z-score/forward-five-session convergence correlation.

These are OOS observations, not a new optimization target. No DEVELOPMENT
threshold can cause a replacement pair to be selected from TRAIN.

## Stop States

- No full TRAIN pass:
  `STOP_LIT_MR_02_1_RELATIONSHIP_ATLAS_01_NO_FULL_PASS`.
- TRAIN pass and DEVELOPMENT opened:
  `OOS_DEVELOPMENT_COMPLETE_LIT_MR_02_1_RELATIONSHIP_ATLAS_01`.

Neither state authorizes CONFIRMATION, allocation, live shorting, provider
expansion, or live behavior.
