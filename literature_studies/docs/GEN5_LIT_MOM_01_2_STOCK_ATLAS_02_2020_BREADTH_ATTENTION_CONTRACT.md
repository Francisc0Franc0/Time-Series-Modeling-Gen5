# LIT-MOM-01.2 Stock Atlas 02: 2020 Breadth + Attention Contract

Status: `FROZEN_RETROSPECTIVE_EXPLORATION`

## Question

What does the unchanged `LIT-MOM-01.2` per-asset horizon-selection and
single-position process look like across 100 additional stocks that combine
broad sector coverage with names demonstrably receiving retail attention by
the end of TRAIN?

## Nomenclature

This is `LIT-MOM-01.2 / STOCK_ATLAS_02_2020_BREADTH_ATTENTION`. It is a
replication batch under unchanged signal and execution mechanics, not a new
decimal variant.

## Frozen registry

The registry contains exactly 100 symbols not present in Stock Atlas 01:

- `DIVERSIFIED_CORE`: 75 stocks, six or seven from each of the eleven broad
  sectors. Every name appears in the SPDR S&P 500 ETF Trust schedule of
  investments dated June 30, 2020. The within-sector sample favors liquid,
  long-history, recognizable businesses and was frozen before `01.2` results.
- `RETAIL_ATTENTION_2020`: 25 stocks explicitly named in contemporaneous May,
  August, November, or December 2020 coverage of Robinhood's Top 100 or
  Robintrack popularity data. Published ranks are retained where available.

The attention cohort is an observable retail-attention proxy. It is not a
claim that the names were the 25 most discussed securities across all media,
nor that popularity predicts momentum.

## Source ledger

| Source ID | Point-in-time evidence | URL |
|---|---|---|
| `SEC_SPY_2020_06_30` | SEC-filed SPY schedule of investments as of June 30, 2020 | https://www.sec.gov/Archives/edgar/data/884394/000175272420177260/NPORT_2992774291443337.htm |
| `INVESTORPLACE_RH_2020_05_27` | Ten explicitly ranked members of Robinhood's Top 100 | https://investorplace.com/2020/05/robinhood-stocks-to-buy-100-most-popular-list/ |
| `FORBES_RH_2020_08_05` | Explicit Robintrack popularity coverage of KODK, ADT, and LI | https://www.forbes.com/sites/advisor/2020/08/05/most-popular-stocks-on-robinhood/ |
| `KIPLINGER_RH_2020_11_24` | Six ranked late-2020 Robinhood names | https://www.kiplinger.com/investing/stocks/stocks-to-buy/601807/6-top-robinhood-stocks-for-late-2020-do-the-pros-agree |
| `FOOL_RH_TOP10_2020_12_05` | December 2020 top-ten Robinhood leaderboard | https://www.fool.com/investing/2020/12/05/the-10-most-widely-held-stocks-on-robinhood/ |

Robintrack's public holder-count API ended in August 2020. The later articles
therefore preserve contemporaneous leaderboard observations rather than a
continuous end-December holder-count panel.

## Coverage gate

Every registry row remains visible. A stock is analytically eligible only if
its adjusted daily bars exactly cover both:

- TRAIN: January 3, 2017 through December 31, 2020; and
- retrospective replay: January 4, 2021 through December 29, 2023,

using SPY sessions as the calendar reference. IPOs, acquisitions, ticker
changes, or provider gaps receive a coverage STOP. They are not replaced
after outcomes.

## Per-asset selection and execution

For every coverage-eligible stock:

1. Evaluate all 49 `L,H in {1,5,10,25,60,120,250}` TRAIN combinations.
2. Require selected `H >= 5` and at least 20 `CHAN_MIN_STEP=min(L,H)` pairs.
3. Select the maximum TRAIN Pearson-correlation t-statistic using the frozen
   shorter-H then shorter-L tie breaks.
4. Freeze that asset's selected `L/H`.
5. Replay only the frozen rule in known 2021-2023 data with causal next-open
   long entry after positive signals, cash after non-positive signals, one
   full-capital fixed-quantity position, exact-H holding, and full reinvestment
   between trades.
6. Report gross, 5 bp-per-side primary, and 10 bp-per-side stress paths; audit
   executed positive calls separately from the symmetric all-sign selector.

All three inference views remain visible: `CHAN_MIN_STEP` is primary;
all-phase `STEP_L` and strict `L+H` are diagnostics.

## Interpretation boundary

- The window is already known and is not fresh OOS confirmation.
- Do not choose the best stock, cohort, sector, or horizon after outcomes.
- Do not form a portfolio or infer allocation weights.
- Do not replace coverage failures or add short trades.
- Do not query 2024+ confirmation.
- The survivor-prone core and media-preserved attention cohort are
  pedagogical breadth probes, not an investable historical universe.
