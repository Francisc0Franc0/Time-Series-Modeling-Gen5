# HYP-MOM-10.1 QQQ-Adjacent ETF Cross-Sectional Momentum Results

Status: `STOP_HYP_MOM_10_1_NO_SEARCH_ADJUSTED_TRAIN_RANKING`

Run date: `2026-08-22`

## Bottom line

The registered continuation hypothesis failed before DEVELOPMENT. Every cell
in the frozen `L={5,20,60}` by `H={1,5,20}` surface had the wrong sign: recent
relative leaders subsequently underperformed relative laggards on average.
This is a STOP for the continuation proposition, not evidence sufficient to
adopt a reversal rule.

## Registered test

The frozen basket contained 12 QQQ-adjacent ETFs across broad growth, broad
technology, semiconductors, and biotech innovation. For every date and
horizon, the basket common return was subtracted from both predictor and
target. The primary statistic was mean within-date Spearman rank IC; the
supporting ordering was the forward return of the top three ranks minus the
bottom three ranks.

The TRAIN family contained nine cells. A complete circular shift of target
date rows preserved cross-ETF and cross-horizon dependence and produced a
family-wise maximum-statistic null. The result also had to remain positive
after omitting each declared sleeve.

## Source and integrity

- 12/12 registered ETFs covered the requested historical TRAIN range.
- 6/6 source gates and 7/7 analytical integrity gates passed.
- All funds shared 1,259 source sessions through `2020-12-31`.
- The common surface used 986 anchor dates and 11,832 asset-date rows per cell.
- The data-health WARN is bounded: the explicit historical query is stale
  relative to the 2026 as-of session, but every registered TRAIN range is
  completely covered.
- DEVELOPMENT and confirmation markers verify that neither later zone was
  queried or calculated.

## TRAIN evidence

The least-negative observed cell was `L5_H1`:

- mean daily rank IC: `-0.009265`;
- pooled Pearson relation: `-0.041743`;
- mean top-three-minus-bottom-three relative return: `-0.000267`;
- positive daily IC fraction: `0.488844`;
- positive top-minus-bottom fraction: `0.490872`; and
- worst leave-one-sleeve-out mean IC: `-0.016719`.

The complete time-shift control contained 867 admissible shifts. Its p90
maximum rank IC was `0.096601`, while the observed maximum was `-0.009265`;
the empirical upper-tail probability was `1.000000`.

The 1,000-replicate randomized-rank diagnostic placed the observed
top-minus-bottom ordering below its p90 of `0.000212`; empirical upper-tail
probability was `0.944056`.

The wrong sign strengthened at longer forward horizons. The most negative
cell, `L20_H20`, had mean daily rank IC `-0.124600` and top-minus-bottom
ordering `-0.008594`.

## Overlap and interpretation

Mean pairwise daily-return correlation was `0.866`. Broad growth and broad
technology pairs often correlated around `0.97-1.00`; even the three
semiconductor ETFs were highly redundant. The basket therefore supplied much
less than 12 independent sources of relative information.

That overlap is an important limitation, but it does not rescue the registered
continuation proposition. Common return was already removed, all nine cells
were negative, three of four leave-one-sleeve-out checks were negative, and
the observed ordering was weaker than random rank assignment.

The result is consistent with either short-horizon relative mean reversion or
no stable effect under strong overlap. Distinguishing those explanations would
require a separately motivated reversal contract with fresh evidence; simply
inverting this stopped surface would be outcome-driven.

## Evidence boundary

No cell was nominated. The 2021-2023 DEVELOPMENT interval was not queried or
calculated. The 2024-2025 confirmation interval remains sealed. No strategy,
portfolio, cost, turnover, P&L, Sharpe, drawdown, allocation, leverage, advice,
or live behavior was computed.

## Artifacts

- Run packet: `runs/research_workbench/operator_hypothesis_lab/hyp_mom_10_1_qqq_adjacent_etf_cross_sectional_momentum_20260822`
- Primary report: `hm101_report.md`
- Full surface: `hm101_train_surface.csv`
- Family-wise control: `hm101_train_shift_maxima.csv`
- Randomized-rank control: `hm101_train_randomized_rank.csv`
- Sleeve diagnostic: `hm101_train_leave_one_sleeve_out.csv`
- Overlap diagnostic: `hm101_train_overlap.csv`
- Decisive figures: `visuals/hm101_train_surface.png`,
  `visuals/hm101_train_search_control.png`,
  `visuals/hm101_train_randomized_rank.png`,
  `visuals/hm101_train_overlap.png`, and
  `visuals/hm101_train_ranking_tapes.png`
