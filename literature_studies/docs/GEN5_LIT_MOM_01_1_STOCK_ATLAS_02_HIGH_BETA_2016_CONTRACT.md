# LIT-MOM-01.1 Stock Atlas 02 High-Beta 2016 Contract

Status: `OOS_DEVELOPMENT_COMPLETE_STOP_RECOMMENDED`

## Place in the literature-study progression

`LIT-MOM-01.1 / STOCK_ATLAS_02_HIGH_BETA_2016` is a point-in-time breadth
replication of the completed Chapter 6 interday time-series-momentum exercise.
It answers a narrower follow-up: does contemporaneously high market beta make
the frozen time-series-momentum pattern more common?

This is not a new strategy variant. The horizon screen, signal, overlapping
sleeves, costs, six TRAIN gates, and OOS authorization rule remain unchanged.
It does not open portfolio construction, stock selection, leverage, live
shorting, advice, or execution.

## Frozen point-in-time registry

The registry reproduces all 99 common-equity holdings in the `PowerShares S&P
500 High Beta Portfolio (SPHB)` Schedule of Investments dated October 31, 2016:

`literature_studies/registries/gen5_lit_mom_01_1_stock_atlas_02_high_beta_2016_registry.csv`

Authoritative source: SEC EDGAR accession `0001193125-17-002614`, pages 50–51,
`PowerShares S&P 500 High Beta Portfolio (SPHB), October 31, 2016`:

<https://www.sec.gov/Archives/edgar/data/1378872/000119312517002614/d269293dncsr.htm>

The entire filing panel is frozen before any 2017–2023 momentum outcome is
inspected. Historical tickers are retained as printed-era identifiers. An
acquisition, delisting, ticker change, bankruptcy, or missing provider history
is a visible coverage STOP; it is not silently removed from the denominator.

The source sector counts are also frozen: Consumer Discretionary 8, Energy 25,
Financials 32, Health Care 7, Industrials 4, Information Technology 14,
Materials 6, Real Estate 2, and Telecommunication Services 1.

## Beta is not momentum

Beta measures sensitivity to the market:

`beta_i = Cov(r_i, r_market) / Var(r_market)`

The SPHB membership is the causal high-beta label. For interpretation only, the
packet also estimates each stock's beta against SPY from adjusted daily returns
between January 4 and December 30, 2016. This estimate is wholly pre-TRAIN and
does not select or delete registry members.

A high beta says that a stock historically amplified market moves. It does not
say that the sign of its own trailing return predicts the sign of its next
return. The latter is the distinct time-series-momentum claim tested here.

## Frozen strategy and windows

Each coverage-eligible stock independently reuses the exact `LIT-MOM-01.1`
contract:

- adjusted daily Alpaca bars only;
- warm-up from January 4, 2016;
- TRAIN from January 3, 2017 through December 31, 2020;
- DEVELOPMENT from January 4, 2021 through December 29, 2023;
- 2024+ CONFIRMATION sealed and not queried;
- `L,H in {1,5,10,25,60,120,250}` with the existing support rule;
- selection by maximum TRAIN Pearson t-statistic with frozen tie breaks;
- one next-open `1/H` sleeve per session, held for `H` open-to-open intervals;
- aggregate exposure bounded to `[-1,+1]`;
- 5 bp primary one-way turnover costs;
- 10 bp stress one-way turnover costs plus 100 bp annual short borrow; and
- the existing six conjunctive TRAIN gates.

## Coverage and OOS rules

- Full warm-up-plus-TRAIN SPY-session coverage is required to calculate a TRAIN
  result.
- Every registry member remains in the coverage table, including zero-history
  and partial-history names.
- DEVELOPMENT is opened only when all six TRAIN gates pass and the symbol has
  exact DEVELOPMENT SPY-session coverage.
- A TRAIN passer without full DEVELOPMENT coverage receives
  `DEVELOPMENT_COVERAGE_STOP`; no shortened OOS window is substituted.
- Every authorized OOS replay is reported. No OOS winner is selected.

## Interpretation boundary

This finite panel can show whether the source mechanism appears more or less
often among stocks that a contemporaneous index classified as high beta. It
cannot prove that beta causes momentum, that SPHB was investable with these
strategy rules, or that a 2016 membership list remains appropriate later.
Multiplicity, sector concentration, historical-symbol availability, and
corporate-action attrition must remain explicit.
