# HYP-MOM-04.3A Target Structure Audit Contract

Status: `FROZEN_EXECUTED`

## Research question

Did `HYP-MOM-04.2` fail mainly because its next-quarter target mixed
stock-specific selection with sector leadership and prior-beta exposure, and
how do economically clearer target definitions change the feature evidence?

This is a diagnostic derivative of `HYP-MOM-04.2`. It is not a feature search,
model comparison, trading backtest, or authorization to open OOS.

## Evidence boundary

- Source: the retained, integrity-passing `HYP-MOM-04.2` TRAIN feature panel.
- Universe: 481 coverage-eligible identities from the September 2020 SPY
  deployment cohort.
- Signal quarters: `2017Q1` through `2020Q3`.
- Outcome dates: next-quarter open-to-open returns ending no later than
  `2020-12-31`.
- OOS: no observation dated `2021-01-01` or later may be read or queried.
- No provider call is permitted. The audit must operate from retained TRAIN
  evidence only.

The effective temporal sample remains 15 market quarters. Stock-quarter rows
within one quarter are not independent temporal replications.

## Terminology correction

The implemented `HYP-MOM-04.2` reference target was next-quarter stock return
minus the eligible-universe mean return, not literally stock return minus SPY.
Subtracting SPY would preserve the same cross-sectional rank because it removes
one common quarter-level constant, but it would change the numerical excess-
return level. This audit names the implemented target `UNIVERSE_RELATIVE`.

## Frozen target definitions

For stock `i`, sector `s`, and signal quarter `t`, let `R(i,t+1)` be the next-
quarter open-to-open return and `beta(i,t)` the causal 126-session beta known at
the signal date.

1. `UNIVERSE_RELATIVE`

   `R(i,t+1) - mean_i(R(i,t+1))`

   Question: which stocks beat the eligible deployment universe next quarter?

2. `SECTOR_RELATIVE`

   `R(i,t+1) - mean_{i in s}(R(i,t+1))`

   Question: which stocks beat their same-sector peers next quarter?

3. `SECTOR_BETA_RESIDUAL`

   The OLS residual from the quarter-specific cross-sectional regression

   `R(i,t+1) = sector_fixed_effect(s) + gamma(t) * beta(i,t) + error(i,t)`.

   Question: which stocks did better than their sector and prior beta would
   imply? This is a diagnostic challenger, not the default trading objective.

All target construction uses only the already-retained next-quarter TRAIN
outcome. No feature, model coefficient, or target definition may be changed in
response to the audit results.

## Frozen diagnostics

The audit must produce:

1. target scale by quarter: standard deviation, interquartile range, median
   absolute deviation, 90th-minus-10th percentile, and positive fraction;
2. outlier influence: top-1%-absolute-return mass share and winsorized-to-raw
   dispersion ratio;
3. pairwise target agreement by quarter: Spearman rank correlation, top-
   quartile Jaccard overlap, and sign agreement;
4. raw-return decomposition by quarter: sector-only, beta-only, and sector-plus-
   beta cross-sectional R-squared;
5. realized top-quartile sector concentration under each target: maximum sector
   share and Herfindahl index;
6. simple causal baseline relationships for high beta, low volatility, prior
   momentum, prior sector leadership, and within-sector momentum;
7. quarter-by-quarter Spearman IC for all 33 frozen `HYP-MOM-04.2` features
   against each target; and
8. human-facing plots that show both pooled shape and temporal variation.

The audit may summarize which target most cleanly answers a stock-selection
question. It may not select a feature basket, fit Ridge, run permutations,
construct a portfolio, calculate trading performance, or nominate a target for
OOS.

## Integrity gates

All must pass before interpretation:

1. retained H04.2 status is `STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN`;
2. retained H04.2 integrity checks all passed;
3. exactly 15 ordered signal quarters are present;
4. at least 400 identities and at least 20 rows per quarter are present;
5. every target and required causal input is finite;
6. every sector-quarter contains at least three identities;
7. each target is centered within its intended comparison group;
8. signal date precedes entry date and entry date precedes exit date; and
9. no signal, entry, exit, or source observation reaches `2021-01-01`.

## Stop state

Passing the integrity gates records
`TARGET_AUDIT_COMPLETE_SELECTION_NOT_FROZEN`. It means the target comparison is
usable for discussion only. Choosing a target and reopening model research
requires a separate operator decision and a new frozen contract.

Failure of an integrity gate records `STOP_TARGET_AUDIT_INTEGRITY_FAILED` and
blocks interpretation.
