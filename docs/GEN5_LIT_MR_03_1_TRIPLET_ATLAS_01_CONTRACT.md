# LIT-MR-03.1 Triplet Atlas 01 Contract

## Status

`OOS_DEVELOPMENT_COMPLETE`

This is a higher-throughput instance batch under the unchanged
`LIT-MR-03.1` daily Johansen triplet mechanics. It is not a new strategy
revision. The original eight-triplet batch and its
`STOP_LIT_MR_03_1_NO_TRAIN_NOMINATION` result remain immutable.

## Completed Readout

The frozen atlas completed with
`OOS_DEVELOPMENT_COMPLETE_LIT_MR_03_1_TRIPLET_ATLAS_01`.

- All 78 required symbols passed requested 2016-2020 TRAIN coverage after the
  explicit refresh.
- Ten of 28 triplets passed the exact-rank-one diagnostic.
- One triplet, `A25_EWA_EWC_EWZ`, cleared all eight TRAIN gates.
- Its TRAIN vector was
  \(\left[1,-0.6476169,-0.0628629\right]\), with vector cosine `0.9986`,
  half-life `8.33` sessions, 89 completed trades, mean primary-cost return
  `+17.68 bp/trade`, 95% lower bound `+1.81 bp`, and robust forward
  convergence.
- The identity and vector were frozen before the single 2021-2023
  DEVELOPMENT replay.
- DEVELOPMENT produced 57 completed trades, mean primary-cost return
  `+8.50 bp/trade`, `71.9%` hit rate, cumulative return `+3.73%`, naive
  Sharpe `0.283`, autocorrelation-adjusted Sharpe `0.317`, and maximum
  drawdown `-5.88%`.
- At the 10 bp stress cost, DEVELOPMENT cumulative return was `-3.23%`.
- CONFIRMATION beginning 2024 remains sealed.

The data-health `WARN` records that bounded historical queries ending in 2020
or 2023 are stale relative to the explicit 2026 as-of timestamp. Requested
TRAIN and DEVELOPMENT coverage passed; these WARNs do not represent missing
bars inside either requested window.

The generated packet is
`runs/research_workbench/literature_grounded/lit_mr_03_1_triplet_atlas_01_20260729`.

## Research Question

Can a transparent economic-relationship generator produce a finite,
category-balanced set of triplet hypotheses, and does any predeclared triplet
clear all eight TRAIN gates strongly enough to justify one genuinely OOS
DEVELOPMENT replay with a frozen cointegrating vector?

The atlas demonstrates disciplined breadth. It does not keep adding triplets
until one works, rank candidates by observed return, or treat TRAIN replay as
historical strategy performance.

## Frozen Generator

The generator combines an instrument topology with an economic mechanism:

1. near-substitute ETFs linked by overlapping claims;
2. sector or industry ETF triangles linked by common constituents;
3. duration or credit structures linked by a shared yield curve;
4. a sector basket and two longstanding companies from that economic domain;
5. a commodity exposure and related producer or service equities;
6. three operating-company peers; and
7. three country ETFs with a shared regional or macro sensitivity.

The country/macro cell is explicitly softer than duplicate-claim or
term-structure cells. Categories organize hypotheses; they do not imply equal
prior probability of cointegration.

Four candidates are frozen in each cell. Symbol order is the coefficient
normalization order.

| Index | Triplet ID | Symbols | Category | Ex-ante rationale |
|---:|---|---|---|---|
| 101 | `A01_GLD_IAU_SGOL` | GLD, IAU, SGOL | ETF near substitute | Three physically backed gold exposures |
| 102 | `A02_MDY_IJH_VO` | MDY, IJH, VO | ETF near substitute | Three broad US mid-cap implementations |
| 103 | `A03_IWM_IJR_VB` | IWM, IJR, VB | ETF near substitute | Three broad US smaller-company implementations |
| 104 | `A04_EEM_IEMG_VWO` | EEM, IEMG, VWO | ETF near substitute | Three broad emerging-market equity implementations |
| 105 | `A05_XLK_VGT_QQQ` | XLK, VGT, QQQ | Sector/industry triangle | Technology and growth-heavy US equity baskets |
| 106 | `A06_XBI_IBB_BBH` | XBI, IBB, BBH | Sector/industry triangle | Differently weighted biotechnology portfolios |
| 107 | `A07_ITA_XAR_PPA` | ITA, XAR, PPA | Sector/industry triangle | Differently weighted aerospace and defense portfolios |
| 108 | `A08_XLF_KBE_KRE` | XLF, KBE, KRE | Sector/industry triangle | Broad financials, banks, and regional banks |
| 109 | `A09_SHV_IEI_TLH` | SHV, IEI, TLH | Term/credit structure | Short, intermediate, and long Treasury duration |
| 110 | `A10_VGSH_VGIT_VGLT` | VGSH, VGIT, VGLT | Term/credit structure | Vanguard short, intermediate, and long Treasuries |
| 111 | `A11_BIL_IEF_TLT` | BIL, IEF, TLT | Term/credit structure | Treasury bill, intermediate, and long Treasury exposures |
| 112 | `A12_VCSH_VCIT_VCLT` | VCSH, VCIT, VCLT | Term/credit structure | Short, intermediate, and long corporate bonds |
| 113 | `A13_XLK_AAPL_MSFT` | XLK, AAPL, MSFT | Basket/components | Technology basket and two longstanding technology leaders |
| 114 | `A14_XLE_XOM_CVX` | XLE, XOM, CVX | Basket/components | Energy basket and two integrated oil majors |
| 115 | `A15_XLP_PG_KO` | XLP, PG, KO | Basket/components | Staples basket and two longstanding consumer franchises |
| 116 | `A16_XLY_AMZN_HD` | XLY, AMZN, HD | Basket/components | Consumer-discretionary basket and two major domain companies |
| 117 | `A17_GLD_GDX_GDXJ` | GLD, GDX, GDXJ | Commodity/production chain | Physical gold, large miners, and junior miners |
| 118 | `A18_SLV_SIL_GDX` | SLV, SIL, GDX | Commodity/production chain | Physical silver, silver miners, and diversified precious-metal miners |
| 119 | `A19_CPER_FCX_SCCO` | CPER, FCX, SCCO | Commodity/production chain | Copper-futures proxy and two copper producers |
| 120 | `A20_USO_OIH_XES` | USO, OIH, XES | Commodity/production chain | Oil-futures proxy and two oil-service baskets |
| 121 | `A21_V_MA_AXP` | V, MA, AXP | Stock-peer triangle | Three large payment networks and card franchises |
| 122 | `A22_KO_PEP_MNST` | KO, PEP, MNST | Stock-peer triangle | Three non-alcoholic beverage companies |
| 123 | `A23_HD_LOW_TSCO` | HD, LOW, TSCO | Stock-peer triangle | Three US home and rural-improvement retailers |
| 124 | `A24_UPS_FDX_CHRW` | UPS, FDX, CHRW | Stock-peer triangle | Parcel delivery and freight-logistics peers |
| 125 | `A25_EWA_EWC_EWZ` | EWA, EWC, EWZ | Country/macro triangle | Commodity-sensitive Australian, Canadian, and Brazilian equities |
| 126 | `A26_EWG_EWI_EWP` | EWG, EWI, EWP | Country/macro triangle | Large euro-area country equity exposures |
| 127 | `A27_EWJ_EWY_EWT` | EWJ, EWY, EWT | Country/macro triangle | Asian manufacturing and export-oriented equity exposures |
| 128 | `A28_EWW_EWZ_ECH` | EWW, EWZ, ECH | Country/macro triangle | Large Latin American country equity exposures |

The registry is finite and immutable after this contract is recorded.
Repeated symbols and conceptual anchors are visible; results are not pooled
with the original eight-triplet batch.

## Unchanged Mechanics And Gates

Every candidate uses the exact `LIT-MR-03.1` contract:

- Alpaca adjusted daily OHLCV;
- explicit as-of `2026-07-24 17:30:00`;
- 2016-2020 TRAIN only for selection;
- price-level, one-lag Johansen/VECM with a constant;
- 1,000 seeded rank-null simulations;
- exactly rank one;
- TRAIN-frozen leading vector, first coefficient normalized to one;
- 20-session spread z-score;
- long below `-1`, short above `+1`, zero-crossing exit;
- after-close signal and next-open execution;
- daily price-converted, gross-normalized dollar weights;
- 5 bp per one-way weight change and 10 bp stress cost; and
- the same eight-gate conjunction covering integrity, I(1), rank, vector
  stability, half-life, two-sided support, cost-aware return, and robust
  forward convergence.

Changing the rank interpretation, lag, bootstrap, window, entry, exit, costs,
vector normalization, thresholds, or gates would require a substantive new
revision and cannot be justified from this atlas's inspected outcomes.

## Leakage-Safe Sequence

1. Query and analyze only 2016-2020 TRAIN for all 28 triplets.
2. Report every candidate in frozen registry order and by frozen category.
3. If no candidate passes all eight gates, stop without querying later
   strategy outcomes.
4. If one or more pass, nominate the first full pass in frozen registry order.
5. Freeze that identity and its full-TRAIN vector.
6. Query and replay only the nominated triplet through 2021-2023 DEVELOPMENT.
7. Report the single OOS replay without replacement, refitting, or mechanical
   changes.
8. Keep 2024+ CONFIRMATION sealed in every case.

Registry order is a deterministic tie-break, not an economic ranking.

## Multiplicity And Interpretation

Twenty-eight simultaneous screens create more opportunities for chance
diagnostic passes than the original eight-triplet batch. The eight-gate
conjunction and one-shot OOS replay reduce that risk but do not constitute a
formal family-wise-error correction.

Therefore:

- a TRAIN full pass authorizes one OOS test; it is not validation;
- a category with several attractive TRAIN point estimates is descriptive;
- the best failed candidate cannot be selected;
- DEVELOPMENT cannot choose a replacement; and
- confirmation, allocation, and live behavior remain closed.

## Stop States

- No full TRAIN pass:
  `STOP_LIT_MR_03_1_TRIPLET_ATLAS_01_NO_FULL_PASS`.
- TRAIN nomination and one OOS replay completed:
  `OOS_DEVELOPMENT_COMPLETE_LIT_MR_03_1_TRIPLET_ATLAS_01`.

Neither state authorizes intraday data, portfolio allocation, live shorting,
provider expansion, or live behavior.
