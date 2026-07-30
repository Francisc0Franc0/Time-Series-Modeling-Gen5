# LIT-MR-04.1 Kalman Dynamic-Regression Pair POC Contract

## Status

`COMPLETED_STOP`

## Completed Readout

The shared causal filter passed all structural gates and the pair cleared
`7 / 8` frozen TRAIN gates. Record
`STOP_LIT_MR_04_1_TRAIN_STRATEGY`.

- The pair completed 21 trades: 12 long spread and 9 short spread, below the
  frozen 24-trade support minimum.
- Mean primary-cost return was `+67.76 bp/trade`; its 90% bootstrap lower
  bound was `+42.27 bp`.
- The observed mean exceeded the random-sign 90th percentile
  (`+17.91 bp`).
- Forward-five convergence correlation was `-0.1572`, with 90% upper bound
  `-0.0436`.
- Bar-level primary-cost cumulative return was `+14.21%`, maximum drawdown
  `-5.41%`, and autocorrelation-adjusted Sharpe `0.716`.
- Spread-direction hit rate was `53.5%`; EWC absolute up/down accuracy was
  `47.6%`, confirming those are different estimands.
- The support miss stops strategy evaluation before DEVELOPMENT. The
  2021-2023 strategy interval was not queried; 2024+ remains sealed.

The evidence packet is
`runs/research_workbench/literature_grounded/lit_mr_04_1_05_1_kalman_textbook_20260729`.
The educational deck is
`presentations/gen5_lit_mr_04_1_05_1_kalman_textbook_exercises.pptx`.

`LIT-MR-04.1` is a new literature-grounded mean-reversion concept. It treats
Chan's Kalman-filter example as a textbook exercise in causal, time-varying
linear regression. It does not reopen, overwrite, or tune `LIT-MR-02.1`.

The purpose is to learn the estimator and test one exact translation honestly.
It is not a search for a profitable pair.

## Research Question

Can a causally updated dynamic regression of EWC on EWA produce calibrated,
economically coherent one-step innovations that subsequently converge, and
can a bounded long/short rule trade those innovations after costs?

## Source Model

With response \(y_t=P_{\mathrm{EWC},t}\) and regressor row
\(\mathbf{x}_t=[P_{\mathrm{EWA},t},1]\):

\[
y_t=\mathbf{x}_t\boldsymbol{\theta}_t+\epsilon_t,\qquad
\boldsymbol{\theta}_t=
\begin{bmatrix}\beta_t&\alpha_t\end{bmatrix}^{\top},
\]

\[
\boldsymbol{\theta}_t=\boldsymbol{\theta}_{t-1}+\boldsymbol{\omega}_{t-1}.
\]

The pre-update innovation and its variance are

\[
e_t=y_t-\mathbf{x}_t\widehat{\boldsymbol{\theta}}_{t|t-1},
\qquad
S_t=\mathbf{x}_tP_{t|t-1}\mathbf{x}_t^{\top}+R.
\]

The signal statistic is \(z_t=e_t/\sqrt{S_t}\). The state is updated only
after that causal forecast error is recorded:

\[
K_t=P_{t|t-1}\mathbf{x}_t^{\top}/S_t,\qquad
\widehat{\boldsymbol{\theta}}_{t|t}
=\widehat{\boldsymbol{\theta}}_{t|t-1}+K_te_t.
\]

The process is a random walk with
\(P_{t|t-1}=P_{t-1|t-1}+Q\).

## Frozen Gen5 Translation

- Provider: Alpaca adjusted daily OHLCV only.
- Explicit as-of: `2026-07-24 17:30:00`.
- Orientation: `EWC ~ EWA`; do not reverse it after seeing results.
- Price transform: raw adjusted daily price levels.
- TRAIN: `2016-01-04` through `2020-12-31`.
- DEVELOPMENT: `2021-01-01` through `2023-12-29`, queried for strategy
  evaluation only if every TRAIN gate passes.
- CONFIRMATION: begins `2024-01-01` and remains sealed.
- Warm-up: first 252 common TRAIN sessions; no signals or trades inside it.
- Initial state: ordinary least squares on the warm-up, ordered
  `[EWA slope, intercept]`.
- Initial covariance:
  \(P_0=\widehat{\sigma}^2(X^{\top}X)^{-1}\), with a deterministic
  machine-scale diagonal ridge only if needed for inversion.
- Observation variance: \(R=\widehat{\sigma}^2\), the warm-up OLS residual
  variance, floored only at machine scale.
- Source memory parameter: \(\delta=0.0001\), fixed from Chan rather than
  selected on Gen5 outcomes.
- Scale-aware process covariance:
  \(Q=\delta/(1-\delta)\operatorname{diag}(\operatorname{diag}(P_0))\).

Chan's displayed reference initialization (`theta=0`, `P=0`,
`Ve=0.001`, and `Vw=delta/(1-delta) I`) is recorded as source context, not
used as strategy authority: the fixed `Ve` is not scale invariant and the
book says its constants were chosen with hindsight. The Gen5 translation
keeps Chan's random-walk state and memory parameter while estimating scale
once, causally, from TRAIN warm-up.

## Frozen Trading Rule

1. Compute the pre-update \(z_t\) after close.
2. Enter long spread when \(z_t<-1\); enter short spread when \(z_t>+1\).
3. Exit at the first zero crossing.
4. Do not reverse on the same signal; a new entry requires a later bar.
5. Execute at the next adjusted open.
6. Use the posterior slope known after close \(t\) for that next-open hedge.
7. Rehedge daily while the position is open.
8. The long-spread share vector is \([1,-\beta_t]\). Convert it to next-open
   dollar weights and gross-normalize:

\[
\mathbf{w}_{t+1}(d)=
d\frac{[P_{\mathrm{EWC},t+1}^{O},
-\beta_tP_{\mathrm{EWA},t+1}^{O}]}
{|P_{\mathrm{EWC},t+1}^{O}|+
|\beta_tP_{\mathrm{EWA},t+1}^{O}|},
\quad d\in\{-1,+1\}.
\]

9. Charge 5 bp per one-way weight change, with 10 bp as a stress cost.
10. Apply a 100 bp annualized borrow-cost stress to negative dollar weights.

This is a daily swing exercise. It does not open intraday, scalping,
portfolio-allocation, historical-borrow-authority, live-shorting, or live
execution scope.

## Frozen Comparator

A trailing 20-session OLS fit through \(t-1\) predicts \(y_t\) and supplies an
out-of-sample forecast error. The packet compares:

- Kalman and rolling-OLS slope/intercept paths;
- one-step RMSE and mean absolute error;
- standardized-error mean, standard deviation, lag-one autocorrelation, and
  \(|z|>1\) frequency; and
- coefficient turnover.

This comparator diagnoses what the adaptive estimator changes. It does not
receive a separate strategy search, parameter selection, or promotion gate.

## TRAIN Gates

All eight are required before DEVELOPMENT strategy evaluation:

1. **Integrity and causality:** data coverage, chronology, warm-up, pre-update
   signal, next-open execution, weights, costs, and sealed partitions pass.
2. **Finite filter:** at least 95% of post-warm-up TRAIN rows have finite state,
   innovation, positive innovation variance, and finite normalized weights
   when invested.
3. **Pair semantics:** the EWA slope is positive on at least 95% of
   post-warm-up TRAIN rows, preserving an opposite-side relative-value spread.
4. **Two-sided support:** at least 24 completed trades, including at least
   eight long and eight short trades.
5. **Cost-aware mean:** primary-cost mean completed-trade return is positive.
6. **Return uncertainty:** the seeded 90% moving-block-bootstrap lower bound
   for primary-cost mean trade return is above zero.
7. **Random-sign control:** observed mean trade return exceeds the seeded
   90th percentile from random entry-direction flips with the same timing.
8. **Forward convergence:** pre-update \(z_t\) versus the next-five-session
   fixed-posterior-vector return has negative correlation and a seeded 90%
   bootstrap upper bound below zero.

Gates 1-3 are structural. Gates 4-8 test whether this particular trading
interpretation is supported. Innovation calibration, rolling-OLS comparison,
Sharpe, hit rate, P&L, drawdown, turnover, and stress-cost results are required
diagnostics but are not silently promoted to additional pass/fail gates.
These thresholds and controls are Gen5 design, not Chan's published checklist.

## Leakage-Safe Sequence

1. Query TRAIN only.
2. Initialize scale and state using only the first 252 TRAIN sessions.
3. Run the recursive filter and strategy causally through TRAIN.
4. Evaluate the frozen conjunction once.
5. If any gate fails, stop the strategy at TRAIN and do not query DEVELOPMENT
   for strategy evaluation.
6. If every gate passes, query the already-frozen DEVELOPMENT interval once;
   keep \(Q\), \(R\), thresholds, costs, and rule fixed while the state updates
   recursively from past observations.
7. Keep 2024+ sealed regardless of the result.

The structural filter implementation may still be reused by `LIT-MR-05.1`;
failure of pair profitability is not failure of the Kalman arithmetic lesson.

## Stop States

- Structural/filter failure:
  `STOP_LIT_MR_04_1_FILTER_STRUCTURE`.
- Structurally valid but no full TRAIN strategy pass:
  `STOP_LIT_MR_04_1_TRAIN_STRATEGY`.
- Full TRAIN pass and one DEVELOPMENT replay:
  `OOS_DEVELOPMENT_COMPLETE_LIT_MR_04_1`.

None authorizes parameter rescue, pair mining, confirmation, allocation, or
live behavior.
