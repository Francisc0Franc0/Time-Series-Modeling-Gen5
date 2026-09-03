# Gen5 Literature Source Ledger

Status: `LITERATURE_INVENTORIED_THROUGH_LIT_REG_01_1`

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

Additional claims used by `LIT-MR-04.1` and `LIT-MR-05.1`:

| Claim or warning | Printed pages | PDF pages | Kalman POC use |
|---|---:|---:|---|
| A moving-window regression imposes an abrupt cutoff, whereas a Kalman filter recursively downweights older information without choosing a hard window boundary. | 75 | 93 | Compare a dynamic state path with a trailing 20-session OLS diagnostic. |
| Dynamic regression can be written as an observation equation with time-varying slope/intercept and a random-walk state equation. | 76 | 94 | Use `[slope(s), intercept]` as the state and identity transition. |
| The signal is the pre-update forecast error (innovation), standardized by its predicted variance; the Kalman gain then updates the state. | 76-77 | 94-95 | Generate signals from the causal pre-update innovation, never the mechanically shrunken post-update residual. |
| Chan parameterizes state noise as `delta/(1-delta) I`; zero delta gives fixed regression while values near one make coefficients very volatile. | 77 | 95 | Freeze `delta=0.0001`, but scale the diagonal by warm-up state uncertainty for price-scale invariance. |
| Example 3.3 uses EWA to explain EWC, initializes the displayed filter at zero, and uses `delta=0.0001` and `Ve=0.001`; the text says the latter constants were chosen with hindsight. | 78 | 96 | Keep EWC-on-EWA orientation and source delta, but estimate observation scale from TRAIN warm-up and do not treat the reported constants as validated authority. |
| The example enters long below minus one predicted standard deviation, short above plus one, and exits on the zero crossing. | 80-81 | 98-99 | Freeze the bounded two-sided trading rule with next-open execution and costs. |
| The source reports 26.2% APR and 2.4 Sharpe for the displayed in-sample example. | 81 | 99 | Record only as source context; do not tune toward or compare Gen5 periods as a replication claim. |
| The filter supplies time-varying hedge ratios, intercept, and forecast-error variance, but convergence must be established from future returns rather than the post-update residual. | 81-82 | 99-100 | Report coefficient paths and calibration, while gating the trading interpretation on future fixed-vector convergence. |

Additional claims used by `LIT-MR-06.1`:

| Claim or warning | Printed pages | PDF pages | LIT-MR-06.1 use |
|---|---:|---:|---|
| Example 4.1 estimates each stock's trailing 90-session standard deviation of close-to-close returns, then looks for an opening gap below the prior low by more than one such standard deviation. | 93-94 | 111-112 | Freeze the lagged 90-session volatility-scaled gap threshold. |
| The second rule requires the current open to remain above a trailing 20-session moving average, seeking a sharp gap inside a broader positive price context. | 93-94 | 111-112 | Freeze the lagged MA filter and isolate its incremental value with a labeled ablation. |
| Eligible stocks are ranked by the most negative gap, at most ten are bought, each receives one tenth of capital, unused sleeves stay cash, and positions exit at the close. | 94 | 112 | Preserve top-ten ranking, fixed sleeve denominator, long-only direction, and same-day exit. |
| The source reports 8.7% APR and 1.5 Sharpe from May 11, 2006 to April 24, 2012, while noting survivor bias and omitting transaction costs. | 94-95 | 112-113 | Record as published in-sample context only; add costs and quarantine static-survivor evidence. |
| The official open cannot be both observed for signal formation and obtained as a subsequent fill; pre-open market data may differ across venues and from the consolidated opening price. | 95-96 | 113-114 | Keep the same-open result as `NONCAUSAL_REFERENCE`; make 09:31 observation and a strictly later 09:32 fill the primary estimand. |
| A mirrored short-on-gap strategy is presented separately and has different drawdown and short-sale constraints. | 95 | 113 | Exclude the short mirror from `06.1`; it requires a separately frozen substantive variant. |

Additional claims used by `LIT-MOM-01.1`:

| Claim or warning | Printed pages | PDF pages | LIT-MOM-01.1 use |
|---|---:|---:|---|
| Time-series momentum predicts an asset's own future return from its own past return, unlike cross-sectional momentum, which ranks assets against one another. | 133-135 | 151-153 | Use one instrument and score absolute up/down direction separately from P&L. |
| Past and future return horizons should be compared across a finite grid before selecting the worked strategy horizon. | 135-137 | 153-155 | Reconstruct the complete 49-cell `L,H` screen on TRAIN before freezing the SHY rule. |
| Figure 6.1 and the surrounding prose advance the correlation anchors by the shorter return interval to reduce overlapping observations. | 135-136 | 153-154 | Use `min(L,H)` as the source-faithful sparse screen, while disclosing that the longer return interval can still overlap. |
| The printed MATLAB loop advances by the larger interval, in tension with the prose and figure. | 136 | 154 | Preserve the inconsistency in the ledger and add a strict `L+H` sensitivity rather than pretending either convention creates fully independent raw intervals. |
| The TU table leaves multiple plausible positive-correlation candidates; `250/25` is selected after that table and reflects a reasonably short holding-period preference. | 137-138 | 155-156 | Keep `250/25` as the canonical informed source choice, not an arbitrary constant or the automatic SHY rule. |
| Example 6.1 starts one `1/25` position each day from the sign of the past 250-session return and holds each position for 25 sessions. | 138-139 | 156-157 | Implement causal daily `1/H` sleeves with next-open entry and bounded aggregate long/short exposure. |
| The source reports about 1.0 Sharpe, 1.7% APR on notional capital, and 2.5% maximum drawdown for TU from June 1, 2004 to May 11, 2012. | 139 | 157 | Record as source in-sample context only; do not tune SHY toward it or import futures leverage assumptions. |
| Futures rolls require special continuous-price treatment, and leverage changes the interpretation of return on capital. | 138-140 | 156-158 | Disclose that adjusted SHY ETF bars do not reproduce TU roll, margin, financing, tax, or capital-efficiency mechanics. |
| Momentum strategies can suffer infrequent but severe reversals and often provide fewer independent signals than their daily trading frequency suggests. | 142-145 | 160-163 | Report sleeve and bar evidence, drawdown, autocorrelation-adjusted Sharpe, strict-spacing sensitivity, and cost stress. |

Additional claims used by `LIT-MOM-02.1`:

| Claim or warning | Printed pages | PDF pages | LIT-MOM-02.1 use |
|---|---:|---:|---|
| The opening-gap momentum rule is presented as the opposite of the stock buy-on-gap mean-reversion rule and is said to work on some futures and currencies. | 155-157 | 173-175 | Treat futures/currencies as the source domain and label US-listed ETFs and stocks as a retail-domain translation. |
| Example 7.1 buys when the open exceeds the prior high by `0.1` times lagged 90-session close-return volatility and shorts below the mirrored prior-low threshold. | 156 | 174 | Freeze the 90-session estimator, `0.1` multiple, two-sided direction, and same-close exit. |
| FSTX is reported as the best result after testing multiple futures, with 13% APR and 1.4 Sharpe from July 16, 2004 through May 17, 2012. | 156 | 174 | Record the headline as selected in-sample source context, not Gen5 evidence or an exact replication. |
| The source attributes possible continuation to clustered stops triggered at the open and to overnight information. | 157 | 175 | Use same-day signed continuation as the estimand and randomize the signal direction as a falsification control. |
| The printed return line is `positions.*(op-cl)./op`, which reverses the P&L sign implied by the prose, position labels, and rising equity figure. | 156-157 | 174-175 | Preserve the literal sign as an audit diagnostic and implement the narrative-consistent `position*(close-open)/open` direction. |

## External HMM and Regime-Switching Sources

These sources open `LIT-REG-01.1` and its volatility-only `01.2` variant. They were not part of the operator's
original Chan/Halls-Moore PDF folder, so the source boundary remains explicit.

| Source | Grounded section or pages | LIT-REG-01.1 use | Not imported |
|---|---|---|---|
| Rabiner (1989), *A Tutorial on Hidden Markov Models and Selected Applications in Speech Recognition*, Proceedings of the IEEE 77(2), DOI `10.1109/5.18626` | Published pp. 257-261: model elements and three basic problems; pp. 261-267: forward, Viterbi, and Baum-Welch solutions | Define emissions, transition probabilities, scaled forward filtering, retrospective decoding, EM estimation, and synthetic algorithm checks | Speech topology, speech features, or application-specific state meaning |
| Zucchini, MacDonald, and Langrock (2016), *Hidden Markov Models for Time Series: An Introduction Using R*, 2nd ed. | Chapters titled “Hidden Markov models: definition and properties,” “Estimation,” “Forecasting, decoding and state prediction,” “Model selection and checking,” and “Models for financial series” | Separate filtering, prediction, decoding, model checking, state-count judgment, and R implementation concerns | Any package dependency or a preselected financial feature/state recipe |
| Hamilton (1989), *A New Approach to the Economic Analysis of Nonstationary Time Series and the Business Cycle*, Econometrica 57(2) | pp. 357-384 | Ground probabilistic inference and forecasting when time-series parameters depend on an unobserved Markov state | GNP variables, autoregressive order, or recession labels |
| Ang and Timmermann (2012), *Regime Changes and Financial Markets*, Annual Review of Financial Economics 4 | pp. 313-337 | Treat regimes as potentially differing in means, volatilities, autocorrelations, and cross-covariances; avoid reducing regime to direction alone | Portfolio rules, state count, or evidence that a regime model is tradable |
| Pohle, Langrock, van Beest, and Schmidt (2017), *Selecting the Number of States in Hidden Markov Models*, DOI `10.1007/s13253-017-0283-8` | Sections 2-4: HMM basics, simulation pitfalls, and pragmatic order selection | Keep H2 primary, make H3 diagnostic, and require occupancy, recurrence, semantic distinction, stability, and held-out value beyond information criteria | Animal-movement emissions or biological labels |
| Visser and Speekenbrink (2010), *depmixS4: An R Package for Hidden Markov Models*, Journal of Statistical Software 36(7) | pp. 1-21 | Implementation reference for EM, multivariate emissions, constraints, and posterior probabilities | Automatic authorization to add `depmixS4` or any dependency |
| Nystrup, Madsen, and Lindstrom (2017), *Dynamic Portfolio Optimization Across Hidden Market Regimes*, Quantitative Finance 18(1) | pp. 83-95 | Applied example of delayed causal decisions and transaction-aware regime use after state modeling | Model-predictive control, allocation, strategy switching, or claimed performance |
| Rydén, Teräsvirta, and Åsbrink (1998), *Stylized Facts of Daily Return Series and the Hidden Markov Model*, Journal of Applied Econometrics 13(3) | Abstract and empirical S&P 500 sections | Ground the narrower claim that hidden-state mixtures can represent higher-order temporal dependence and volatility clustering while warning that parameters can vary across subperiods | Evidence of stable direction states, tradable alpha, or universal parameter stability |
| Bulla and Bulla (2006), *Stylized Facts of Financial Time Series and Hidden Semi-Markov Models*, Computational Statistics & Data Analysis 51(4) | Abstract, introduction, and conclusion | Ground volatility as an HMM-appropriate niche and preserve the limitation that geometric HMM durations may miss slow volatility dependence | Automatic authority to replace HMM with HSMM inside `01.2` |
| Harte (2025), CRAN `HiddenMarkov` package 1.8-14 reference manual | Package overview; `dthmm`, `BaumWelch`, `forwardback`, and Gaussian examples | Independent univariate Gaussian HMM estimation and likelihood reference for `01.2` | Package filtering as causal evidence without Gen5 cross-checks, multivariate models, or strategy authority |
| Michelot (2025), CRAN `hmmTMB` package 1.1.2 and “General dependence structures in hmmTMB” vignette | Vignette section “Autoregressive hidden Markov models,” especially the lagged-observation formulation and state-switching AR examples | Package-native TMB maximum-likelihood authority for the state-dependent intercept, AR(1) slope, variance, and transition matrix in `02.1` | Evidence that financial directions are identifiable, permission to add model complexity, or causal filtering without the Gen5 recursion |

Project-designed elements that must not be attributed to the sources include
SPY, log return plus log normalized true range, the B0/B1/H2/H3 registry, the
2016-2023 folds, 20 deterministic starts, covariance floor, block bootstrap,
temporal-order controls, every quantitative gate, and the 2024+ seal.

For `01.2`, the univariate log normalized-range observation, B0/B1/B2/H2
registry, twelve starts, formal abstention boundary, 80th-percentile high-range
target, SPY and replication instruments, and every quantitative gate are also
project-designed. The operator explicitly approved `HiddenMarkov` on
2026-08-19 after a package audit; `depmixS4` was archived by CRAN on 2026-07-04
and `hmmTMB` was judged disproportionate for this minimal POC.

For `02.1`, the operator separately approved `hmmTMB` and its dependencies on
2026-08-19 after the directional lane was opened. The package is installed
only in ignored `.codex_r_libs`. The planted drift, AR coefficients,
transition matrices, simulation seeds, 20-session probability target,
baselines, oracle, multistart registry, gates, and STOP boundary are Gen5
design and must not be attributed to Michelot, Hamilton, or the package.

`02.2` reuses the same package authority but changes the Gen5 evaluation
question. The four B2 features, fixed ridge penalty, fresh seeds, paired
confidence bounds, calibration limits, frontier definition, and stress
interpretation are project-designed. They are not recommendations or defaults
from `hmmTMB` or the cited HMM literature.

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
- `LIT-MR-02.2` and `LIT-MR-03.2` preserve the source-inspired pair and
  triplet trading rules while changing Gen5-designed evidence gates. The
  one-sided 90% bootstrap bounds, support thresholds, vector-cosine threshold,
  half-life ceiling, diagnostic roles, candidate registries, and
  retrospective-versus-fresh lane design are project decisions and must not be
  attributed to Chan.
- Completed `02.2/03.2` evidence does not support further gate easing. The
  sole fresh triplet survivor, `UNP-CSX-NSC`, also passed every original strict
  gate and then returned `-14.25%` in 2021-2023 DEVELOPMENT. The interpretation
  of this as a temporal relationship break and the proposed future
  requalification discussion are Gen5 conclusions, not literature claims.
- `LIT-MR-04.1` is the single-pair EWC-on-EWA causal Kalman exercise.
  Warm-up OLS scale initialization, scale-aware process covariance, next-open
  accounting, costs, comparator diagnostics, and eight TRAIN gates are Gen5
  translations; they must not be attributed to Chan.
- `LIT-MR-05.1` adds IGE as a second regressor in one fixed orientation. It is
  an asymmetric dynamic multiple regression, not a Johansen rank estimator.
  The chosen triplet, orientation, gross normalization, and gates are Gen5
  design.
- Both Kalman filters passed their structural TRAIN gates. `LIT-MR-04.1`
  stopped only on the frozen 24-trade support minimum (`21` completed), while
  `LIT-MR-05.1` stopped on return uncertainty and random-sign separation.
  These are Gen5 outcomes, not replications of Chan's reported in-sample
  performance. Neither DEVELOPMENT strategy interval was queried.
- `LIT-MR-06.1` is a Gen5 causal translation of Chan's Example 4.1. The
  09:31 signal timestamp, 09:32 adjusted-minute entry proxy, costs, static
  ten-panel atlas, benchmarks, random-stock control, ablation, and eight TRAIN
  gates are Gen5 design and must not be attributed to Chan. The source-style
  official-open fill is retained only as a labeled noncausal diagnostic.
- The completed `LIT-MR-06.1` atlas produced `0 / 10` full TRAIN passes.
  Consumer staples and discretionary each passed six gates and had positive
  point estimates, but both failed support and uncertainty. This
  `STOP_LIT_MR_06_1_ATLAS_NO_FULL_PASS` verdict is a Gen5 outcome, not a
  replication or refutation of Chan's reported 2006-2012 result.
- `LIT-MR-06.1 / RECENT_WIDE_ATLAS_02` is a fresh replication batch under
  unchanged strategy mechanics. Its July 28, 2026 holdings inputs come from
  the eleven official State Street Select Sector SPDR daily workbooks.
  Provider-weight order, CUSIP6 issuer deduplication, top-40 coverage
  screening, 30-stock sector caps, the 305-stock union, newer evidence
  windows, and conditional OOS rule are Gen5 design—not claims from Chan.

- The completed recent-wide batch produced `0 / 12` full TRAIN passes.
  `W01_WIDE_US` passed seven gates with `+4.12%` primary return and `56.2%`
  up/down accuracy, but its one-sided 90% lower bound was `-2.81 bp/day`.
  Financials and health care also reached seven gates but failed frozen
  support. These are Gen5 outcomes; DEVELOPMENT was not queried.
- `LIT-MOM-01.1` reconstructs Chan's full Chapter 6 sequence rather than
  treating `250/25` as an arbitrary starting rule. The source supplies the
  horizon grid, sparse-correlation idea, canonical `250/25` reference, and
  daily overlapping-sleeve mechanism. The SHY proxy, deterministic
  TRAIN-only selection rule, minimum five-session swing hold, costs,
  dependence sensitivities, six gates, and evidence windows are Gen5 design.
- The frozen SHY screen selected `60/5`, which passed all six TRAIN gates.
  Its one authorized 2021-2023 DEVELOPMENT replay weakened to 44.0%
  directional accuracy, +0.09% primary cumulative return, 0.03 adjusted
  Sharpe, and -3.56% stress return. Record
  `OOS_DEVELOPMENT_COMPLETE_LIT_MOM_01_1` and recommend STOP before sealed
  CONFIRMATION. This is a Gen5 outcome, not a refutation of Chan's TU result.
- `LIT-MOM-01.1 / STOCK_ATLAS_01` is a Gen5-designed breadth replication,
  not a panel proposed by Chan. Its 22-stock, eleven-sector static registry,
  per-stock repetition of the 49-cell selector, conditional OOS rule, costs,
  six gates, and survivor-bias disclosure are project design. `HD` was the
  sole full TRAIN passer with a frozen `10/10` rule. Its 2021-2023 replay
  retained 58.7% direction accuracy but returned -5.86% after primary costs
  and -9.82% under stress. This is evidence about the frozen retail
  translation, not a refutation of Example 6.1 or Chan's `TU` result.
- `LIT-MOM-02.1` recapitulates Chan's FSTX Example 7.1 as
  `SOURCE_REFERENCE_ONLY`; the source's continuous-contract series and roll
  construction were not supplied, so no exact source-period reproduction is
  claimed. The 09:31 observation, 09:32 adjusted-minute entry, 10/20 bp costs,
  92-instrument registry, eight TRAIN gates, bootstrap, sign control, and STOP
  decision are Gen5 design. None of the eight anchors or 92 atlas instruments
  passed all eight gates. XLP reached 7/8 but failed the frozen stress gate.
  Record `STOP_LIT_MOM_02_1_OPENING_GAP_NO_TRAIN_NOMINEE`; DEVELOPMENT was not
  queried and this is not a refutation of Chan's selected FSTX result.

Methodological correction:

- Printed page 46 and printed page 134 describe a p-value as the probability
  that the null hypothesis is true. That is not correct. A p-value is the
  probability, under the null, of observing a statistic at least as extreme as
  the one observed. L1 therefore reports effect sizes, confidence intervals,
  and randomized controls rather than treating a p-value as posterior belief.
  `LIT-MOM-01.1` similarly labels the horizon-table p-values as nominal,
  exposes the 49 related comparisons, adds dependence-aware spacing
  sensitivities, and treats the sealed OOS replay as the real falsification
  surface.

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

## Active Dual-Momentum Source Set

`LIT-MOM-03.1` treats a recent video as practitioner literature: it supplies a
specific, reproducible hypothesis, while academic sources supply the broader
mechanism. Neither source class supplies Gen5 confirmation.

| Source | Source role | Imported into `LIT-MOM-03.1` | Explicitly not imported |
|---|---|---|---|
| Quantpedia, “Dual Momentum Strategies - Quantpedia Explains Trading Strategies,” YouTube, July 12, 2026, <https://www.youtube.com/watch?v=c1HDiohiqLU> | Operator-supplied practitioner literature and study prompt | The recent dual-momentum framing and link to the published implementation | Any verbal or displayed performance claim as Gen5 evidence |
| Quantpedia, “Active Dual Momentum GTAA Strategy,” May 22, 2026, <https://quantpedia.com/active-dual-momentum-gtaa-strategy/> | Primary implementation specification | Nine-ETF universe (`SHY, IEF, UUP, GLD, USO, SPY, EFA, QQQ, EEM`); Wednesday-close weekly signal; 10- and 25-week ROC sleeves; top three positive selections per sleeve; failed slots in cash; 50/50 sleeve allocation | The reported 2008-2026 backtest as independent evidence; the article searched horizons and breadths on the same history before selecting 10/25 weeks and top three |
| Antonacci, “Risk Premia Harvesting Through Dual Momentum,” SSRN 2042750, <https://doi.org/10.2139/ssrn.2042750> | Dual-momentum academic/practitioner bridge | Relative-strength selection combined with an absolute-momentum permission rule | Antonacci's exact assets, parameters, or performance as proof of the Quantpedia rule |
| Jegadeesh and Titman (1993), “Returns to Buying Winners and Selling Losers,” <https://doi.org/10.1111/j.1540-6261.1993.tb04702.x> | Cross-sectional momentum foundation | The claim that portfolio-level winner-minus-loser continuation differs from forecasting one asset's next return | The unavailable short leg as authority for a long-only implementation |
| Moskowitz, Ooi, and Pedersen (2012), “Time Series Momentum,” <https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum> | Time-series momentum foundation | The claim that own past direction can have a weak average relation to future return when diversified across markets | Any implication that every single asset or fast horizon must show a visible signal |
| Daniel and Moskowitz, “Momentum Crashes,” NBER Working Paper 20439, <https://www.nber.org/papers/w20439> | Risk and persistence context | Momentum can retain a premium while suffering violent reversals and difficult risk | Any claim that academic support removes implementation, timing, cost, or baseline risk |

The opening
[study deck](../presentations/gen5_lit_mom_03_1_dual_momentum_study.pptx)
contains the source-by-slide notes, the fleet-versus-leaf intuition, the
long-only baseline ladder, the exact published mechanics, and the next narrow
slice: an auditable weekly signal and allocation tape before performance. That
mechanics slice is now complete on the clean locally admitted 2016-2026
window; see the
[mechanics results](GEN5_LIT_MOM_03_1_DUAL_MOMENTUM_MECHANICS_RESULTS.md).
All 11 integrity checks passed across 508 decisions, but the Alpaca refresh
still returned no pre-2016 history. The publisher's 2008-2015 segment therefore
remains unreproduced, and no performance surface or edge claim was opened.

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
- `LIT-MR-04.1` is the frozen EWC-on-EWA Kalman dynamic-regression pair
  textbook exercise; it completed at
  `STOP_LIT_MR_04_1_TRAIN_STRATEGY`.
- `LIT-MR-05.1` is the frozen EWC-on-EWA-and-IGE asymmetric Kalman triplet
  textbook extension; it completed at
  `STOP_LIT_MR_05_1_TRAIN_STRATEGY`.
- `LIT-MOM-01.1` is the first literature-grounded momentum concept. Its
  full 49-cell TRAIN screen selected `60/5` for SHY, all six TRAIN gates
  passed, and the frozen 2021-2023 OOS replay completed essentially flat
  after ordinary costs and negative under stress. Preserve
  `OOS_DEVELOPMENT_COMPLETE_LIT_MOM_01_1` and stop before CONFIRMATION.
