# LIT-MR-05.1 Kalman Dynamic-Regression Triplet POC Contract

## Status

`FROZEN_BEFORE_IMPLEMENTATION`

`LIT-MR-05.1` is the textbook extension of `LIT-MR-04.1` from one regressor
to two. It is a dynamic multiple regression, not a symmetric Johansen
cointegration estimator and not a replacement for `LIT-MR-03.1`.

## Research Question

After the shared causal filter passes structural implementation tests, can a
fixed-orientation dynamic regression of EWC on EWA and IGE produce
economically coherent innovations that converge and support the same bounded
long/short rule after costs?

## Model and Important Asymmetry

Let

\[
\mathbf{x}_t=[P_{\mathrm{EWA},t},P_{\mathrm{IGE},t},1],\qquad
y_t=P_{\mathrm{EWC},t}.
\]

Then

\[
y_t=\mathbf{x}_t
\begin{bmatrix}
\beta_{\mathrm{EWA},t}\\
\beta_{\mathrm{IGE},t}\\
\alpha_t
\end{bmatrix}
+\epsilon_t,
\]

with the same random-walk state, pre-update innovation, innovation variance,
Kalman gain, and posterior update as `LIT-MR-04.1`.

The orientation matters: regressing EWC on EWA and IGE is not algebraically
equivalent to choosing a different response. Johansen estimates a subspace;
this Kalman exercise estimates one conditional equation. Therefore the
response and regressor order are frozen before outcomes and no alternate
orientation is inspected.

## Frozen Gen5 Translation

- Provider, as-of, TRAIN, DEVELOPMENT, sealed CONFIRMATION, adjusted raw-price
  levels, 252-session warm-up, \(\delta=0.0001\), initialization, \(P_0\),
  \(R\), and scale-aware \(Q\) are identical to `LIT-MR-04.1`.
- Orientation: `EWC ~ EWA + IGE`.
- Rationale: EWA and EWC are Chan's country-equity pair; IGE supplies a
  global natural-resource exposure that may absorb a shared commodity factor.
- The identity is a single predeclared lesson example. No triplet atlas,
  orientation search, or outcome ranking is opened.

## Frozen Trading Rule

The pre-update \(z_t\), \(+/-1\) entries, zero-crossing exit, no same-bar
reversal, next-open execution, daily rehedging, 5/10 bp turnover costs, and
100 bp annualized short-leg borrow stress are identical to `LIT-MR-04.1`.

The long-spread share vector is
\([1,-\beta_{\mathrm{EWA},t},-\beta_{\mathrm{IGE},t}]\). At the next open,
gross-normalize its dollar exposures:

\[
\mathbf{w}_{t+1}(d)=
d\frac{
[P_{\mathrm{EWC}}^{O},
-\beta_{\mathrm{EWA},t}P_{\mathrm{EWA}}^{O},
-\beta_{\mathrm{IGE},t}P_{\mathrm{IGE}}^{O}]
}{
|P_{\mathrm{EWC}}^{O}|+
|\beta_{\mathrm{EWA},t}P_{\mathrm{EWA}}^{O}|+
|\beta_{\mathrm{IGE},t}P_{\mathrm{IGE}}^{O}|
}.
\]

This is still a daily swing exercise. It opens no intraday, portfolio, or live
scope.

## Frozen Comparator

A trailing 20-session multiple OLS fit through \(t-1\) predicts EWC at \(t\).
The packet reports the same forecast, calibration, coefficient-path, and
turnover diagnostics as `LIT-MR-04.1`, for both slopes. The comparator is
diagnostic, not another strategy.

## TRAIN Gates

All eight are required before DEVELOPMENT strategy evaluation:

1. **Integrity and causality:** the same data, timing, accounting, and sealed
   partition checks as `LIT-MR-04.1`.
2. **Finite filter:** at least 95% finite post-warm-up state, innovation,
   positive innovation variance, and invested weights.
3. **Triplet semantics:** the long-spread vector has at least one positive and
   one negative next-open dollar leg on at least 95% of post-warm-up rows.
4. **Two-sided support:** at least 24 completed trades, including at least
   eight long and eight short trades.
5. **Cost-aware mean:** positive primary-cost mean completed-trade return.
6. **Return uncertainty:** positive seeded 90% moving-block-bootstrap lower
   bound for that mean.
7. **Random-sign control:** observed mean exceeds the seeded 90th percentile
   from random direction flips with identical timing.
8. **Forward convergence:** negative pre-update-z/next-five-session
   fixed-posterior-vector correlation with seeded 90% bootstrap upper bound
   below zero.

As in `04.1`, gates 1-3 are structural and gates 4-8 test the trading
interpretation. Predictor conditioning, coefficient turnover, innovation
calibration, rolling-OLS comparison, stress costs, performance, and
directional hit rates remain mandatory diagnostics rather than hidden gates.
The entire gate design is Gen5-authored.

## Leakage-Safe Sequence

1. Implement and unit-test the shared scalar-observation Kalman recursion.
2. Complete the `04.1` pair's structural checks.
3. Query only this triplet's TRAIN bars and run `05.1` causally.
4. Evaluate its frozen conjunction once.
5. Query DEVELOPMENT for strategy evaluation only after a full TRAIN pass.
6. If opened, update the state recursively using only prior observations while
   keeping \(Q\), \(R\), thresholds, costs, and rule frozen.
7. Keep 2024+ sealed.

Pair profitability is not a prerequisite for this triplet lesson. A failure
of the shared filter's arithmetic, causality, or finite-state checks is.

## Stop States

- Structural/filter failure:
  `STOP_LIT_MR_05_1_FILTER_STRUCTURE`.
- Structurally valid but no full TRAIN strategy pass:
  `STOP_LIT_MR_05_1_TRAIN_STRATEGY`.
- Full TRAIN pass and one DEVELOPMENT replay:
  `OOS_DEVELOPMENT_COMPLETE_LIT_MR_05_1`.

None authorizes orientation search, triplet mining, confirmation, allocation,
or live behavior.
