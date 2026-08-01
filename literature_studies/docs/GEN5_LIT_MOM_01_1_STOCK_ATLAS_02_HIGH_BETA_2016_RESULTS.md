# LIT-MOM-01.1 Stock Atlas 02 High-Beta 2016 Results

Status: `OOS_DEVELOPMENT_COMPLETE_STOP_RECOMMENDED`

## Question

Does the unchanged Chapter 6 horizon-screen-plus-sleeve mechanism recur more
often among stocks that were demonstrably high beta before TRAIN?

This is a point-in-time replication of `LIT-MOM-01.1`, not a new strategy
variant. It uses all 99 common-equity constituents in SPHB's SEC Schedule of
Investments dated October 31, 2016. No name was chosen because its later price
path looked exciting.

## Why this panel is materially better than a remembered high-beta list

The filing establishes what the fund actually held before the January 2017
TRAIN window. The registry includes later acquisitions, delistings, ticker
changes, and bankruptcies rather than silently reconstructing a survivor-only
universe.

The source is SEC EDGAR accession `0001193125-17-002614`, SPHB pages 50–51:

<https://www.sec.gov/Archives/edgar/data/1378872/000119312517002614/d269293dncsr.htm>

The source panel is concentrated: 32 Financials and 25 Energy names account
for 57 of 99 holdings. That concentration existed before testing and remains
part of the result.

## Beta is not momentum

Beta is a market-sensitivity estimate:

`beta_i = Cov(r_i, r_SPY) / Var(r_SPY)`

Time-series momentum asks a different question: does the sign and magnitude
of a stock's own trailing return contain information about its subsequent
return? High beta can amplify both persistent and reversing moves.

As a pre-TRAIN descriptive check, 97 names had enough 2016 adjusted-daily
history to estimate beta against SPY. Median beta was 1.70, mean beta 1.75,
and 96 of 97 estimates exceeded 1. This supports the intended panel identity;
it does not select members or prove momentum.

## Coverage

- Frozen filing registry: `99` stocks.
- Finite pre-TRAIN beta estimates: `97 / 99`.
- Exact January 2016–December 2020 warm-up-plus-TRAIN coverage: `84 / 99`.
- Coverage stops: `15 / 99`, all retained in the audit.
- Exact 2021–2023 DEVELOPMENT coverage among six-gate passers: `10 / 11`.

`XEC` passed TRAIN but its history ends September 30, 2021 after its
acquisition. It therefore receives `DEVELOPMENT_COVERAGE_STOP`; no shortened
OOS window or successor ticker is substituted.

The 15 TRAIN coverage stops are `DLPH, HAR, APC, BHI, FTI, NFX, NBL, TSO,
ETFC, LM, STI, CELG, ARNC, CBG, LVLT`. Their missing history is a retail-data
feasibility result, not an outcome-driven deletion.

## TRAIN breadth

Eleven of 84 analyzable stocks passed all six gates: `XEC, DVN, HAL, HP, MRO,
MPC, AMP, CMA, IVZ, STT, ZION`. Ten selected either `5/5` or `10/10`; `HP`
selected `1/10`.

| Gate | Pass count | Interpretation |
|---|---:|---|
| G1 integrity and causal timing | 84 / 84 | The implementation contract held. |
| G2 horizon-screen admissibility | 29 / 84 | Positive nominally significant correlation remained selective. |
| G3 independent-outcome and sleeve support | 80 / 84 | Most selected short horizons had adequate support. |
| G4 direction accuracy above 50% | 58 / 84 | Sign prediction often looked better than chance in TRAIN. |
| G5 positive primary return and adjusted Sharpe | 43 / 84 | Roughly half had positive cost-aware TRAIN economics. |
| G6 positive stress return and three positive years | 22 / 84 | Cost and time stability remained the tightest economic gate. |

The full-pass rate was `13.1%` (`11/84`), versus `4.5%` (`1/22`) in the static
balanced Stock Atlas 01. This is descriptive enrichment, not proof that beta
causes momentum: the panels differ in date-validity, sector composition, and
membership construction.

## OOS DEVELOPMENT: all ten complete replays lost money

| Symbol | Frozen L/H | OOS correlation | Direction accuracy | Primary return | Stress return |
|---|---:|---:|---:|---:|---:|
| DVN | 5/5 | -0.0889 | 48.0% | -61.84% | -64.97% |
| HAL | 10/10 | +0.0683 | 58.7% | -12.85% | -16.63% |
| HP | 1/10 | -0.0503 | 47.1% | -48.16% | -50.31% |
| MRO | 10/10 | -0.0010 | 53.3% | -39.14% | -41.84% |
| MPC | 1/5 | -0.0116 | 50.9% | -1.76% | -9.40% |
| AMP | 10/10 | -0.1110 | 48.0% | -21.55% | -24.96% |
| CMA | 10/10 | +0.0538 | 44.0% | -18.20% | -21.97% |
| IVZ | 5/5 | -0.0457 | 49.3% | -4.13% | -11.57% |
| STT | 5/5 | +0.0342 | 54.7% | -9.52% | -16.34% |
| ZION | 10/10 | -0.0130 | 46.7% | -55.37% | -57.56% |

No OOS replay had a positive primary or stress cumulative return. Mean primary
return was -27.25%, median primary return -19.87%, and the median directional
accuracy was 48.7%. Four of ten had direction accuracy above 50%, but none
cleared all four descriptive continuity flags.

## Up-versus-down prediction explains the failure

Across the ten complete OOS replays:

| Sleeve direction | Sleeves | Pooled direction accuracy | Pooled mean primary-net sleeve return | Stocks above 50% accuracy |
|---|---:|---:|---:|---:|
| Long | 4,066 | 54.28% | +0.53% | 9 / 10 |
| Short | 3,362 | 43.04% | -1.28% | 0 / 10 |

The signal classified subsequent up moves materially better than down moves.
The symmetric long/short rule consequently accumulated damaging short sleeves.
This is exactly why reporting a single hit rate is insufficient: prediction
quality is direction-dependent, and payoff magnitude differs from accuracy.

This observation does **not** authorize dropping the short side after seeing
OOS. A long-only translation would be a new strategy mechanic and needs a new
variant, fresh contract, and untouched evidence window.

## Decision

Record:

`OOS_DEVELOPMENT_COMPLETE_LIT_MOM_01_1_STOCK_ATLAS_02_HIGH_BETA_2016`

Recommend:

`STOP_STOCK_ATLAS_02_HIGH_BETA_2016_BEFORE_CONFIRMATION`

The point-in-time panel produced more TRAIN passers than the static balanced
atlas, but none retained positive OOS economics. Keep 2024+ CONFIRMATION
sealed. Do not rescue the result by deleting short sleeves, selecting MPC as
the least-negative path, repairing acquired names with successor tickers,
changing horizons, or pooling the ten strategies.

## Evidence

- Authoritative packet:
  `runs/research_workbench/literature_grounded/lit_mom_01_1_stock_atlas_02_high_beta_2016_20260731/`
- Frozen registry:
  `literature_studies/registries/gen5_lit_mom_01_1_stock_atlas_02_high_beta_2016_registry.csv`
- Contract:
  `literature_studies/docs/GEN5_LIT_MOM_01_1_STOCK_ATLAS_02_HIGH_BETA_2016_CONTRACT.md`
- Evidence deck:
  `literature_studies/presentations/gen5_lit_mom_01_1_stock_atlas_02_high_beta_2016_evidence.pptx`
