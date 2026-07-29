# LIT-MR-02.2 Graded-Evidence Pair Reversion Contract

## Status

`FROZEN_BEFORE_IMPLEMENTATION`

## Research Question

Does the unchanged `LIT-MR-02.1` rolling-beta Bollinger pair rule produce
credible candidates when uncertainty is assessed with one-sided 90% bootstrap
bounds, while hit rate and calendar-year consistency are treated as
diagnostics rather than vetoes?

## Unchanged Trading Mechanics

- Alpaca adjusted daily OHLCV with explicit as-of
  `2026-07-24 17:30:00`;
- 2016-2020 TRAIN and 2021-2023 DEVELOPMENT;
- raw adjusted prices;
- 20-session rolling OLS hedge ratio and spread z-score;
- long spread below `-1`, short spread above `+1`, exit at zero;
- after-close signal and next-open execution;
- daily gross-normalized dollar rehedging;
- 5 bp per one-way weight change and 10 bp stress cost; and
- no confirmation data beginning 2024.

## Frozen Admission Rules

All six are mandatory:

1. every integrity, timing, partition, and accounting check passes;
2. rolling beta is positive on at least 95% of eligible TRAIN sessions;
3. at least 24 completed trades, including at least eight long-spread and eight
   short-spread trades;
4. mean primary-cost completed-trade return is positive and the 10th
   percentile of the seeded moving-block bootstrap is above zero;
5. observed mean return exceeds the unchanged matched random-sign p90; and
6. z-score versus forward-five-session spread return has a negative
   correlation and the 90th bootstrap percentile is below zero.

Completed-trade hit rate and the number of positive TRAIN calendar years are
reported diagnostics. They do not admit or reject a candidate.

Bootstrap draw counts, block lengths, seeds, costs, and the random-sign null
remain unchanged from `02.1`.

## Retrospective Lane

The retrospective registry is the deterministic union of:

1. the canonical pair;
2. PANEL A primary pairs;
3. PANEL B;
4. RELATIONSHIP ATLAS 01.

Exact unordered symbol-pair duplicates are removed by first occurrence in that
order, leaving 44 unique prior pairs from 53 named instances. Orientation is
preserved from the retained first occurrence.

Every relaxed-gate survivor receives a 2021-2023 descriptive replay. No
survivor is nominated, ranked into authority, or treated as a discovery.

## Fresh Pair Atlas 01

Twenty candidates are frozen in five balanced categories:

| Index | Pair ID | Y | X | Category | Ex-ante rationale |
|---:|---|---|---|---|---|
| 301 | `F01_SCHX_VOO` | SCHX | VOO | broad ETF substitute | Broad US large-cap implementations |
| 302 | `F02_SCHB_VTI` | SCHB | VTI | broad ETF substitute | Broad total-US-market implementations |
| 303 | `F03_SPTM_ITOT` | SPTM | ITOT | broad ETF substitute | Broad investable US equity implementations |
| 304 | `F04_SCHF_VEA` | SCHF | VEA | broad ETF substitute | Developed-markets ex-US implementations |
| 305 | `F05_SCHD_VYM` | SCHD | VYM | factor/style ETF | Dividend-oriented US equity portfolios |
| 306 | `F06_SPLV_USMV` | SPLV | USMV | factor/style ETF | Low-volatility US equity portfolios |
| 307 | `F07_IUSV_VTV` | IUSV | VTV | factor/style ETF | Broad US value portfolios |
| 308 | `F08_IUSG_VUG` | IUSG | VUG | factor/style ETF | Broad US growth portfolios |
| 309 | `F09_XME_PICK` | XME | PICK | industry ETF | Metals and mining equity portfolios |
| 310 | `F10_KIE_IAK` | KIE | IAK | industry ETF | US insurance equity portfolios |
| 311 | `F11_XSD_SOXX` | XSD | SOXX | industry ETF | Differently weighted semiconductor portfolios |
| 312 | `F12_XPH_PJP` | XPH | PJP | industry ETF | Differently weighted pharmaceutical portfolios |
| 313 | `F13_SHY_VGSH` | SHY | VGSH | term/credit | Short Treasury portfolios |
| 314 | `F14_IEI_VGIT` | IEI | VGIT | term/credit | Intermediate Treasury portfolios |
| 315 | `F15_TLT_VGLT` | TLT | VGLT | term/credit | Long Treasury portfolios |
| 316 | `F16_VCIT_LQD` | VCIT | LQD | term/credit | Investment-grade corporate bond portfolios |
| 317 | `F17_XOM_CVX` | XOM | CVX | stock peer | Integrated oil majors |
| 318 | `F18_CAT_DE` | CAT | DE | stock peer | Global heavy-equipment manufacturers |
| 319 | `F19_WMT_TGT` | WMT | TGT | stock peer | Large US general-merchandise retailers |
| 320 | `F20_UNP_CSX` | UNP | CSX | stock peer | Large US freight railroads |

The registry, orientation, order, categories, and rationales are immutable
after this document is recorded.

## Leakage-Safe Fresh Sequence

1. Query and analyze only 2016-2020 TRAIN for all 20 pairs.
2. Report strict `02.1` and relaxed `02.2` status side by side.
3. If none passes all six relaxed rules, stop.
4. Otherwise nominate the first relaxed pass in registry order.
5. Query only that pair through 2021-2023 DEVELOPMENT.
6. Replay once without replacement or mechanical changes.
7. Keep 2024+ sealed.

## Stop States

- `STOP_LIT_MR_02_2_FRESH_ATLAS_01_NO_PASS`
- `OOS_DEVELOPMENT_COMPLETE_LIT_MR_02_2_FRESH_ATLAS_01`

Neither state authorizes portfolio or live behavior.
