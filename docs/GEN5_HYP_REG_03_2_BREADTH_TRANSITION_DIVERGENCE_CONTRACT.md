# HYP-REG-03.2 Breadth-Transition and Leadership-Divergence Contract

Status: `FROZEN_FOR_DIAGNOSTIC_EXECUTION`

## Where This Fits

`HYP-REG-03.1` established that ten-sector breadth is a real cross-sectional
measurement surface, but its absolute level was not a portable general
direction classifier. It left one useful clue: while SPY's own trend remained
positive, deteriorating breadth preceded a lower H20 median return.

`HYP-REG-03.2` does not tune the rejected score or invert its H63 result. It
tests the narrower mechanism that motivated the operator's question:

> While headline SPY trend remains positive, do weakening sector participation
> and lagging equal-weight leadership warn of a 20-session trend failure?

This is a market-level warning-sensor diagnostic. It is not a stock-selection
model, strategy, or volatility regime map.

## Scope Boundary

The diagnostic may use forward returns only as labels. It may not calculate or
interpret entries, exits, costs, capital, leverage, strategy P&L, Sharpe,
drawdown, portfolio performance, allocation, advice, or live behavior.

The accepted `HYP-REG-01.1` ATR% state is not joined. VIX term structure,
intraday persistence, recovery thrust, and constituent-level breadth remain
unopened hypotheses.

## Evidence Boundary

- Explicit as-of timestamp:
  `2026-08-14 17:30:00 America/New_York`.
- Query start: 2016-01-04.
- Development analysis: 2018-01-02 through 2023-12-29.
- Temporal audit halves: 2018-2020 and 2021-2023.
- Confirmation seal: 2024-01-02 and later are prohibited.
- Provider: established Gen5 Alpaca adjusted daily OHLCV query path.
- Missing sessions are not imputed.

The design was informed by the already inspected HYP-REG-03.1 window. This is
therefore a structured development diagnostic, not fresh confirmation.

## Fixed Signal Universe

Sector participation uses the same ten long-lived Select Sector SPDR ETFs:

`XLB, XLE, XLF, XLI, XLK, XLP, XLRE, XLU, XLV, XLY`.

`RSP` supplies the equal-weight S&P 500 price history and `SPY` supplies the
cap-weighted market price, visible trend context, and primary target. Their
historical ETF series preserve the index providers' contemporaneous
maintenance without reconstructing today's constituents backward.

This remains a sector and equal-weight proxy, not exact point-in-time
constituent advance/decline breadth.

## Fixed Measurements

For sector `i` after close `t`:

\[
q_{i,t}=\log(C_{i,t}/SMA_{20,i,t}).
\]

Define breadth level, participation, and cross-sector dispersion:

\[
B_t=\operatorname{median}_i(q_{i,t}),\qquad
P_t=\frac{1}{10}\sum_i 1[q_{i,t}\geq0],\qquad
X_t=Q_{0.75}(q_{i,t})-Q_{0.25}(q_{i,t}).
\]

Define the two primary transition measurements:

\[
D_t=B_t-B_{t-20}
\]

and

\[
G_t=\log(RSP_t/SPY_t)-\log(RSP_{t-20}/SPY_{t-20}).
\]

`D_t < 0` means sector breadth is weakening. `G_t < 0` means the equal-weight
market is lagging the cap-weighted index. `X_t` is evaluated only as a
continuous descriptive modifier; it is not allowed to select or redefine the
primary state after inspection.

For continuous ranking, calculate causal prior-252-session percentiles of
`D_t`, `G_t`, and `X_t`, excluding the current row. Define a fixed, unfitted
narrowing-risk score:

\[
N_t=1-\frac{pct(D_t)+pct(G_t)}{2}.
\]

Higher `N_t` means both transition measures are weak relative to their own
recent histories. No coefficient or threshold is fitted.

## Fixed Context and States

SPY visible trend is positive when:

\[
T_t=\log(SMA_{20,SPY,t}/SMA_{60,SPY,t})\geq0.
\]

Inside `T_t >= 0`, define:

- `HEALTHY`: `D_t >= 0` and `G_t >= 0`;
- `NARROWING`: `D_t < 0` and `G_t < 0`;
- `MIXED_BREADTH_WEAK`: `D_t < 0` and `G_t >= 0`;
- `MIXED_LEADERSHIP_WEAK`: `D_t >= 0` and `G_t < 0`.

Dates with negative visible SPY trend are labeled
`PRICE_TREND_NOT_POSITIVE` and excluded from the primary contrast.

The primary comparison is `NARROWING` versus `HEALTHY`. The mixed states are
reported but may not be selected after inspection.

## Fixed Target

The sole return horizon is H20:

\[
R_{t,20}=\log(O_{SPY,t+21}/O_{SPY,t+1}).
\]

- Signal and state are known after close `t`.
- The target begins at the next open.
- `DOWN` means `R_{t,20} < 0`.
- All-daily rows provide effect-size descriptions only.
- Primary dependence checks use all 20 deterministic starting offsets, each
  containing H20-spaced non-overlapping observations.

Secondary measurement targets are future 20-session changes in `B_t` and in
`log(RSP/SPY)`. They test whether the named states actually describe future
participation persistence; they are not strategy outcomes.

## Frozen Falsification and Stability Checks

1. Compare `NARROWING` with `HEALTHY` on H20 median return and DOWN rate.
2. Measure Spearman association of `D_t`, `G_t`, `N_t`, and `X_t` with H20
   return; use ROC AUC for `N_t` versus the DOWN label.
3. Repeat the state contrast for all 20 non-overlapping starting offsets.
4. Repeat it in 2018-2020 and 2021-2023 and by calendar year.
5. Run 200 deterministic within-calendar-year circular rotations of the state
   labels among positive-SPY-trend dates, preserving each year's state counts.
6. Compare future breadth and future equal-weight leadership under
   `NARROWING` and `HEALTHY` overall and in both temporal halves.

## Frozen Gates

All eight gates must pass for
`DIAGNOSTIC_COMPLETE_STOP_BEFORE_ATR_OR_STRATEGY`:

1. **Integrity:** all 12 assets have complete requested-window coverage; every
   analysis date has ten sector inputs; causal timing and the 2024+ seal hold.
2. **Primary state effect:** both states have at least 100 all-daily rows;
   `NARROWING` minus `HEALTHY` median H20 return is at most `-0.75` percentage
   points and its DOWN-rate difference is at least `+10` percentage points.
3. **Continuous ordering:** Spearman(`D_t`, return) and Spearman(`G_t`, return)
   are positive; Spearman(`N_t`, return) is negative; and DOWN AUC for `N_t` is
   at least `0.55`.
4. **Starting-offset stability:** at least 15/20 offsets contain at least five
   observations in both primary states, and at least 14/20 have both a negative
   return gap and a positive DOWN-rate gap.
5. **Temporal transport:** both 2018-2020 and 2021-2023 have a negative return
   gap and positive DOWN-rate gap.
6. **Calendar stability:** at least four of six years have both a negative
   return gap and positive DOWN-rate gap.
7. **Circular timing control:** the actual return gap is at or below the 10th
   control percentile and the actual DOWN-rate gap is at or above the 90th.
8. **State semantics:** future H20 breadth change and future H20 RSP/SPY
   relative change are both lower under `NARROWING` than `HEALTHY`, overall and
   in both temporal halves.

If any gate fails, record
`STOP_BREADTH_TRANSITION_GATES_FAILED_NO_JOINT_FILTER`.

## Source Grounding

- Operator-provided Reddit comment and dialogue decision `D130`.
- S&P Dow Jones Indices, *Worth the Weight* (July 23, 2024), on equal weighting
  and concentration as distinct views of the U.S. large-cap market.
- Paulo Maio, *Cross-sectional return dispersion and the equity premium*,
  Journal of Financial Markets 29 (2016), 87-109, for the broader proposition
  that cross-sectional dispersion can contain aggregate predictive
  information. This contract does not assume its sign transfers to sector
  depth dispersion.
