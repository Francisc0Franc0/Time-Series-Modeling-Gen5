# LIT-MR-03.1 Johansen Triplet Mean-Reversion POC Contract

## Status

`COMPLETED_STOP`

`LIT-MR-03.1` is a new literature-grounded mean-reversion concept. It extends
the pair-spread idea from `LIT-MR-02.1` to a three-instrument cointegrating
portfolio. It does not reopen or overwrite any `LIT-MR-02.1` result.

## Completed Readout

The frozen TRAIN screen completed with
`STOP_LIT_MR_03_1_NO_TRAIN_NOMINATION`.

- Five of eight predeclared triplets met the exact rank-one diagnostic.
- No triplet cleared all eight gates.
- `T01_EWA_EWC_IGE` cleared seven gates, with vector cosine `0.991`,
  half-life `10.16` sessions, 86 completed trades, and mean primary-cost
  return `+17.26 bp/trade`. It failed only robust forward convergence:
  correlation `-0.0814`, but the 95% upper bound was `+0.0282`.
- `T04_SHY_IEF_TLT` also cleared seven gates, including robust forward
  convergence, but failed cost-aware return at `-3.28 bp/trade`.
- No triplet was nominated, DEVELOPMENT was not queried for strategy
  evaluation, and CONFIRMATION remains sealed.

The generated packet is
`runs/research_workbench/literature_grounded/lit_mr_03_1_triplets_20260729`.

## Research Question

Can a predeclared daily triplet exhibit one stable cointegrating relationship
on TRAIN, support the same simple z-score convergence trade after costs, and
then retain that behavior in a genuinely OOS DEVELOPMENT window after the
cointegrating vector is frozen?

## Theory

For a price vector

\[
\mathbf{p}_t =
\begin{bmatrix}
P_{1,t} & P_{2,t} & P_{3,t}
\end{bmatrix}^{\top},
\]

cointegration rank one means there is a non-zero vector
\(\boldsymbol{\beta}\) such that

\[
s_t = \boldsymbol{\beta}^{\top}\mathbf{p}_t
\]

is stationary even though the three component price series are individually
integrated of order one.

The Johansen method starts from a vector error-correction model. With one VAR
lag and a constant:

\[
\Delta\mathbf{p}_t =
\boldsymbol{\Pi}\mathbf{p}_{t-1}+\mathbf{c}+\boldsymbol{\varepsilon}_t,
\qquad
\boldsymbol{\Pi}=\boldsymbol{\alpha}\boldsymbol{\beta}^{\top}.
\]

The rank of \(\boldsymbol{\Pi}\) is the number of independent cointegrating
relations. For three assets:

- rank 0 means no detected cointegrating vector;
- rank 1 means one three-leg relation, the target of this POC;
- rank 2 means two independent relations and is outside this minimal design;
- full rank means the level system is stationary rather than an \(I(1)\)
  cointegration problem.

The Johansen trace statistic for a null rank \(r\) is

\[
J_{\text{trace}}(r)
=-T\sum_{i=r+1}^{3}\log(1-\widehat{\lambda}_i),
\]

where the ordered generalized eigenvalues
\(\widehat{\lambda}_1\geq\widehat{\lambda}_2\geq\widehat{\lambda}_3\)
measure error-correction strength.

This implementation uses a seeded random-walk bootstrap, matched to the TRAIN
increment covariance, to obtain empirical p-values. It does not add an R
package or silently import package-specific critical-value conventions.

## Frozen Candidate Registry

The registry is deliberately small and mechanism-diverse. Symbols are in
coefficient-normalization order.

| Index | Triplet ID | Symbols | Category | Ex-ante rationale |
|---:|---|---|---|---|
| 1 | `T01_EWA_EWC_IGE` | EWA, EWC, IGE | literature anchor | Chan's country/commodity-sensitive triplet |
| 2 | `T02_GLD_GDX_USO` | GLD, GDX, USO | literature anchor | Chan's omitted-common-factor illustration |
| 3 | `T03_SPY_IVV_VOO` | SPY, IVV, VOO | duplicate claim | Three implementations of the S&P 500 claim |
| 4 | `T04_SHY_IEF_TLT` | SHY, IEF, TLT | Treasury curve | Short-, intermediate-, and long-duration Treasuries |
| 5 | `T05_XLE_XOP_USO` | XLE, XOP, USO | energy complex | Broad energy, producers, and oil-futures proxy |
| 6 | `T06_GLD_SLV_GDX` | GLD, SLV, GDX | precious-metals complex | Gold, silver, and gold-miner equities |
| 7 | `T07_QQQ_XLK_SMH` | QQQ, XLK, SMH | technology factor | Growth, broad technology, and semiconductors |
| 8 | `T08_XLF_JPM_BAC` | XLF, JPM, BAC | basket/components | Financial basket and two large bank components |

Registry order is the deterministic tie-break if multiple candidates pass all
TRAIN gates. No outcome ranking chooses the triplet.

## Frozen Estimation

- Provider: Alpaca adjusted daily OHLCV only.
- Explicit as-of: `2026-07-24 17:30:00`.
- TRAIN: `2016-01-04` through `2020-12-31`.
- DEVELOPMENT: `2021-01-01` through `2023-12-29`.
- CONFIRMATION: begins `2024-01-01` and remains sealed.
- Johansen form: price levels, one VAR lag, unrestricted constant removed by
  residualization.
- Bootstrap: 1,000 seeded covariance-matched random walks per rank null.
- Rank requirement: reject rank 0 at 5%, but do not reject rank at most 1 at
  5%.
- Vector: leading rank-one eigenvector, sign-oriented to a positive first
  coefficient and normalized so the first coefficient equals 1.
- Stability comparison: cosine similarity of dollar-exposure vectors estimated
  on the first and second TRAIN subwindows, evaluated at the full-TRAIN final
  prices.

The Johansen vector is estimated only on TRAIN. If nominated, it is frozen
without re-estimation for all DEVELOPMENT signals and trades.

## Frozen Trading Rule

For a frozen vector \(\widehat{\boldsymbol{\beta}}\):

1. compute \(s_t=\widehat{\boldsymbol{\beta}}^{\top}\mathbf{p}_t\);
2. compute a 20-session rolling mean and sample standard deviation of \(s_t\);
3. define \(z_t=(s_t-\overline{s}_{t,20})/\widehat{\sigma}_{t,20}\);
4. enter long portfolio when \(z_t<-1\);
5. enter short portfolio when \(z_t>+1\);
6. exit at the zero crossing;
7. signal after close and execute at next open;
8. convert the fixed share vector to daily dollar weights and gross-normalize:

\[
w_{i,t}(d)=
d\frac{\widehat{\beta}_iP_{i,t}}
{\sum_{j=1}^{3}|\widehat{\beta}_jP_{j,t}|},
\quad d\in\{-1,+1\};
\]

9. charge 5 bp per one-way weight change, with 10 bp as stress cost.

This is a daily swing strategy. No intraday, scalping, live shorting, or
quarterly allocation behavior is opened.

## TRAIN Gates

All eight are required:

1. **Integrity:** data, chronology, next-open timing, weight, cost, and
   partition checks pass.
2. **I(1) structure:** every component has level ADF-style \(t>-3.0\) and
   first-difference ADF-style \(t<-3.0\).
3. **Rank one:** bootstrap \(p<0.05\) for rank 0 and \(p\geq0.05\) for rank at
   most 1.
4. **Vector stability:** split-TRAIN dollar-exposure cosine similarity is at
   least 0.85.
5. **Plausible half-life:** the TRAIN spread half-life is between 2 and 60
   sessions.
6. **Two-sided support:** at least 30 completed trades, with at least 10 long
   and 10 short.
7. **Cost-aware return:** mean primary-cost net trade return is positive and
   its 95% moving-block-bootstrap lower bound exceeds zero.
8. **Forward convergence:** z-score versus next-five-session frozen-vector
   portfolio return is negative and its 95% bootstrap upper bound is below
   zero.

The ADF threshold, bootstrap design, stability threshold, trade thresholds,
costs, and conjunctive gate are Gen5 design choices. They are not represented
as Chan's published checklist.

## Leakage-Safe Sequence

1. Query only TRAIN bars for all eight triplets.
2. Estimate and evaluate each triplet entirely inside TRAIN.
3. If none passes all eight gates, stop; do not query DEVELOPMENT for strategy
   evaluation.
4. If one or more pass, select the first full pass in frozen registry order.
5. Freeze its full-TRAIN Johansen vector.
6. Query and replay only that identity through DEVELOPMENT.
7. Report DEVELOPMENT once, without selecting a replacement or modifying the
   vector, lookback, thresholds, costs, or exit.
8. Keep CONFIRMATION sealed regardless of the DEVELOPMENT result.

## Conditional DEVELOPMENT Readout

For the nominated triplet only, report:

- the frozen coefficients and gross-normalized dollar weights;
- completed trades and direction counts;
- primary- and stress-cost cumulative return;
- naive and autocorrelation-adjusted Sharpe;
- maximum drawdown;
- mean net trade return and hit rate;
- forward-five-session convergence correlation; and
- representative signal and trade tapes.

## Stop States

- No full TRAIN pass:
  `STOP_LIT_MR_03_1_NO_TRAIN_NOMINATION`.
- TRAIN nomination and OOS replay completed:
  `OOS_DEVELOPMENT_COMPLETE_LIT_MR_03_1`.

Neither state authorizes confirmation, portfolio allocation, live shorting,
provider expansion, or live behavior.
