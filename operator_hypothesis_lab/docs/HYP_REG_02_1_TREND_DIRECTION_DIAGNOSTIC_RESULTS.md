# HYP-REG-02.1 Trend-Direction Diagnostic Results

Status: `STOP_TREND_DIRECTION_GATES_FAILED_JOINT_NOT_RUN`

## Question

Can one fixed, causal, scale-free trend score provide direction information
that is useful on its own before it is combined with the accepted ATR%
movement-magnitude sensor?

The frozen score was:

\[
T_t=\log(SMA_{20,t}/SMA_{60,t}).
\]

Positive scores predicted `UP`; negative scores predicted `DOWN`. The score
was known after close `t`, and every target began at the next open. No strategy
entry, exit, cost, capital, leverage, P&L, Sharpe, drawdown, or portfolio
outcome was calculated.

## Frozen Evidence

- 26 assets copied exactly from `HYP-REG-01.1`.
- Alpaca adjusted daily OHLCV queried from 2016-01-04 through 2023-12-29 with
  explicit as-of `2026-08-14 17:30:00 America/New_York`.
- Development observations: 2018-01-02 through 2023-12-29.
- 2024-01-02 and later remained sealed.
- Forward open-to-open direction targets at 5, 20, and 63 sessions.
- Deterministic horizon-spaced non-overlapping samples.
- Two fixed descriptive comparators: `log(close/SMA60)` and 63-session return.
- 200 deterministic within-asset, within-calendar-year circular timing
  controls.

## Primary Readout

| Horizon | Median Spearman | Positive assets | Balanced accuracy | Up recall | Down recall | Median Q5-Q1 return spread |
|---:|---:|---:|---:|---:|---:|---:|
| 5 | -0.048 | 2 / 26 | 0.492 | 0.611 | 0.364 | -0.092% |
| 20 | -0.166 | 3 / 26 | 0.452 | 0.583 | 0.304 | -2.266% |
| 63 | -0.155 | 6 / 26 | 0.452 | 0.571 | 0.354 | -5.299% |

The sign rule often predicted `UP` because equities spent much of this period
with SMA20 above SMA60. It therefore recalled a majority of positive targets,
but it missed most negative targets. Balanced accuracy remained below 0.50 at
the two principal horizons.

The continuous evidence was more damaging than the class imbalance alone:
higher trend scores were followed by lower returns at the panel median, and
the causal score's Q5-Q1 ordering was negative at every horizon. The same
broad inverse association also appeared in both fixed comparators, so this is
not a peculiarity of the SMA20/SMA60 ratio alone.

## Stability and Falsification

- Median per-asset Spearman was negative in all six calendar years at H20 and
  all six calendar years at H63.
- The real H20 and H63 panel alignments ranked at the 0th percentile of the
  200 circular controls.
- Only the integrity gate passed. The panel association, cross-asset breadth,
  balanced direction, quintile ordering, calendar stability, and placebo
  gates all failed.

The circular result should not be read as proof that a mechanically reversed
score is alpha. It says the frozen directional hypothesis was worse than its
own deliberately misaligned controls. Reversing the score after seeing that
result would create a new, retrospective mean-reversion hypothesis and would
require a fresh theory, contract, and evidence boundary.

## Decision

Record `STOP_TREND_DIRECTION_GATES_FAILED_JOINT_NOT_RUN`.

Because `HYP-REG-02.1` did not pass all seven gates, the conditional
`HYP-REG-02.2` ATR% complementarity audit was not run. The accepted
`HYP-REG-01.1` volatility-magnitude classifier remains unchanged; this result
only rejects the fixed SMA20/SMA60 score as the proposed orthogonal direction
sensor on the frozen development panel.

## Artifacts

- Frozen contract:
  `docs/GEN5_HYP_REG_02_TREND_DIRECTION_DIAGNOSTIC_CONTRACT.md`
- Registry:
  `operator_hypothesis_lab/registries/hyp_reg_02_1_trend_direction_registry.csv`
- Runner:
  `operator_hypothesis_lab/scripts/run_hyp_reg_02_1_trend_direction.R`
- Ignored evidence packet:
  `runs/research_workbench/operator_hypothesis_lab/hyp_reg_02_1_trend_direction_20260814/`
- Evidence deck:
  `operator_hypothesis_lab/presentations/hyp_reg_02_1_trend_direction_diagnostic_evidence.pptx`
