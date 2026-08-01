# LIT-MOM-01.1 Stock Atlas 01 Results

Status: `OOS_DEVELOPMENT_COMPLETE_STOP_RECOMMENDED`

## Question

Does Chan's Chapter 6 horizon-screen-plus-sleeve workflow recur across a
balanced panel of individual U.S. stocks when every stock is evaluated under
the same frozen TRAIN and DEVELOPMENT protocol?

This is a breadth replication of `LIT-MOM-01.1`, not a stock-selection model.
The atlas contains 22 large, liquid stocks, exactly two from each of the eleven
broad sectors. The static July 2026 registry has survivor and membership bias;
it is a textbook demonstration, not a historical point-in-time universe.

## Frozen method

Each stock independently received the same 49-cell
`L,H in {1,5,10,25,60,120,250}` TRAIN screen, the same deterministic
selection rule, causal `1/H` next-open sleeves, costs, and six conjunctive
gates as the SHY exercise. `250/25` remained a side-by-side canonical
reference. Only a full six-gate TRAIN pass could open the frozen 2021-2023
DEVELOPMENT window, and every such passer had to be shown.

The panel did not choose a common horizon, delete failures, rank an OOS
winner, or form a portfolio.

## Coverage

All 22 stocks and the SPY session reference contain exactly 2,012 requested
sessions from January 4, 2016 through December 29, 2023. No requested session
is missing. The generic workbench health file reports `stale_symbol` because
the deliberately bounded historical query ends before the July 2026 as-of
date; it does not indicate a hole in the requested evidence window.

## TRAIN breadth

Only `HD` passed all six gates:

| Gate | Pass count | Interpretation |
|---|---:|---|
| G1 integrity and causal timing | 22 / 22 | Infrastructure and timing held throughout. |
| G2 horizon-screen admissibility | 3 / 22 | The dominant stop: 19 selected rows lacked the required positive, nominally significant correlation. |
| G3 statistical and sleeve support | 20 / 22 | Two long-horizon selections lacked enough sparse pairs. |
| G4 direction accuracy above 50% | 18 / 22 | Up/down prediction often looked better than chance in TRAIN. |
| G5 positive primary return and adjusted Sharpe | 14 / 22 | Positive P&L was materially more common than a valid source-style correlation screen. |
| G6 positive stress return and calendar stability | 7 / 22 | Cost and time stability eliminated half of the G5 passers. |

This pattern matters. A profitable backtest is not automatically evidence for
the proposed momentum mechanism. For example, `MSFT` produced a +75.16%
selected-horizon TRAIN return and 75.0% direction accuracy, but its selected
past/future correlation was slightly negative (`r=-0.0172`, nominal
`p=0.9160`). It therefore stopped at G2 rather than being promoted because its
equity curve looked attractive.

`HD` selected `10/10` and produced:

| Diagnostic | HD TRAIN |
|---|---:|
| Chan-min-step pairs | 100 |
| Past/future return correlation | 0.1833 |
| Nominal Pearson p-value | 0.0679 |
| Past-sign/future-sign accuracy | 61.0% |
| Completed sleeves | 995 |
| Primary cumulative return | +41.00% |
| Autocorrelation-adjusted Sharpe | 0.49 |
| Primary maximum drawdown | -24.73% |
| Stress cumulative return | +33.44% |
| Positive calendar years | 3 of 4 |

## OOS DEVELOPMENT: HD 10/10

The sole authorized replay retained a positive correlation and above-chance
direction accuracy, but not positive economics:

| Diagnostic | HD 2021-2023 OOS |
|---|---:|
| Chan-min-step pairs | 75 |
| Past/future return correlation | 0.1830 |
| Nominal Pearson p-value | 0.1160 |
| Past-sign/future-sign accuracy | 58.67% |
| Completed sleeves | 741 |
| Primary cumulative return | -5.86% |
| Autocorrelation-adjusted Sharpe | -0.03 |
| Primary maximum drawdown | -29.94% |
| Stress cumulative return | -9.82% |

Long sleeves averaged +0.45% after primary costs with 58.1% directional
accuracy; short sleeves averaged -0.68% with 44.8% accuracy. Calendar returns
were -5.39% in 2021, -14.59% in 2022, and +16.50% in 2023.

The signal retained some ability to classify the sign of sparse future
10-session returns, yet the fully traded daily-sleeve strategy lost money.
That is not contradictory: hit rate ignores payoff asymmetry, turnover, path
dependence, and the difference between sparse diagnostic pairs and the many
overlapping traded sleeves. Here the short side was especially damaging.

## Decision

Record:

`OOS_DEVELOPMENT_COMPLETE_LIT_MOM_01_1_STOCK_ATLAS_01`

Recommend:

`STOP_STOCK_ATLAS_01_BEFORE_CONFIRMATION`

The breadth exercise did what it was supposed to do. It found only one full
TRAIN passer without cherry-picking, opened exactly that OOS path, and showed
that directional persistence did not translate into cost-aware P&L. Do not
rescue the result by selecting MSFT or another attractive TRAIN equity curve,
dropping the short side, choosing the best horizon after OOS, pooling stocks,
or opening 2024+ CONFIRMATION. Each would be a new substantive hypothesis.

## Evidence

- Authoritative packet:
  `runs/research_workbench/literature_grounded/lit_mom_01_1_stock_atlas_01_20260731/`
- Frozen registry:
  `literature_studies/registries/gen5_lit_mom_01_1_stock_atlas_01_registry.csv`
- Contract:
  `literature_studies/docs/GEN5_LIT_MOM_01_1_STOCK_ATLAS_01_CONTRACT.md`
- Evidence deck:
  `literature_studies/presentations/gen5_lit_mom_01_1_stock_atlas_01_evidence.pptx`
