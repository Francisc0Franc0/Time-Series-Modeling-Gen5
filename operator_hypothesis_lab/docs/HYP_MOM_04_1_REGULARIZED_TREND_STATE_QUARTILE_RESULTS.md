# HYP-MOM-04.1 Regularized Trend-State Quartile Results

Status: `STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN`

## Question and scope

This lane tested whether six interpretable, completed-close trend-state
features could rank stocks by next-quarter relative return. A time-ordered
ridge model was the primary hypothesis; a fixed-sign equal-weight composite
was a diagnostic comparator. The frozen 122-name registry, target, feature
definitions, lambda grid, gates, and OOS lock were recorded before TRAIN
outcomes were computed.

The refreshed Alpaca packet covered 2016-01-04 through 2020-12-31 only. Eight
later-history identities could not cover the bounded range and were excluded
without replacement. The final TRAIN panel contained 114 coverage-eligible
identities, 1,693 asset-quarter observations, 15 signal quarters, and 111 to
114 assets per quarter. All 15 integrity checks passed. The refresh preserved
the cached outcome exactly; the partial-history warnings reflect unavailable
pre-listing history, while the stale-symbol warnings are expected for an
intentionally 2020-bounded query.

## What the model learned in pooled TRAIN

The one-standard-error rule selected the strongest regularization level,
`lambda = 100`. Final pooled coefficients favored 12-1 momentum and a rising
slow trend, penalized elevated short-run volatility and 252-session-high
proximity, and assigned small weights to the remaining features.

The final pooled fit looked unusually encouraging:

- top-quartile mean excess return: `+2.98` percentage points per quarter;
- mean quartile-4 minus quartile-1 spread: `+3.64` points;
- positive top-quartile excess in `11 / 15` quarters;
- quarter-bootstrap interval for mean top-quartile excess: `+0.56` to `+5.53`
  points; and
- full-procedure within-quarter permutation percentile: `98.8%`.

These figures are descriptive TRAIN fit, not forward evidence. The permutation
control says the pooled feature/target association is difficult to reproduce
after destroying the within-quarter mapping. It does not prove that the
relationship is stable through time.

## The time-ordered result failed

All five ridge penalties had negative mean expanding-validation IC. The
selected `lambda = 100` model produced:

- mean validation Spearman IC: `-0.0176`;
- positive validation-quarter IC: `5 / 9` (`55.6%`); and
- large sign changes, from `-0.264` in 2018Q3 to `+0.245` in 2019Q2 and back
  to `-0.208` in 2020Q3.

Gate G3 required both positive mean validation IC and at least 60% positive
validation quarters. It failed both conditions. The other six gates passed,
including integrity, sample size, pooled quartile separation, permutation rank,
and sector concentration.

This is the central result: **the model could explain the pooled TRAIN panel
but could not consistently rank the next chronological quarters using only
earlier TRAIN data**. The attractive full-sample quartile chart is therefore
exactly the result that must not be promoted.

## Feature-level interpretation

The univariate diagnostics support a simpler economic story but not a model
nomination:

| Feature | Mean quarterly rank IC | Positive quarters | Mean Q4 excess |
|---|---:|---:|---:|
| 12-1 momentum | +0.047 | 66.7% | +0.94 pp |
| Slow SMA200 slope / ATR20 | +0.044 | 53.3% | +1.04 pp |
| 252-session high proximity | +0.005 | 60.0% | -0.37 pp |
| Sector-relative 126-session momentum | -0.016 | 53.3% | +1.16 pp |
| 20-session extension | -0.041 | 46.7% | -0.19 pp |
| RV20 / RV126 | -0.064 | 40.0% | -1.04 pp |

The predeclared fixed-sign composite averaged `+0.0413` rank IC, was positive
in `9 / 15` quarters, and produced `+1.74` points of mean Q4 excess. Because it
was a comparator rather than the primary nomination policy, and because these
are pooled TRAIN diagnostics rather than an expanding replay, this does not
authorize an OOS run. It is a legitimate future question only if separately
frozen before accessing later data.

## Decision

Record `STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN`.

- The nomination file is explicitly false.
- No 2021-2023 bar was queried by this lane.
- No OOS return, Sharpe, drawdown, trade tape, or asset selection exists.
- No feature, sign, lambda, gate, quartile, or window may be changed under
  `HYP-MOM-04.1` after seeing this result.
- Any theory-composite study, rolling re-estimation concept, or reduced feature
  set requires a new identifier, a new pre-outcome contract, and an operator
  decision about evidence boundaries.

Generated evidence lives under
`runs/research_workbench/operator_hypothesis_lab/hyp_mom_04_1_train_20260810/`.
The run spec, integrity table, coverage, panel, CV ledger, quartile summaries,
permutation ledger, gate matrix, and visuals are retained there as ignored
research artifacts.
