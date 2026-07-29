# Gen5 Literature Source Ledger

Status: `LITERATURE_INVENTORIED_THROUGH_LIT_MR_03_1`

## Purpose

This ledger records the sources used to define the first literature-grounded
Gen5 proof of concept. The sources generate hypotheses and methodological
constraints; they are not Gen5 performance authority.

## Operator-supplied books

### Ernest P. Chan

- **Title:** *Algorithmic Trading: Winning Strategies and Their Rationale*
- **Publisher and date:** Wiley, 2013
- **Document type:** practitioner book, not a peer-reviewed empirical paper
- **Operator-local file:** `C:/Users/Franc/OneDrive/Documents/Francis/Trading Literature/Algorithmic Trading - Winning Strategies and Their Rationale 2013.pdf`
- **Edition note:** title and publication metadata are present; the PDF contains
  225 pages including front matter.

Grounded claims used by L1:

| Claim or warning | Printed pages | PDF pages | L1 use |
|---|---:|---:|---|
| Prefer simple linear models with few rules and parameters because complexity raises data-snooping risk. | 5-7 | 23-25 | One fixed rank, two long legs, two short legs, and one holding horizon. |
| Relative-return prediction may be more reliable than absolute-return prediction; ranking naturally supports a long-short portfolio. | 6-7 | 24-25 | Separate spread prediction from absolute up/down prediction. |
| Survivorship bias is especially dangerous for beaten-down long-only stock strategies. | 8-10 | 26-28 | Use long-history sector ETFs and disclose the fixed-survivor universe. |
| Most asset prices are nonstationary; mean reversion can instead be tested through serial dependence or stationary combinations. | 39-41 | 57-59 | Do not require individual ETF prices to pass an ADF stationarity test. |
| ADF, Hurst, variance ratio, and half-life are diagnostics with different nulls and horizons. | 42-47 | 60-65 | Keep them educational and secondary to the exact cross-sectional estimand. |
| Cointegration means a linear combination of nonstationary series is stationary; it is not ordinary correlation. | 51-54 | 69-72 | Do not call the L1 ranking portfolio a cointegration strategy. |
| Linear mean reversion can be expressed through continuously scaled or thresholded long-short positions. | 64-74 | 82-92 | L1 uses a fixed extreme-rank threshold without scaling or optimization. |
| Stock and ETF mean-reversion examples often omit costs, include lookahead, or choose parameters with hindsight. | 64-85 | 82-103 | Freeze timing, costs, controls, and STOP rules before outcomes. |
| Cross-sectional mean reversion buys relative losers and shorts relative winners. | 102-106 | 120-124 | Direct strategy mechanism for L1. |
| Direction-only prediction can be evaluated through correlation of past and future return signs. | 133-136 | 151-154 | Add absolute and relative directional scorecards. |
| Nonoverlapping past/future windows are required for honest correlation inference. | 135-136 | 153-154 | Use nonoverlapping five-session cohorts and cohort-level inference. |

Additional claims used by `LIT-MR-02.1`:

| Claim or warning | Printed pages | PDF pages | LIT-MR-02.1 use |
|---|---:|---:|---|
| A price ratio can be more stable across changing nominal price levels, but there is no universal answer; in the GLD-USO comparison, the adaptive raw-price spread worked better than ratio or log-price spread. | 66-69 | 84-87 | Use the raw adjusted-price spread for source fidelity and report ratio/log-price as future concepts, not hidden alternatives. |
| Example 3.1 estimates a rolling 20-session OLS hedge ratio for `USO ~ GLD`, then defines the unit-portfolio spread as `USO - beta * GLD`. | 67-68 | 85-86 | Freeze the pair, rolling estimator, lookback, and spread orientation. |
| The published 20-session lookback was near-optimal with hindsight. | 67 | 85 | Treat 20 as a literature-fixed parameter, not new Gen5 optimization authority. |
| The log-price version underperformed the raw-price version in the source example and required daily capital rebalancing. | 68-69 | 86-87 | Do not silently substitute log prices; account for adaptive-hedge turnover. |
| Bollinger entry/exit thresholds bound position size and make risk allocation more practical than continuously scaling exposure with z-score magnitude. | 70-71 | 88-89 | Hold at most one normalized unit portfolio long or short. |
| Example 3.2 uses `entryZscore = 1`, `exitZscore = 0`, and the same adaptive raw-price spread construction as Example 3.1. | 71-72 | 89-90 | Freeze the exact thresholds and signal family. |
| The source reports 17.8% APR and 0.96 Sharpe for May 24, 2006-April 9, 2012. | 72 | 90 | Record as a published in-sample result only; do not treat it as Gen5 evidence or tune toward it. |
| The displayed source P&L applies lagged positions to close-to-close price changes and does not include transaction or borrow costs. | 68, 71-72 | 86, 89-90 | Reproduce the author's accounting separately from the Gen5 next-open, cost-aware translation. |

Additional claims used by `LIT-MR-03.1`:

| Claim or warning | Printed pages | PDF pages | LIT-MR-03.1 use |
|---|---:|---:|---|
| CADF is pair-specific and order-dependent; Johansen applies to any number of series and estimates cointegrating rank and vectors together. | 51-56 | 69-74 | Use a three-series Johansen/VECM estimator rather than three pairwise regressions. |
| The rank of the long-run matrix is the number of independent cointegrating portfolios, and Johansen eigenvectors provide their share hedge ratios. | 54-58 | 72-76 | Require one unambiguous relation in the minimal POC and treat the leading eigenvector as shares. |
| Chan's EWA-EWC-IGE example uses the leading eigenvector, computes portfolio market value as shares times prices, and estimates a 23-session half-life in the source sample. | 55-58 | 73-76 | Include the literature anchor, translate shares to gross-normalized dollar weights, and test half-life separately from trading performance. |
| The source's linear triplet strategy scales portfolio units continuously by negative z-score and reports 12.6% APR / 1.4 Sharpe in-sample. | 58-60 | 76-78 | Preserve as context; Gen5 instead uses the already-frozen bounded +/-1z entry and zero-exit rule to keep capital finite and comparable. |
| ETF relationships may persist better than single-company pairs because basket fundamentals change more slowly. | 91 | 109 | Prefer ETF-heavy, economically motivated triplets without treating ETF status as a pass condition. |
| GLD-GDX may omit energy costs; adding USO is an empirical omitted-factor hypothesis, but USO's futures exposure is an imperfect spot-oil proxy. | 91-92 | 109-110 | Include GLD-GDX-USO as a direct scientific-hypothesis anchor and disclose the proxy limitation. |

Implementation clarification:

- The printed Example 3.1 spread is `USO - beta * GLD`, while its displayed
  position-weight line uses the opposite sign. `LIT-MR-02.1` uses the
  economically consistent interpretation: a low spread is bought by going
  long USO and short `beta` shares of GLD; a high spread is shorted with the
  opposite legs.
- The source estimates an intercept in rolling OLS but omits the intercept
  from the traded unit-portfolio spread. The POC preserves that convention
  and records the intercept only as an audit diagnostic.
- `LIT-MR-02.1-PANEL-A` and `LIT-MR-02.1-PANEL-B` are
  operator/Codex-designed replication batches, not claims that Chan proposed
  their ETF pairs. They apply the source-derived formula unchanged to finite
  registries fixed before outcomes. Their economic rationales, gates, and
  readouts are grounded in the separate
  [Panel A contract](GEN5_LIT_MR_02_1_PANEL_A_CONTRACT.md) and
  [Panel B contract](GEN5_LIT_MR_02_1_PANEL_B_CONTRACT.md).
- `LIT-MR-02.1 / CASESTUDY_2018` is an explicitly ex-post working-regime
  explanation inside already-open TRAIN. It is not an independent test.
- `LIT-MR-02.1 / SOURCE_REPRO_2006_2012` uses Yahoo chart adjusted daily bars
  only because the canonical Alpaca path does not cover the published
  interval. The Yahoo URLs, adjusted-OHLC reconstruction, retrieval timestamp,
  and coverage audit are recorded in the ignored evidence packet. This
  reference source does not enter canonical Gen5 provider or live scope.
- The source-period reproduction is documented in
  [the positive-control case-study addendum](GEN5_LIT_MR_02_1_CASE_STUDIES.md).
- `LIT-MR-02.1 / RELATIONSHIP_ATLAS_01` is a Gen5-designed, five-cell
  hypothesis generator. Its 25 identities, topologies, mechanisms,
  orientations, and rationales were frozen before outcomes. It produced
  `STOP_LIT_MR_02_1_RELATIONSHIP_ATLAS_01_NO_FULL_PASS`.
- `LIT-MR-03.1` is a Gen5 implementation of the source's Johansen triplet
  concept. The exact-rank-one requirement, seeded null simulation, vector
  stability gate, bounded Bollinger-style trade rule, costs, and eight-gate
  conjunction are project-designed and must not be attributed to Chan.
- Chan's Example 2.7 reports full rank for EWA-EWC-IGE and then uses the
  leading vector. Gen5 records the example but does not treat full rank as a
  minimal one-relation result; `LIT-MR-03.1` requires exactly rank one before
  nomination.
- `LIT-MR-03.1 / TRIPLET_ATLAS_01` is a Gen5-designed seven-cell hypothesis
  generator under the unchanged source-inspired triplet mechanics. Its 28
  identities, categories, rationales, and order were frozen before outcomes.
  `EWA-EWC-EWZ` cleared all eight TRAIN gates and retained a modest positive
  primary-cost result in the one authorized OOS DEVELOPMENT replay. The atlas,
  thresholds, and gates are project design and must not be attributed to Chan.

Methodological correction:

- Printed page 46 and printed page 134 describe a p-value as the probability
  that the null hypothesis is true. That is not correct. A p-value is the
  probability, under the null, of observing a statistic at least as extreme as
  the one observed. L1 therefore reports effect sizes, confidence intervals,
  and randomized controls rather than treating a p-value as posterior belief.

### Michael L. Halls-Moore

- **Title:** *Successful Algorithmic Trading*
- **Publication date:** PDF build dated June 18, 2015
- **Document type:** self-published practitioner book
- **Operator-local file:** `C:/Users/Franc/OneDrive/Documents/Francis/Trading Literature/Successful Algorithmic Trading.pdf`
- **Edition note:** no explicit edition number was found; the PDF contains 208
  pages.

Grounded claims used by L1:

| Claim or warning | Printed pages | PDF pages | L1 use |
|---|---:|---:|---|
| Lookahead, optimization, survivorship, cognitive bias, and transaction costs can make a backtest an upper bound rather than achievable evidence. | 16-20 | 25-29 | Frozen windows, next-open timing, fixed costs, and no rescue. |
| Strategy evaluation should include risk, benchmark, leverage, frequency, win/loss behavior, and drawdown rather than returns alone. | 34-35 | 43-44 | Multi-layer mechanism, cohort, bar, and risk reporting. |
| OU, ADF, Hurst, and cointegration test different statistical ideas. | 87-96 | 96-105 | Educational diagnostics do not become a three-way classifier. |
| Bar-level tests provide more observations than completed trades, but strategy metrics depend on the implemented rule. | 96 | 105 | Report statistical mechanism evidence and portfolio evidence separately. |
| Performance should be measured at trade and bar granularity. Mean reversion often has many small winners and rare severe losses; momentum often has the opposite profile. | 109-111 | 118-120 | Cohort hit/payoff/tail metrics plus daily equity and drawdown. |
| Sharpe requires an explicit periodic return convention and has non-normality, transaction-cost, and backward-looking limitations. | 113-114 | 122-123 | Report naive and autocorrelation-adjusted Sharpe with costs. |
| Maximum drawdown and drawdown duration describe distinct dimensions of loss. | 117 | 126 | Report depth, duration, and time under water. |

## Primary-method cross-checks

- Engle, R. F. and Granger, C. W. J. (1987), "Co-integration and Error
  Correction: Representation, Estimation, and Testing." Used to preserve the
  distinction between stationary price combinations and cross-sectional
  reversal.
- Lo, A. W. and MacKinlay, A. C. (1988), "Stock Market Prices Do Not Follow
  Random Walks." Used to preserve the warning that rejecting a random walk
  does not establish stationary mean reversion.
- Lo, A. W. (2002), "The Statistics of Sharpe Ratios." Used to require an
  autocorrelation-aware Sharpe diagnostic rather than relying only on
  square-root-of-time annualization.
- Bailey, D. H. and López de Prado, M. (2014), "The Deflated Sharpe Ratio."
  Reserved for later use if the project searches many strategy variants. The
  minimal L1 POC instead prevents multiplicity by freezing one rule.

- Johansen, S. (1991), "Estimation and Hypothesis Testing of Cointegration
  Vectors in Gaussian Vector Autoregressive Models." Used to preserve the
  rank interpretation and the distinction between eigenvectors, rank tests,
  and a trading rule.

## Retail-data and borrow boundary

Alpaca adjusted daily OHLCV is sufficient to reconstruct L1's historical price
and volume inputs. It is not sufficient to prove point-in-time historical
borrow availability or borrow fees.

Current Alpaca documentation exposes a current `borrow_status` field and
distinguishes easy-to-borrow from hard-to-borrow handling. The older
`easy_to_borrow` field is scheduled for deprecation. This is prospective
operational information only; L1 must not backfill it into historical dates.

## Selected ideas

- `LIT-MR-01.1` is the completed five-session long-short cross-sectional
  reversal test across nine long-history U.S. sector ETFs.
- `LIT-MR-02.1` is the adaptive GLD-USO raw-price-spread Bollinger test derived
  directly from Chan Examples 3.1 and 3.2.
- `LIT-MR-02.1-PANEL-A` preserves that canonical example and records a
  predeclared breadth replication separately; it produced
  `STOP_LIT_MR_02_1_PANEL_A_NO_FULL_PASS`.
- `LIT-MR-02.1-PANEL-B` adds a separately frozen 15-pair sector, industry, and
  producer/commodity breadth replication; it produced
  `STOP_LIT_MR_02_1_PANEL_B_NO_FULL_PASS`.
- `LIT-MR-02.1 / RELATIONSHIP_ATLAS_01` adds a finite 25-instance,
  category-labeled generator under unchanged mechanics; it produced
  `STOP_LIT_MR_02_1_RELATIONSHIP_ATLAS_01_NO_FULL_PASS`.
- `LIT-MR-03.1` is the daily Johansen triplet POC across eight predeclared
  relationships. Five met the exact rank-one diagnostic, but none cleared all
  eight TRAIN gates, producing `STOP_LIT_MR_03_1_NO_TRAIN_NOMINATION`.
- `LIT-MR-03.1 / TRIPLET_ATLAS_01` adds 28 predeclared triplets across seven
  economic categories. Ten met the exact-rank-one diagnostic and
  `EWA-EWC-EWZ` alone cleared all eight TRAIN gates. Its frozen-vector
  2021-2023 OOS replay returned `+3.73%` at primary costs and `-3.23%` at
  stress costs, producing
  `OOS_DEVELOPMENT_COMPLETE_LIT_MR_03_1_TRIPLET_ATLAS_01`.
