# LIT-MR-03.2 Graded-Evidence Triplet Reversion Contract

## Status

`FROZEN_BEFORE_IMPLEMENTATION`

## Research Question

Does the unchanged `LIT-MR-03.1` daily Johansen triplet rule produce credible
candidates when vector stability, half-life, support, and uncertainty
thresholds are eased in a measured, predeclared way while I(1) and exact-rank-
one structure remain mandatory?

## Unchanged Trading Mechanics

- Alpaca adjusted daily OHLCV with explicit as-of
  `2026-07-24 17:30:00`;
- 2016-2020 TRAIN and 2021-2023 DEVELOPMENT;
- price-level one-lag Johansen/VECM with a constant;
- 1,000 seeded rank-null simulations;
- exactly one cointegrating relation;
- TRAIN-frozen leading vector, first coefficient normalized to one;
- 20-session spread z-score;
- long below `-1`, short above `+1`, exit at zero;
- after-close signal and next-open execution;
- daily gross-normalized dollar weights;
- 5 bp per one-way weight change and 10 bp stress cost; and
- no confirmation data beginning 2024.

## Frozen Admission Rules

All eight are mandatory:

1. every integrity, chronology, accounting, and mixed-sign-vector check passes;
2. every component satisfies the unchanged frozen I(1) diagnostic;
3. the seeded Johansen bootstrap supports exactly rank one;
4. split-TRAIN dollar-exposure cosine similarity is at least 0.80;
5. spread half-life is between 2 and 90 sessions;
6. at least 24 completed trades, including at least eight in each direction;
7. mean primary-cost completed-trade return is positive and its 10th
   moving-block-bootstrap percentile is above zero; and
8. z-score versus forward-five-session frozen-vector return has a negative
   correlation and its 90th bootstrap percentile is below zero.

All seeds, bootstrap counts, block lengths, costs, Johansen settings, and trade
mechanics remain unchanged from `03.1`.

## Retrospective Lane

The retrospective registry contains all eight original triplets followed by
all 28 Triplet Atlas 01 instances. Every relaxed-gate survivor receives a
2021-2023 descriptive replay.

No survivor is nominated or treated as a discovery. The exercise is
explicitly post-hoc because the challenger thresholds were designed after
inspecting these families.

## Fresh Triplet Atlas 01

Twenty candidates are frozen in five balanced categories:

| Index | Triplet ID | Symbols | Category | Ex-ante rationale |
|---:|---|---|---|---|
| 201 | `F01_VTI_SCHB_ITOT` | VTI, SCHB, ITOT | ETF near substitute | Total-US-market implementations |
| 202 | `F02_VOO_IVV_SPLG` | VOO, IVV, SPLG | ETF near substitute | S&P 500 implementations |
| 203 | `F03_SCHF_VEA_IEFA` | SCHF, VEA, IEFA | ETF near substitute | Developed-markets ex-US implementations |
| 204 | `F04_SCHD_VYM_HDV` | SCHD, VYM, HDV | ETF near substitute | Dividend-oriented US equity portfolios |
| 205 | `F05_XSD_SOXX_SMH` | XSD, SOXX, SMH | Sector/industry triangle | Differently weighted semiconductor portfolios |
| 206 | `F06_XPH_PJP_IHE` | XPH, PJP, IHE | Sector/industry triangle | Differently weighted pharmaceutical portfolios |
| 207 | `F07_KIE_IAK_XLF` | KIE, IAK, XLF | Sector/industry triangle | Insurance portfolios with a broad financial anchor |
| 208 | `F08_XME_PICK_REMX` | XME, PICK, REMX | Sector/industry triangle | Mining portfolios with different commodity emphasis |
| 209 | `F09_SHY_VGSH_SPTS` | SHY, VGSH, SPTS | Term/credit structure | Short Treasury portfolios |
| 210 | `F10_IEI_VGIT_SPTI` | IEI, VGIT, SPTI | Term/credit structure | Intermediate Treasury portfolios |
| 211 | `F11_TLT_VGLT_SPTL` | TLT, VGLT, SPTL | Term/credit structure | Long Treasury portfolios |
| 212 | `F12_LQD_VCIT_IGIB` | LQD, VCIT, IGIB | Term/credit structure | Investment-grade corporate bond portfolios |
| 213 | `F13_XLI_CAT_DE` | XLI, CAT, DE | Basket/components | Industrials basket and heavy-equipment leaders |
| 214 | `F14_XLK_MSFT_ORCL` | XLK, MSFT, ORCL | Basket/components | Technology basket and mature software leaders |
| 215 | `F15_XLP_KO_PEP` | XLP, KO, PEP | Basket/components | Staples basket and beverage leaders |
| 216 | `F16_XLV_UNH_ELV` | XLV, UNH, ELV | Basket/components | Health-care basket and managed-care leaders |
| 217 | `F17_XOM_CVX_COP` | XOM, CVX, COP | Stock-peer triangle | Large oil and gas producers |
| 218 | `F18_CAT_DE_CMI` | CAT, DE, CMI | Stock-peer triangle | Heavy-equipment and engine manufacturers |
| 219 | `F19_WMT_TGT_COST` | WMT, TGT, COST | Stock-peer triangle | Large US general-merchandise retailers |
| 220 | `F20_UNP_CSX_NSC` | UNP, CSX, NSC | Stock-peer triangle | Large US freight railroads |

The registry, symbol order, category, rationale, and index order are immutable
after this document is recorded.

## Leakage-Safe Fresh Sequence

1. Query and analyze only 2016-2020 TRAIN for all 20 triplets.
2. Report strict `03.1` and relaxed `03.2` status side by side.
3. If none passes all eight relaxed rules, stop.
4. Otherwise nominate the first relaxed pass in registry order.
5. Freeze its identity and full-TRAIN vector.
6. Query and replay only that triplet through 2021-2023 DEVELOPMENT.
7. Do not replace, refit, or alter mechanics after OOS inspection.
8. Keep 2024+ sealed.

## Stop States

- `STOP_LIT_MR_03_2_FRESH_ATLAS_01_NO_PASS`
- `OOS_DEVELOPMENT_COMPLETE_LIT_MR_03_2_FRESH_ATLAS_01`

Neither state authorizes portfolio or live behavior.
