# HYP-MOM-10.1 QQQ-Adjacent ETF Cross-Sectional Momentum Contract

Status: `STOP_HYP_MOM_10_1_NO_SEARCH_ADJUSTED_TRAIN_RANKING`

Date frozen: `2026-08-22`, after a return-blind cache/schema/calendar inventory
and before any HYP-MOM-10.1 return, rank, target, correlation, or ordering
statistic was calculated.

## Identity and research boundary

`HYP-MOM-10.1` formalizes `QQQ-S6` from the approved
[QQQ minimal-hypothesis slate](../../literature_studies/docs/GEN5_QQQ_MINIMAL_HYPOTHESIS_SLATE.md).

This is a fresh, predictor-only cross-sectional question. It is not a rescue
of stopped M1: M1 used a 24-ETF global equity atlas, a monthly 12-minus-1 rank,
and next-month outcomes. This contract uses a frozen QQQ-adjacent basket,
short/intermediate daily horizons, and same-date basket-relative predictors
and targets. M1 remains unchanged and is used only as an interpretive control
after this result is frozen.

No portfolio, trade rule, costs, turnover, P&L, Sharpe, drawdown, allocation,
leverage, confirmation read, advice, or live behavior is authorized.

## Narrative hypothesis

> Within a frozen basket of growth and technology ETFs, recent relative
> leaders continue to outperform recent relative laggards over a short forward
> horizon because style and subsector reallocations diffuse gradually.

The falsifying null is that trailing within-basket relative rank has no
positive search-adjusted relation with forward within-basket relative return,
or that any apparent ordering is carried by one declared sleeve or common
market direction.

## Frozen basket and grouping

The basket was chosen before outcomes from broad, liquid, cached ETFs that
represent four predeclared QQQ-adjacent sleeves:

| Sleeve | ETFs | Rationale |
|---|---|---|
| Broad growth | `QQQ`, `VUG`, `IWF`, `IUSG` | Large-cap and broad US growth exposure |
| Broad technology | `XLK`, `VGT`, `IYW` | Diversified technology-sector exposure |
| Semiconductors | `SMH`, `SOXX`, `XSD` | Concentrated technology-industry leadership |
| Biotech innovation | `IBB`, `XBI` | Growth-sensitive innovation outside conventional information technology |

The overlapping funds are intentional. Fund count is not treated as
independent evidence. Realized return correlation, sleeve diagnostics, and
leave-one-sleeve-out rank evidence must be reported.

## Source and evidence zones

- Provider: canonical Gen5 Alpaca adjusted-daily cache.
- Bars: adjusted `1D` OHLCV.
- Explicit as-of: `2026-08-22 17:30:00 America/New_York`.
- Query warm-up start: `2016-01-04`.
- TRAIN anchors and target exits: `2017-01-03` through `2020-12-31`.
- Conditional DEVELOPMENT anchors and target exits: `2021-01-04` through
  `2023-12-29`.
- Sealed confirmation: `2024-01-02` through `2025-12-31`.
- No 2026 observation may enter a predictor, target, diagnostic, plot, or
  decision.

The runner queries only through TRAIN first. DEVELOPMENT may be queried only
after all frozen TRAIN gates pass. Confirmation remains unread in this slice.

## Frozen measurements

Freeze lookbacks `L in {5, 20, 60}` and forward horizons
`H in {1, 5, 20}`. All nine cells use the common anchors eligible for
`L=60` and `H=20`.

For ETF `j` after close `t`:

`R[j,t,L] = log(C[j,t] / C[j,t-L])`

`X[j,t,L] = R[j,t,L] - mean_j(R[j,t,L])`.

The attainable forward return begins at the next open:

`F[j,t,H] = log(O[j,t+1+H] / O[j,t+1])`

`Y[j,t,H] = F[j,t,H] - mean_j(F[j,t,H])`.

The primary cell statistic is the mean across dates of the within-date
Spearman correlation between `X` and `Y`. Supporting measurements are pooled
Pearson correlation, mean top-three-minus-bottom-three relative forward
return, and leave-one-sleeve-out mean rank IC. Arithmetic uses log returns.

Subtracting the same-date basket mean from both sides is the registered
common-return control; raw trailing return is retained as a nested comparison
if DEVELOPMENT opens.

## TRAIN search control and gates

Jointly circularly shift the complete forward-target date rows, preserving the
cross-ETF and cross-horizon structure. Admit every shift whose shortest
circular displacement is at least 60 common dates. For each shift, retain the
maximum mean daily rank IC across all nine cells. The frozen family-wise
threshold is the type-7 90th percentile of that complete maximum distribution.

TRAIN passes only if all conditions hold:

1. at least 900 common TRAIN anchor dates and all 12 ETFs are present;
2. all integrity and timing checks pass;
3. the largest observed mean daily rank IC is strictly positive and strictly
   exceeds the shift-maximum p90;
4. that same cell has positive mean top-three-minus-bottom-three ordering; and
5. its mean rank IC remains positive after removing each declared sleeve in
   turn.

Failure records
`STOP_HYP_MOM_10_1_NO_SEARCH_ADJUSTED_TRAIN_RANKING`, nominates no cell, and
leaves DEVELOPMENT and confirmation unread. Passage nominates the largest
mean rank IC, breaking exact ties toward shorter `H`, then shorter `L`.

A deterministic 1,000-replicate within-date randomized-rank control with seed
`1006101` is reported for the best observed cell. It is a specificity
diagnostic, not a substitute for the family-wise time-shift gate.

## Conditional DEVELOPMENT test

For the single TRAIN nominee, fit on TRAIN and freeze:

- `DRIFT`: intercept only on basket-relative forward return;
- `RAW_RETURN`: intercept plus raw trailing ETF return; and
- `RELATIVE_SCORE`: intercept plus basket-relative trailing return.

Apply coefficients unchanged to identical DEVELOPMENT rows. DEVELOPMENT
passes only if all of these hold:

1. at least 600 common DEVELOPMENT dates;
2. mean daily rank IC is positive;
3. a 10,000-replicate date-block stationary bootstrap with expected block
   length 20 and seed `1010101` gives at least 90% probability of positive
   mean rank IC;
4. mean top-three-minus-bottom-three ordering is positive;
5. frozen `RELATIVE_SCORE` MSE is below both `DRIFT` and `RAW_RETURN`; and
6. leave-one-sleeve-out mean rank IC is positive for every omitted sleeve.

Failure records `STOP_HYP_MOM_10_1_DEVELOPMENT_RANKING_GATES_FAILED`.
Passage records
`DEVELOPMENT_PASS_HYP_MOM_10_1_CONFIRMATION_REVIEW_REQUIRED`; it does not open
confirmation automatically.

## Diagnostics and STOP discipline

Required outputs include source/coverage/integrity audits, the full TRAIN
surface, shift distribution, randomized-rank diagnostic, sleeve and overlap
diagnostics, representative ranking tapes, an explicit nominee or no-nominee
file, and sealed-evidence markers.

Do not change the basket, sleeves, return definitions, grids, top/bottom count,
evidence dates, direction, or controls after reading outcomes. Do not drop a
fund or sleeve because it weakens the result, invert a wrong sign, search a
nearby subset, or interpret predictor ordering as portfolio performance. Any
new question requires a new identifier and frozen contract.

## Final readout

Execution stopped at TRAIN. Across 986 common anchor dates and 11,832
asset-date rows per cell, all nine registered mean daily rank ICs were
negative. The least-negative `L5_H1` cell had mean rank IC `-0.009265` and
top-three-minus-bottom-three ordering `-0.000267`, versus the complete
867-shift maximum-statistic p90 of `0.096601`; empirical upper-tail probability
was `1.000000`. Three of four leave-one-sleeve-out ICs were negative, and the
same-cell randomized-rank upper-tail probability was `0.944056`.

No cell was nominated. DEVELOPMENT was not queried or calculated, and
2024-2025 confirmation remains sealed. See the
[results](HYP_MOM_10_1_QQQ_ADJACENT_ETF_CROSS_SECTIONAL_MOMENTUM_RESULTS.md).
