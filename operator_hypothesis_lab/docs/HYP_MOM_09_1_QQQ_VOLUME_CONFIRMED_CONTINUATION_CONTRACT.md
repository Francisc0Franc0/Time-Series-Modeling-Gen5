# HYP-MOM-09.1 QQQ Volume-Confirmed Continuation Contract

Status: `STOP_HYP_MOM_09_1_NO_SEARCH_ADJUSTED_TRAIN_INTERACTION`

Date frozen: `2026-08-22`

Outcome recorded: `2026-08-22`

The contract below was frozen before return outcomes were read. The completed
TRAIN run found a maximum partial interaction correlation of `0.120512`, below
the complete circular-shift maximum-statistic p90 of `0.137202` (empirical
upper-tail probability `0.167051`). No cell was nominated; DEVELOPMENT was not
queried or calculated, and confirmation remains sealed.

## Identity and boundary

`HYP-MOM-09.1` formalizes planning label `QQQ-S5` from the approved
[QQQ minimal-hypothesis slate](../../literature_studies/docs/GEN5_QQQ_MINIMAL_HYPOTHESIS_SLATE.md).

This is a new predictor-only concept. It does not rescue the stopped QQQ
equal-weight leadership, semiconductor lead-lag, QQQ-versus-SPY persistence,
Chan, path-quality, same-slot, or M1 tests. It asks whether participation
changes the forecast content of a QQQ move after the raw move, participation
level, and move magnitude are already controlled.

No strategy, trade rule, thresholded position, P&L, Sharpe, drawdown,
allocation, leverage, confirmation read, or live behavior is authorized.

## Narrative hypothesis

A QQQ move accompanied by unusually high trading participation contains more
persistent information than the same signed move on ordinary volume because
high-participation price discovery reflects broader conviction and slower
position adjustment.

The hypothesis is specifically about a positive interaction:

> holding the signed return, positive volume surprise, and absolute move size
> fixed, the return-by-participation interaction should positively forecast
> the next-open-to-later-open QQQ return.

Raw QQQ continuation or a volume-only effect cannot substitute for the
registered interaction.

## Source and evidence partitions

- Provider: Gen5 Alpaca cache through the canonical adjusted-daily workbench.
- Instrument: `QQQ` only.
- Bars: adjusted daily OHLCV.
- Feed: repository data-layer configuration, recorded in the run manifest.
- Explicit as-of timestamp: `2026-08-22 17:30:00 America/New_York`.
- Query warm-up start: `2016-01-04`.
- TRAIN anchors and targets: `2017-01-03` through `2020-12-31`.
- Conditional DEVELOPMENT anchors and targets: `2021-01-04` through
  `2023-12-29`.
- Sealed confirmation: `2024-01-02` through `2025-12-31`.
- No 2026 bar may enter any predictor, target, fit, diagnostic, plot, or
  decision.

The runner must query only through the TRAIN boundary first. DEVELOPMENT may
be queried only after the frozen TRAIN gate passes. Confirmation remains
unread even if DEVELOPMENT passes.

## Causal participation construction

For each session `i`:

1. Define adjusted dollar volume
   `DV[i] = adjusted_close[i] * adjusted_volume[i]`.
2. Define the reference level as the median of the strictly prior 60 sessions:
   `M60[i] = median(DV[i-60], ..., DV[i-1])`.
3. Define positive volume surprise:
   `P[i] = min(max(log(DV[i] / M60[i]), 0), log(5))`.

The current session is excluded from its own reference. Negative log ratios
are set to zero because the narrative concerns unusually high participation,
not a symmetric high-versus-low volume slope. The `5x` cap is a frozen
robustness bound, not a selected threshold.

For each trailing return lookback `L` in `{1, 5, 20}`:

- `R_L[t] = log(close[t] / close[t-L])`;
- `V_L[t] = mean(P[t-L+1], ..., P[t])`;
- `A_L[t] = abs(R_L[t])`;
- `I_L[t] = R_L[t] * V_L[t]`.

All components are known after session `t` closes. The common feature warm-up
is 80 sessions: 60 strictly prior sessions plus the longest 20-session move.

Dollar volume is used instead of share volume to reduce split-unit ambiguity.
This does not claim ETF volume measures unique end-investor conviction; it is
an operational participation proxy whose incremental predictive content must
survive the registered controls.

## Forward target and timing

For each horizon `H` in `{1, 5, 20}`:

`Y_H[t] = log(open[t+1+H] / open[t+1])`.

The signal is complete after close `t`. The target begins at the next
session's open and ends `H` open-to-open sessions later, so predictor and
target do not overlap.

All nine `(L, H)` cells use the same anchor rows admitted by the maximum
80-session feature warm-up and maximum 20-session target.

## Registered estimand

For each cell, fit the additive control space:

`Y = alpha + b_R R_L + b_V V_L + b_A A_L + error`.

Residualize both `I_L` and `Y_H` on the same additive control space. The
primary TRAIN statistic is their Pearson correlation, the partial correlation
of the interaction with the target after drift, signed return, positive volume
surprise, and absolute move magnitude.

The corresponding full-model interaction coefficient and partial Spearman
correlation are reported as diagnostics. The economic sign is positive.

## TRAIN multiplicity control and nomination

The complete `3 x 3` surface is one search family.

1. Jointly circularly shift all three target-horizon columns relative to the
   feature rows.
2. Admit every shift whose minimum circular displacement is at least 60 rows.
3. Recalculate the nine partial correlations for each shift.
4. Record the maximum partial correlation from each shifted surface.
5. Compute the type-7 90th percentile of that complete maximum-statistic null.

TRAIN passes only if the observed maximum partial correlation is positive and
strictly greater than the shift-maximum p90 threshold.

If TRAIN passes, nominate exactly one cell: the largest observed partial
correlation, breaking exact ties by shorter lookback and then shorter horizon.
If TRAIN fails, nominate nothing and do not query or calculate DEVELOPMENT.

## Frozen model comparison after a TRAIN pass

At the single nominated cell, fit these models on all TRAIN rows:

- `DRIFT`: intercept only;
- `RETURN`: intercept plus `R_L`;
- `VOLUME`: intercept plus `V_L`;
- `ADDITIVE`: intercept plus `R_L`, `V_L`, and `A_L`;
- `INTERACTION`: `ADDITIVE` plus `I_L`.

The fitted TRAIN coefficients are frozen before DEVELOPMENT predictions are
made. Model-loss comparisons use the identical DEVELOPMENT rows.

## DEVELOPMENT gates

DEVELOPMENT passes only if all of the following hold:

1. At least 600 common DEVELOPMENT anchors exist.
2. The DEVELOPMENT partial correlation of `I_L` with `Y_H` after the additive
   controls is positive.
3. A 10,000-replicate stationary bootstrap with expected block length 20 and
   seed `905101` assigns at least 90% probability to a positive DEVELOPMENT
   full-model interaction coefficient.
4. Frozen `INTERACTION` MSE is strictly lower than frozen `ADDITIVE`, `RETURN`,
   `VOLUME`, and `DRIFT` MSE.
5. The stationary-bootstrap probability that `ADDITIVE MSE - INTERACTION MSE`
   is positive is at least 90%.
6. The full-model interaction coefficient is positive in at least two of the
   three calendar years 2021, 2022, and 2023.

MAE, partial Spearman correlation, year estimates, and participation-quintile
diagnostics are reported but cannot rescue a failed hard gate.

A DEVELOPMENT pass ends in
`DEVELOPMENT_PASS_HYP_MOM_09_1_CONFIRMATION_REVIEW_REQUIRED`. It does not
authorize confirmation access.

## Source and construction gates

Before TRAIN statistics are read, the runner must verify:

- exact `QQQ` identity and one row per session;
- strict date order;
- adjusted `1D` bars only;
- positive finite OHLCV and adjusted dollar volume;
- query-start and requested-end coverage;
- maximum observed date no later than the requested evidence boundary;
- zero split-like reciprocal price/volume discontinuities under frozen
  thresholds `close ratio < 0.55 or > 1.80` and reciprocal-log tolerance
  `0.25`;
- finite causal participation features;
- positive variation in `V_L` for every lookback;
- no more than 1% of eligible daily participation observations capped at
  `log(5)`.

A deliberately historical query may carry a generic stale-cache WARN when its
requested range is fully covered. The packet must state whether any WARN
affects the requested evidence window.

## STOP discipline

Under this identifier, do not:

- replace dollar volume with share volume, turnover, VWAP, trade count,
  options volume, or constituent volume after seeing results;
- change the 60-session reference, positive-part transform, `5x` cap, return
  grid, horizon grid, or shift displacement;
- threshold only positive returns, large moves, or extreme volume days;
- drop the absolute-return control;
- promote raw return or volume-alone evidence as interaction evidence;
- invert a negative interaction;
- search nearby years, assets, or volume definitions;
- consume confirmation after a STOP;
- reinterpret predictor evidence as a trading strategy.

Any such question requires a new narrative, identifier, contract, and fresh
evidence boundary.

## Required artifacts

- frozen contract table and run specification;
- source, coverage, split-adjustment, and participation-construction audits;
- TRAIN partial-correlation surface;
- complete circular-shift maximum distribution and TRAIN decision;
- frozen nominee or explicit no-nominee artifact;
- conditional DEVELOPMENT model, coefficient, loss, year, and participation
  diagnostics;
- readable report and one or two decisive figures;
- explicit DEVELOPMENT and confirmation boundary files;
- progress-log, nomenclature, QQQ-slate, and evidence-deck updates.
