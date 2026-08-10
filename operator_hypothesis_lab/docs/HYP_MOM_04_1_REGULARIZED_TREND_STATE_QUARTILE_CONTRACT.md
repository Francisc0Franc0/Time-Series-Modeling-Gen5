# HYP-MOM-04.1 Regularized Trend-State Quartile Contract

Status: `FROZEN_AND_EXECUTED_STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN`

## Research question

Can a small, theory-signed set of causal trend-state features rank a broad
cross-section of stocks by next-quarter return well enough to justify a
long-only, equal-weight top-quartile retrospective OOS replay?

This lane is deliberately smaller and more interpretable than a general ML
pipeline. It opens one regularized linear ranker and one fixed-sign composite
benchmark. It does not open PCA selection, nonlinear learners, short exposure,
leverage, portfolio optimization, live advice, or execution automation.

## Evidence sequence and data boundary

| Stage | Feature/signal quarters | Target quarters | Authority |
|---|---|---|---|
| Warm-up | 2016 | none | Indicators only |
| TRAIN | 2017Q1-2020Q3 | 2017Q2-2020Q4 | Selection and nomination |
| Retrospective OOS | 2020Q4-2023Q3 | 2021Q1-2023Q4 | Frozen replay only if every TRAIN gate passes |
| Unqueried | 2024 onward | none | Must remain inaccessible to this lane |

The TRAIN runner may query only through `2020-12-31`. The OOS runner must
refuse to run without a frozen nomination file produced by the TRAIN runner.
It may then query through `2023-12-29`, but no later. All pulls use Alpaca
adjusted daily OHLCV and explicit as-of timestamp
`2026-08-07 17:30:00 America/New_York`.

The frozen registry is the union of the existing 22-name Operator Hypothesis
Lab registry and the non-overlapping 100-name breadth registry. Coverage
failures are recorded and never replaced. Eligibility requires complete SPY
session coverage inside the queried interval, valid OHLCV, sufficient warm-up,
and a valid next-quarter target. Retrospective OOS may retain only TRAIN-
eligible identities with complete OOS coverage; at least 80% of the frozen
TRAIN identities and at least 20 assets per quarter must remain.

This registry is known with hindsight and therefore survivor-biased. The lane
can test mechanics and cross-sectional stability, not claim a production-ready
point-in-time universe.

## Causal observation and return timing

At each completed quarter-end close `t`, every feature uses data available at
or before `t`. A selected name enters at the first adjusted open of the next
quarter and exits at that quarter's final adjusted open. The target return is:

`r[i,q+1] = Open[i,last(q+1)] / Open[i,first(q+1)] - 1`

The supervised target is stock return minus the equal-weight eligible-universe
return in the same target quarter. This asks the model to rank relative winners
rather than merely rediscover the broad market drift. The final open-to-close
interval of each quarter is intentionally unowned so that every target remains
inside a single, fully observed quarter.

## Frozen features

Exactly six features are computed from completed adjusted closes:

1. **12-1 momentum**: `log(C[t-21] / C[t-252])`.
2. **Sector-relative six-month momentum**: the asset's 126-session log return
   minus the equal-weight mean of the same quantity among contemporaneously
   eligible names in its registered sector. A sector requires at least three
   eligible members.
3. **Slow-trend slope**: `(SMA200[t] - SMA200[t-20]) / ATR20[t]`.
4. **Short-term extension**: `(log(C[t]) - mean(log(C[t-19:t]))) /
   sd(log(C[t-19:t]))`.
5. **Volatility ratio**: `RV20[t] / RV126[t]`, where `RVn` is the sample
   standard deviation of daily log returns over `n` sessions.
6. **252-session high proximity**: `C[t] / max(C[t-251:t])`.

No feature may be added, removed, lag-changed, or sign-flipped after TRAIN
outcomes are observed under identifier `HYP-MOM-04.1`.

## Frozen preprocessing and comparators

Each feature is converted within each signal quarter to a rank-normal score:

`z_rank = Phi^-1((rank_average - 0.5) / n)`

This prevents scale-dominant features and uses only the contemporaneous
cross-section. TRAIN pooled means and standard deviations are then frozen and
applied to OOS scores.

The non-learned benchmark is the equal-weight theory-signed composite:

`+ momentum12_1 + sector_relative126 + slow_slope - extension20
 - volatility_ratio + high_proximity252`

Higher composite or ridge score always means more attractive. Quartile 4 is
the only investable tail; quartiles may not be selected after inspection.

## Ridge model and TRAIN selection

The ridge objective includes an unpenalized intercept and penalized feature
coefficients. The frozen lambda grid is `0.01, 0.1, 1, 10, 100`.

Lambda selection uses expanding, time-ordered cross-validation across the 15
TRAIN signal quarters:

- first 6 quarters train, next 3 validate;
- first 9 quarters train, next 3 validate;
- first 12 quarters train, final 3 validate.

The selection metric is mean per-quarter Spearman rank information coefficient
between score and next-quarter relative return. The largest lambda within one
standard error of the best mean score is selected. The final scaler and model
are then fit once on all TRAIN rows.

Supporting diagnostics do not select the model: per-quarter rank IC,
single-feature quartile sorts, quarterly Fama-MacBeth OLS coefficient signs,
and a 500-draw within-quarter target-permutation control that repeats the full
lambda-selection and final-fit procedure.

## TRAIN nomination gates

Retrospective OOS is structurally blocked unless all gates pass:

1. all registry, data, date-boundary, feature-timing, and target-timing
   integrity checks pass;
2. at least 12 TRAIN quarters and at least 20 assets per quarter are complete;
3. expanding-CV mean rank IC is positive and at least 60% of validation-quarter
   ICs are positive;
4. final-model TRAIN top-quartile excess return is positive on average and in
   at least 60% of quarters;
5. mean TRAIN quartile-4 minus quartile-1 return is positive;
6. the observed TRAIN top-quartile excess statistic is at or above the 90th
   percentile of the full-procedure permutation distribution;
7. no registered sector supplies more than 35% of positive selected-name
   contribution.

Quarter-block uncertainty intervals and coefficient stability are reported,
but are not additional pass/fail gates because 15 TRAIN quarters are too few
to make a lower confidence bound a proportionate hard requirement.

## Frozen retrospective OOS replay

If nominated, each target quarter invests equally in the score's top quartile,
rebalances only at quarter boundaries, and reinvests prior profit or loss. It
starts at wealth 1.0, holds cash only when no valid selection exists, and pays
5 bp per side in the primary view and 10 bp per side in stress.

Required comparators are:

- the fixed-sign composite's top quartile;
- the equal-weight eligible universe;
- SPY buy-and-hold over the same retrospective OOS interval; and
- 500 equal-count random quarterly portfolios.

Required evidence includes bar- and selection-level data, quarterly and total
return, Sharpe, maximum drawdown, hit rate, payoff asymmetry, turnover, sector
concentration, cost stress, score calibration, rank IC, random-control rank,
and representative best, median, and worst quarter tapes. Passing TRAIN only
authorizes this retrospective replay; OOS results do not create live or
portfolio authority and may not be used to retune `04.1`.
