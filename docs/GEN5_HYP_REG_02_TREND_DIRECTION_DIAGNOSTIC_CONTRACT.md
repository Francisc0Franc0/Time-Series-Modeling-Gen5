# HYP-REG-02 Trend-Direction Diagnostic Contract

Status: `FROZEN_FOR_DIAGNOSTIC_EXECUTION`

## Where This Fits

`HYP-REG-01.1` established a causal predictor of future movement magnitude,
while `HYP-REG-01.2` showed that a valid magnitude classifier was not, by
itself, a useful veto on daily SMA8/SMA14 entries. `HYP-REG-02` therefore tests
an economically distinct axis: direction. It remains a strategy-independent
diagnostic until a later, separately frozen decision explicitly opens a
trading overlay.

## Frozen Sequence

1. `HYP-REG-02.1`: validate one continuous trend-direction score without
   strategy return, P&L, entry, exit, cost, capital, leverage, or allocation.
2. `HYP-REG-02.2`: run only if every `02.1` gate passes; measure whether the
   fixed trend score contributes distinct directional information inside the
   accepted `HYP-REG-01.1` ATR% states.
3. Stop for operator discussion. Neither diagnostic may automatically select
   a state combination or authorize a strategy replay.

## Universe and Evidence Boundary

- Registry: 26 predeclared assets copied unchanged from `HYP-REG-01.1`—24
  stocks plus reference ETFs SPY and QQQ.
- Query authority: Alpaca adjusted daily OHLCV through the established Gen5
  data layer.
- Explicit as-of timestamp: `2026-08-14 17:30:00 America/New_York`.
- Query start: 2016-01-04, providing prehistory for all rolling calculations.
- DEVELOPMENT analysis: 2018-01-02 through 2023-12-29.
- Confirmation seal: 2024-01-02 and later are prohibited.
- No missing session is imputed.

## HYP-REG-02.1 Primary Score

For adjusted close (C_t), define trailing simple moving averages using only
observations available at close (t):

\[
SMA_{n,t}=\frac{1}{n}\sum_{j=0}^{n-1}C_{t-j}.
\]

The frozen continuous score is:

\[
T_t=\log\left(\frac{SMA_{20,t}}{SMA_{60,t}}\right).
\]

- (T_t\geq0) predicts `UP`.
- (T_t<0) predicts `DOWN`.
- No deadband, hysteresis, grid, optimized threshold, or parameter selection is
  permitted.
- A causal prior-252-session percentile of (T_t), excluding the current row,
  is used only for descriptive quintile ordering.

The 20/60 pair is frozen because it is slower than the later candidate
SMA8/SMA14 trading policy, responsive enough for swing-to-quarterly horizons,
signed, scale-free, and directly interpretable. It is not claimed to be
statistically independent of ATR%; that relationship is measured in `02.2`.

## Fixed Diagnostic Comparators

The primary score is reported beside two predeclared signed path measures:

\[
B^{price}_t=\log(C_t/SMA_{60,t})
\]

and

\[
B^{return}_t=\log(C_t/C_{t-63}).
\]

Comparators are context, not alternative policies and not a winner-search.
They do not alter the primary gates.

## Causal Forward-Direction Target

A score is known only after close (t). The direction target begins at the
next executable open and spans (h\) completed open-to-open sessions:

\[
R_{t,h}=\log\left(\frac{O_{t+1+h}}{O_{t+1}}\right),
\qquad h\in\{5,20,63\}.
\]

This is a signed price-response measurement, not a strategy return. Rows whose
entry or exit open is unavailable or whose exit reaches 2024 are excluded.

For inference, each horizon uses a deterministic horizon-spaced sample anchored
to the first DEVELOPMENT session. Thus no two retained (R_{t,h}) intervals
for one asset and horizon overlap.

## HYP-REG-02.1 Measurements

For each asset and horizon:

- Spearman association between continuous score and forward return;
- raw directional accuracy;
- up recall, down recall, and balanced accuracy;
- causal top-quintile minus bottom-quintile median forward-return spread;
- score-sign occupancy and effective non-overlapping sample size.

Panel summaries report medians and asset breadth. Calendar breadth uses the
median asset-year Spearman within each year. Two hundred deterministic circular
score shifts within asset-year preserve score distribution and local path
structure while breaking the true calendar alignment.

## HYP-REG-02.1 Frozen Gates

All gates must pass before `02.2` may run:

1. **Integrity:** 26/26 assets; required prehistory; no duplicate or future
   rows; complete causal targets and effective sample counts.
2. **Continuous association:** panel-median primary Spearman is positive at all
   three horizons and at least `0.05` at H20 and H63.
3. **Asset breadth:** at least 18/26 assets have positive primary Spearman at
   both H20 and H63.
4. **Balanced direction:** panel-median balanced accuracy is at least `0.52`,
   with median up recall and down recall each above `0.50`, at H20 and H63.
5. **Quintile ordering:** panel-median Q5-minus-Q1 return spread is positive at
   all horizons and at least 18/26 assets have a positive spread at H20 and
   H63.
6. **Calendar breadth:** panel-median asset-year Spearman is positive in at
   least four of six years at both H20 and H63.
7. **Alignment specificity:** the actual panel-median Spearman is at or above
   the 90th percentile of 200 circular-score controls at both H20 and H63.

Failure records `STOP_TREND_DIRECTION_GATES_FAILED_JOINT_NOT_RUN`.

## Conditional HYP-REG-02.2 ATR% Complementarity Audit

If and only if `02.1` passes, join the accepted `HYP-REG-01.1` state and ATR%
percentile by exact symbol and signal date. Do not recompute or retune ATR.

Report:

- per-asset Spearman between (T_t) and ATR% percentile;
- trend-score Spearman and sign diagnostics separately inside `LOW`, `MEDIUM`,
  and `HIGH`;
- a fixed 2x3 map of trend sign (`DOWN`/`UP`) by ATR state, showing sample
  count, median signed return, up rate, and median absolute return;
- whether ATR state continues to order absolute forward movement inside both
  trend signs.

The joint diagnostic records `COMPLEMENTARY_AXES` only if all hold at H20 and
H63:

1. median absolute trend/ATR Spearman is below `0.35`;
2. within-state trend Spearman is positive in all three ATR states at H20 and
   at least two of three at H63;
3. `UP` minus `DOWN` median forward return is positive in every ATR state;
4. `HIGH` minus `LOW` median absolute return is positive inside both trend
   signs.

Otherwise record `STOP_JOINT_DIAGNOSTIC_NO_COMPLEMENTARITY`. Neither result
grants permission to choose favorable cells or replay a strategy.

## Prohibited Scope

Do not:

- scan SMA horizons, thresholds, deadbands, transformations, targets, assets,
  years, or state combinations;
- use overlapping rows for inferential gates;
- calculate strategy P&L, Sharpe, drawdown, hit rate by trade, costs, leverage,
  allocation, or buy-and-hold comparisons;
- access 2024+;
- form a portfolio or change advice/live behavior.
