# LIT-MOM-01.2 Audit 01: Exposure and Selection Contract

Status: `FROZEN_BEFORE_COMPARATIVE_OUTCOMES`

## Question

Did the encouraging `LIT-MOM-01.2` retrospective result contain incremental
timing and horizon-selection value, or did the long-only policy mainly capture
ordinary upward equity exposure?

## Nomenclature and authority

This is `LIT-MOM-01.2 / AUDIT_01_EXPOSURE_AND_SELECTION`. It is an attribution
audit under unchanged `01.2` mechanics, not a new decimal variant and not a new
strategy family. It may explain the inspected result; it may not tune the rule,
promote an asset, form a portfolio, query 2024+ confirmation, or open live
behavior.

## Evidence boundary

- TRAIN: 2017-01-03 through 2020-12-31.
- Retrospective audit: 2021-01-04 through 2023-12-29.
- Confirmation remains sealed from 2024-01-02.
- Universe: SHY as the worked example, all 22 Atlas 01 stocks, and only the 91
  coverage-eligible Atlas 02 stocks. Coverage failures are not replaced.
- Data: existing Alpaca adjusted daily OHLCV under the same explicit
  `as_of_timestamp`; SPY and the eleven standard sector ETFs are reference
  series only.

## Frozen primary-cost comparators

Every comparator uses 5 bp per entry and exit where applicable.

1. `BUY_AND_HOLD`: enter at the first retrospective open and exit at the final
   retrospective open.
2. `CONSTANT_EXPOSURE`: apply each strategy path's realized average invested
   fraction continuously to the asset's open-to-open return. This is an
   exposure-matched diagnostic, not an executable allocation proposal.
3. `ALWAYS_LONG_BLOCK`: use the asset's selected `H`, remain long through
   consecutive complete `H`-session blocks, and pay literal exit/re-entry
   costs. This isolates signal timing from the block mechanic and turnover.
4. `RANDOM_MATCHED_TIMING`: 1,000 seeded schedules per asset with the same
   selected `H`, completed-trade count, non-overlap constraint, and costs as
   the strategy, but randomly placed entry blocks. Each draw first chooses an
   eligible calendar phase and then samples complete non-overlapping `H` blocks
   without replacement within that phase.
5. `FIXED_250_25`: Chan's already recorded canonical literature reference,
   translated into the unchanged long-only `01.2` execution.
6. `FIXED_60_5`: the already recorded SHY-selected reference, applied
   universally without per-asset horizon selection.

No comparator is chosen after reading audit outcomes.

## Attribution readouts

For every eligible asset report:

- primary cumulative return, maximum drawdown, average exposure, trade count,
  and long-call accuracy;
- return differences versus buy-and-hold, constant exposure, always-long
  blocks, `250/25`, and `60/5`;
- percentile and one-sided empirical p-value versus matched random timing;
- daily OLS beta, annualized intercept, and R-squared versus SPY using a full
  calendar path with zero return while the strategy is in cash;
- sector-clustered 90% bootstrap intervals for median cross-asset excess
  returns, using 5,000 seeded resamples of the eleven sector clusters.

The cross-asset average and bootstrap are evidence summaries, not investable
portfolio simulations.

## Frozen environment descriptors

Each selected strategy trade is labeled using information available at its
signal close:

- SPY 60-session return: positive or non-positive;
- SPY 20-session realized volatility: above or below the TRAIN-only median;
- corresponding sector ETF 60-session return: positive or non-positive; and
- asset minus sector 60-session return: positive or non-positive.

For each state report trade count, mean primary trade return, hit rate, and
compounded trade return. Cells with fewer than 100 pooled trades or fewer than
20 contributing assets are `LOW_SUPPORT`. These labels are explanatory only;
they are not authorized filters.

## Audit scorecard

The following predeclared diagnostics are reported transparently rather than
collapsed into a strategy pass:

1. all integrity checks pass;
2. median excess return versus buy-and-hold is positive;
3. at least 55% of assets beat buy-and-hold;
4. median excess versus constant exposure is positive;
5. median excess versus always-long blocks is positive;
6. at least 55% of assets beat the median matched-random schedule;
7. median matched-random percentile exceeds 50%;
8. median selected-rule return exceeds fixed `250/25`;
9. median selected-rule return exceeds fixed `60/5`;
10. the sector-clustered 90% lower bound for median excess versus constant
    exposure is positive; and
11. median annualized SPY-regression intercept is positive with at least 55%
    positive asset intercepts.

## Interpretation discipline

- Beating buy-and-hold would be strong but is not required to show timing
  value because the strategy spends time in cash.
- Beating constant exposure and matched-random timing is the cleaner test of
  incremental timing merit.
- Positive environment cells do not authorize a filter after inspection.
- If the audit is encouraging, the next step is a separately frozen
  one-factor-at-a-time challenger and fresh validation design.
- If exposure-matched and random-timing comparisons fail, treat environment
  differences as explanation of beta capture, not as a rescue surface.
