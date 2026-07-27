# Gen5.4 X2a Two-Feature Linear Ranker Confirmation Contract

Status: frozen and authorized for implementation on 2026-07-26.

## Question

Can a pooled linear combination of the two already admitted, economically
distinct OHLCV ranking primitives improve cross-sectional ranking quality on
six fresh confirmation quarters without introducing model-search or portfolio
semantics?

This is a ranking-combination gate. It is not a strategy, long-entry rule,
exposure controller, allocation method, performance replay, or live authority.

## Fixed panel and eligibility

- Ranked candidates: the existing fixed 24-stock Gen5.4 panel.
- Context-only symbols: `SPY,QQQ,IWM,SMH,TLT,GLD`.
- Point-in-time eligibility: close at least `$5`, trailing 60-session median
  dollar volume at least `$20M`, complete backward-looking features, and at
  least 20 eligible candidates on the date.
- The panel is survivor-biased by construction because it was fixed using
  present knowledge. X2a may compare ranking methods inside this panel, but it
  may not support a claim about historical universe discovery.

## Timing and target

- Observe features through close `t`.
- Hypothetical execution timestamp: open `t+1`.
- Label endpoint: open `t+6`, giving five open-to-open intervals.
- Target: each asset's h5 return minus the same-date eligible-universe
  equal-weight h5 return.
- The target measures relative ranking quality only. It is not an absolute long
  entry label.

## Predictive inputs

Exactly two same-date eligible-universe ranks on `[0,1]`:

1. `group_relative_20_rank`
2. `intraday_minus_overnight_20_rank`

No other OHLCV feature, context symbol, news field, VIX value, option value,
macro field, interaction, symbol effect, or economic-group effect may enter the
model.

## Frozen competitors

1. Raw group-relative 20-session momentum rank.
2. Raw intraday-minus-overnight 20-session rank.
3. Fixed 50/50 average of the two ranks.
4. Pooled ordinary least-squares model:

   `relative_forward_return_h5 ~ group_relative_20_rank + intraday_minus_overnight_20_rank`

The model includes the ordinary intercept and two main effects only. It pools
eligible asset-date TRAIN rows. OOS predictions are ranked within the eligible
cross-section on each date.

## Confirmation folds

Six quarterly OOS folds: `2025Q1` through `2026Q2`.

- Each fold uses the preceding eight quarters as TRAIN.
- TRAIN rows are retained only when their label endpoint is no later than the
  TRAIN boundary. This purges the final five otherwise-crossing feature dates.
- OOS rows are retained only when their label endpoint remains inside the OOS
  quarter.
- All model fitting occurs inside the fold's TRAIN window.

The two-feature combination is new to this confirmation window, but the period
is not described as virgin history because other Gen5 hypotheses have inspected
parts of it.

## Diagnostics only

The packet may compute:

- daily Spearman rank IC;
- quarterly mean IC;
- top-quintile minus bottom-quintile relative h5 outcome;
- positive-quarter ordering counts;
- maximum economic-group and individual-symbol shares in the top quintile;
- fold coefficients;
- representative ranking tapes.

It must not compute strategy PnL, exposure, Sharpe, drawdown, turnover costs,
allocation, leverage value-add, or live advice.

## Frozen promotion gates for the linear model

All nine gates must pass:

1. Every integrity and leakage check passes.
2. Mean OOS daily rank IC is positive.
3. Quarterly mean IC is positive in at least `4 / 6` quarters.
4. Overall top-minus-bottom relative h5 outcome is positive.
5. Top-minus-bottom ordering is positive in at least `4 / 6` quarters.
6. Mean IC lift is at least `0.005` over the best of the three frozen
   non-model comparators.
7. The model's quarterly IC exceeds the best frozen non-model comparator in at
   least `4 / 6` quarters.
8. Maximum economic-group share in the model's top quintile is at most `50%`.
9. Maximum individual-symbol share in the model's top quintile is at most
   `25%`.

The "best comparator" is a predeclared conservative hurdle: the maximum of the
three frozen non-model competitors. It does not authorize choosing or tuning a
new comparator after seeing outcomes.

## Decision logic

- If all linear-model gates pass: record `PASS_X2A_TO_TOP5_POLICY_THEORY`. A
  separate top-five portfolio proof may then be designed, but is not authorized
  by this contract.
- If the fixed 50/50 composite clears the basic ranking and concentration gates
  but the trained model does not add the required lift: record
  `RETAIN_FIXED_COMPOSITE_CLOSE_ML_COMPLEXITY`.
- Otherwise: record `STOP_X2A_MULTIVARIATE_RANKING`.
- Any result dominated by one symbol, one economic group, or one quarter stops
  promotion.

PCA, HMMs, nonlinear ML, exposure scaling, portfolio replay, and live advice
remain closed.
