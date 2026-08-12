# HYP-MOM-04.2 Feature Atlas Contract

Status: `FROZEN_EXECUTED`

## Research question

Can a small, interpretable atlas of causal price, trend, path, risk, relative-
strength, and participation features identify a feature family or predefined
feature basket whose next-quarter cross-sectional relationship transports
through time inside TRAIN?

This is a derivative of `HYP-MOM-04.1`, not a repair of its failed expanding-
validation gate. `HYP-MOM-04.1` remains frozen with status
`STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN`.

## Evidence boundary

- Universe: the coverage-eligible subset from the passing September 2020 SPY
  deployment-universe audit.
- Bars: Alpaca adjusted daily OHLCV only.
- Query interval: `2016-01-04` through `2020-12-31`.
- Signal quarters: `2017Q1` through `2020Q3` (15 quarters).
- Target: next-quarter open-to-open return minus the same-quarter eligible-
  universe mean return.
- OOS: all observations dated `2021-01-01` or later remain unqueried.
- The point-in-time source, identity rules, sectors, exact-session coverage,
  and data gates from the deployment-universe audit remain authoritative.

The effective temporal sample is 15 quarters, not the number of stock-quarter
rows. Cross-sectional observations within a quarter share the same market
environment and must not be presented as independent temporal replications.

## Frozen feature atlas

All features use information available at the close of the signal quarter.
Returns are log returns unless explicitly described otherwise.

| Family | Frozen features |
|---|---|
| Momentum level | `ret21`, `ret63`, `ret126`, `ret252`, `momentum12_1`, `momentum_accel63_126`, `positive_month_fraction12` |
| Trend quality | `slope63_atr`, `slow_slope_atr`, `trend_r2_63`, `efficiency63`, `efficiency126` |
| Trend state / breakout | `ma50_200_atr`, `price_sma50_atr`, `price_sma200_atr`, `high_proximity63`, `high_proximity252` |
| Path / drawdown | `current_drawdown252`, `max_drawdown126`, `recovery_from_low252`, `extension20` |
| Risk | `rv20`, `rv126`, `volatility_ratio`, `downside_vol63`, `atr20_pct` |
| Participation | `volume_ratio20_126`, `up_volume_share63`, `price_volume_corr63` |
| Relative strength | `beta126`, `market_relative126`, `residual_momentum126`, `sector_relative126` |

Every feature is rank-normalized within its signal quarter before modeling.
Raw values are retained for human-facing scatter and binned-response plots.

## Human feature diagnostics

For every feature, produce:

1. raw feature versus next-quarter relative-return scatter with transparent
   points and decile-mean overlay;
2. decile return curve and top-minus-bottom spread;
3. per-quarter Spearman rank IC;
4. mean and median IC, positive-quarter fraction, and sign stability;
5. rank-feature redundancy against every other feature; and
6. explicit warnings that pooled point clouds do not create additional
   independent quarters.

The scatterplots are descriptive diagnostics. They are not independent tests
and do not authorize feature inclusion by visual appeal.

## Frozen candidate baskets

No arbitrary subset enumeration is permitted. Only these nine candidates may
enter the search:

1. `RIDGE_ORIGINAL_6`: the six `HYP-MOM-04.1` concepts.
2. `RIDGE_MOMENTUM_LEVEL`.
3. `RIDGE_TREND_QUALITY`.
4. `RIDGE_RELATIVE_STRENGTH`.
5. `RIDGE_BREAKOUT_STATE`.
6. `RIDGE_RISK_PATH`.
7. `RIDGE_PARTICIPATION`.
8. `RIDGE_DIVERSE_CORE`.
9. `FIXED_THEORY_CORE`: an equal-weight fixed-sign composite with no fitted
   coefficients.

Ridge candidates use the frozen lambda grid `0.01, 0.1, 1, 10, 100`. Basket
composition and fixed-theory signs live in the engine contract and may not be
changed after outcomes are inspected.

## Nested time-ordered selection

Outer validation uses two non-overlapping three-quarter blocks:

- train first 9 quarters, validate quarters 10-12;
- train first 12 quarters, validate quarters 13-15.

Within each outer training window, candidate and lambda selection uses only
earlier expanding inner folds:

- with 9 outer-training quarters: train 1-6, validate 7-9;
- with 12 outer-training quarters: train 1-6 / validate 7-9 and train 1-9 /
  validate 10-12.

Selection maximizes mean inner-validation rank IC. Exact ties prefer fewer
features, then stronger Ridge regularization. The selected candidate is then
refit on the complete outer-training window and scored on the untouched outer
block.

## Full-search null

Run 200 deterministic permutations. Within each signal quarter, shuffle the
relative-return target across identities, preserving features, quarter sizes,
and the target distribution. For every draw, repeat the complete inner basket
and lambda selection plus outer validation. The null statistic is mean outer-
validation rank IC. This tests the search procedure, not a basket selected
after the fact.

## TRAIN promotion gates

All gates are conjunctive:

1. `G1_INTEGRITY`: source audit, boundary, chronology, and finite-feature
   checks pass.
2. `G2_SAMPLE`: all 15 quarters and at least 400 eligible identities are
   present, with at least 20 identities per quarter.
3. `G3_OUTER_IC`: mean outer rank IC is positive and at least 4 of 6 outer
   quarters have positive IC.
4. `G4_BLOCK_TRANSPORT`: each three-quarter outer block has positive mean IC.
5. `G5_OUTER_Q4_EXCESS`: mean selected top-quartile excess is positive and at
   least 4 of 6 quarters are positive.
6. `G6_SEARCH_ADJUSTED`: full-search permutation p-value is at most `0.05`.
7. `G7_ORIGINAL_CHALLENGER`: selected nested performance exceeds the frozen
   `RIDGE_ORIGINAL_6` outer mean IC.
8. `G8_SECTOR_CONCENTRATION`: no sector contributes more than 35% of positive
   selected top-quartile outer excess.
9. `G9_SELECTION_STABILITY`: the same candidate is selected in both outer
   folds and, for Ridge, at least 60% of its coefficients keep the same
   nonzero sign across the two outer fits; the fixed-sign candidate passes its
   coefficient-sign condition by construction.

Failure of any gate records `STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN`. Passing all
gates records `TRAIN_NOMINATED_OOS_STILL_LOCKED`; opening OOS would require a
separate explicit operator decision.

## Required evidence

- frozen feature dictionary and basket registry;
- complete feature panel and integrity ledger;
- feature scorecard, quarterly IC matrix, binned response, and redundancy
  outputs;
- all scatter-atlas sheets;
- inner selection and outer prediction ledgers;
- full-search permutation distribution and gate matrix;
- concise report, slide deck, progress-log entry, and dialogue-index entry.
