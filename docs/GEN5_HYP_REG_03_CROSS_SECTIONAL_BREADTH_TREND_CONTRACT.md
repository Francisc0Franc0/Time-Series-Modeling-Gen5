# HYP-REG-03.1 Cross-Sectional Sector-Breadth Trend Contract

Status: `FROZEN_FOR_DIAGNOSTIC_EXECUTION`

## Where This Fits

`HYP-REG-02.1` rejected `log(SMA20/SMA60)` as a standalone per-asset direction
sensor. `HYP-REG-03.1` does not tune or invert that result. It asks a different
question: can broad participation across economically distinct sector ETFs
reveal market direction or trend decay that one cap-weighted index or one stock
can conceal?

This family is commonly described as **market breadth**, **participation**, or
a **diffusion index**. S&P Dow Jones Indices, for example, describes the share
of constituents above a moving average as performance breadth. The operator's
specific inspiration was a Reddit comment that recommended advance/decline or
the percentage of stocks above their 20-day average and emphasized breadth
deterioration while an index still grinds upward. The linked page presented bot
verification during source inspection, after which the operator supplied the
comment verbatim in this task.

## Scope Boundary

This is a strategy-independent direction diagnostic. It may calculate forward
returns only as labels for sensor validation. It may not calculate or interpret
entries, exits, costs, capital, leverage, strategy P&L, Sharpe, drawdown,
portfolio performance, allocation, advice, or live behavior.

No `HYP-REG-01.1` ATR% state is joined in this slice. Any volatility-direction
combination requires a separately frozen decision after this diagnostic.

## Evidence Boundary

- Explicit as-of timestamp:
  `2026-08-14 17:30:00 America/New_York`.
- Query start: 2016-01-04.
- Development analysis: 2018-01-02 through 2023-12-29.
- Confirmation seal: 2024-01-02 and later are prohibited.
- Provider: established Gen5 Alpaca adjusted daily OHLCV query path.
- Missing sessions are not imputed.

## Fixed Cross-Sectional Estimator Universe

The signal is built from ten long-lived Select Sector SPDR ETFs:

`XLB, XLE, XLF, XLI, XLK, XLP, XLRE, XLU, XLV, XLY`.

They provide equal-vote sector participation without requiring a historical
stock-constituent reconstruction. `XLC` is excluded because its 2018 launch and
the accompanying sector reclassification would introduce a structural history
break inside the diagnostic window.

This is intentionally a **sector-diffusion proxy**, not a claim to exact
point-in-time S&P 500 constituent breadth. ETF index maintenance remains inside
each historical series. That improves practical point-in-time hygiene but
coarsens the signal to ten sector votes.

## Fixed Target Universe

The 26 targets are copied unchanged from `HYP-REG-02.1`: 24 diverse stocks plus
SPY and QQQ. The common breadth signal contains no target asset's own OHLCV
series. A target may economically overlap a sector ETF; that is intentional
market-context exposure, not a claim of statistical independence.

## Frozen Signal Construction

For sector ETF (i), define its causal distance from the 20-session mean:

\[
q_{i,t}=\log\left(\frac{C_{i,t}}{SMA_{20,i,t}}\right).
\]

On dates where all ten sector ETFs are available, define:

\[
B_t=\operatorname{median}_{i=1}^{10}(q_{i,t})
\]

and the descriptive participation share:

\[
P_t=\frac{1}{10}\sum_{i=1}^{10}\mathbf{1}[q_{i,t}\geq0].
\]

`B_t` is the primary direction score. `B_t >= 0` predicts `UP`; `B_t < 0`
predicts `DOWN`. The median is scale-free, prevents one sector from dominating
the signal, and preserves continuous information that the ten-vote `P_t`
measure would quantize into 10-percentage-point steps. `P_t` remains the
plain-English participation companion closest to the source inspiration.

The predeclared breadth impulse is:

\[
D_t=B_t-B_{t-20}.
\]

`D_t < 0` means the cross-sectional trend is decaying relative to 20 sessions
earlier. The 20-session difference is frozen as a one-month swing diagnostic,
not selected from a grid.

A causal prior-252-session percentile of `B_t`, excluding the current row, is
used for quintile ordering.

## Causal Targets and Samples

For each target asset and horizon `h` in `{5, 20, 63}`:

\[
R_{a,t,h}=\log\left(\frac{O_{a,t+1+h}}{O_{a,t+1}}\right).
\]

- The signal is known after close `t`.
- The target begins at next open `t+1`.
- The exit is the open after `h` complete open-to-open intervals.
- Primary inference uses deterministic horizon-spaced non-overlapping dates.

## Frozen Hidden-Deterioration Audit

For SPY only, define its own descriptive trend as
`log(SMA20_SPY/SMA60_SPY) >= 0`. Among those nominally positive-trend dates,
compare forward returns when:

- breadth is decaying: `D_t < 0`;
- breadth is stable or improving: `D_t >= 0`.

This audit directly tests the motivating claim that participation can weaken
while the headline index still appears to trend upward. It is a conditional
diagnostic, not an entry or exit rule.

## Circular Timing Controls

Run 200 deterministic circular shifts of the common `B_t` series separately
within each calendar year. Apply each shifted series to all targets while
preserving target returns and the signal's within-year distribution. Compare
the actual H20 and H63 median per-target Spearman with these controls.

## Frozen Gates

All eight gates must pass for `DIAGNOSTIC_COMPLETE_STOP_BEFORE_JOINT_FILTER`:

1. **Integrity:** all 10 signal ETFs and all 26 targets pass coverage and the
   2024+ seal; every analysis date has ten sector inputs.
2. **Panel association:** median per-target Spearman is positive at all three
   horizons and at least `0.05` at H20 and H63.
3. **Target breadth:** at least `18 / 26` targets have positive Spearman at H20
   and H63.
4. **Directional balance:** median balanced accuracy is at least `0.52`, and
   median UP and DOWN recall each exceed `0.50`, at H20 and H63.
5. **Quintile ordering:** median Q5-minus-Q1 forward return is positive at all
   horizons and positive for at least `18 / 26` targets at H20 and H63.
6. **Calendar stability:** panel-median Spearman is positive in at least four
   of six calendar years at both H20 and H63.
7. **Timing falsification:** actual median Spearman is at or above the 90th
   percentile of circular controls at H20 and H63.
8. **Hidden deterioration:** on SPY-positive-trend dates, decaying breadth has
   lower median forward return than stable/improving breadth at H20 and H63,
   with a negative decay-minus-improving gap in at least four of six years at
   both horizons.

If any gate fails, record
`STOP_CROSS_SECTIONAL_BREADTH_GATES_FAILED_NO_JOINT_FILTER`.

## Source Grounding

- Operator-supplied Reddit inspiration:
  `https://www.reddit.com/r/algotrading/comments/1rvfy12/comment/oawke1k/`
- S&P Dow Jones Indices, *S&P Kensho New Economies Quarterly Commentary,
  Q1 2024*, page 1: uses the proportion of constituents above their 200-day
  moving average to characterize performance breadth.
- S&P Global Market Intelligence, *Bad breadth concerns rise as S&P 500 set to
  recover tariff-triggered losses*, June 11, 2025: illustrates how a
  cap-weighted rally can coexist with deteriorating constituent participation.
