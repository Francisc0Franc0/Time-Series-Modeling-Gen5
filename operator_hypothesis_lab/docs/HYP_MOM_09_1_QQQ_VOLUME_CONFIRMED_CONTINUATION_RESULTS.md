# HYP-MOM-09.1 QQQ Volume-Confirmed Continuation Results

Status: `STOP_HYP_MOM_09_1_NO_SEARCH_ADJUSTED_TRAIN_INTERACTION`

Date completed: `2026-08-22`

## Decision

Stop this predictor hypothesis at TRAIN. Unusually high QQQ dollar-volume
participation did not add search-adjusted continuation information beyond
drift, signed return, participation level, and absolute move size. Nominate no
lookback/horizon cell, leave 2021-2023 DEVELOPMENT unread, and keep 2024-2025
confirmation sealed.

This is a clean null for the frozen participation interaction. It is not a
claim that volume is economically meaningless, and it is not permission to
mine a different volume definition, threshold, direction, asset, or period.

## What was tested

The frozen contract used adjusted daily QQQ OHLCV. For each date, adjusted
dollar volume was compared with the median of the strictly prior 60 sessions.
Only positive log surprise was retained and capped at `log(5)`. Trailing QQQ
return, mean participation surprise, absolute trailing return, and their
signed return-by-participation interaction were constructed for lookbacks
`1`, `5`, and `20` sessions. Forward targets were next-open-to-later-open QQQ
log returns over `1`, `5`, and `20` sessions.

For every cell, the registered statistic was the partial Pearson correlation
between the interaction and forward return after removing intercept, signed
return, participation, and absolute-return effects. A complete joint circular
shift test preserved the nine-cell search and compared the observed maximum
with the 90th percentile of the maximum-statistic null.

## Source and construction audit

- As-of timestamp: `2026-08-22 17:30:00 America/New_York`.
- Requested TRAIN query: `2016-01-04` through `2020-12-31`.
- Coverage: `1,259` unique adjusted daily QQQ sessions; no duplicates.
- Common TRAIN anchors: `986`.
- Return-blind source gates: `8 / 8` passed.
- Split-like reciprocal price/volume discontinuities: `0`.
- Eligible causal participation sessions: `1,199`.
- Positive-surprise fraction: `51.21%`.
- Cap-hit fraction: `0.334%`, below the frozen `1%` limit.

The workbench emitted a generic stale-symbol WARN because this deliberately
historical query ended before the 2026 as-of session. The requested range was
fully cached through `2020-12-31`, so the WARN did not affect the evidence
window and no refresh was needed.

## TRAIN evidence

The strongest positive cell was `L1_H20`:

- partial interaction correlation: `0.120512`;
- full-model interaction coefficient: `0.876193`;
- partial Spearman correlation: `0.073496`;
- additive in-sample MSE: `0.00290242`;
- interaction in-sample MSE: `0.00286027`.

Those in-sample diagnostics were not enough. Across all `867` admissible joint
shifts, the maximum-statistic p90 was `0.137202`; the observed maximum had an
empirical upper-tail probability of `0.167051`. The frozen TRAIN gate required
the observed maximum to be positive and strictly greater than p90. It failed.

The surface also lacked a stable common sign: the `L20_H20` interaction was
materially negative (`-0.1419999` partial correlation), while the apparent
positive peak sat at the shortest return lookback and longest target. That
shape is descriptive only; no reverse or conditional follow-up is opened by
this result.

## Evidence boundary

- No TRAIN nominee was created.
- DEVELOPMENT `2021-2023` was not queried or calculated.
- Confirmation `2024-2025` was not queried or calculated.
- No strategy, threshold, trade, P&L, Sharpe, drawdown, allocation, leverage,
  or live behavior was computed.

## Interpretation

The intuitive story was reasonable: unusually active trading might mark a
move supported by broader price discovery. But in this daily QQQ construction,
the best apparent interaction was not unusual once the full lookback/horizon
search was reproduced under time-misaligned controls. Put plainly, chance
could generate a nine-cell surface with a peak at least this large often
enough that the contract would not spend later evidence on it.

The useful update is narrower than “volume does not work.” Daily ETF dollar
volume, transformed as a causal positive surprise and entered as a linear
interaction with recent return, did not earn incremental forecast authority.
The result therefore directs the slate toward genuinely distinct mechanisms,
not nearby repairs. QQQ breadth remains conceptually different but requires
point-in-time membership authority; the frozen cross-sectional ETF question
also remains separate and is scheduled last because of its overlap with M1.

## Artifacts

- [frozen contract](HYP_MOM_09_1_QQQ_VOLUME_CONFIRMED_CONTINUATION_CONTRACT.md)
- [evidence packet](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_09_1_qqq_volume_confirmed_continuation_20260822)
- [run report](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_09_1_qqq_volume_confirmed_continuation_20260822/hm091_report.md)
- [TRAIN surface figure](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_09_1_qqq_volume_confirmed_continuation_20260822/visuals/hm091_train_surface.png)
- [search-control figure](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_09_1_qqq_volume_confirmed_continuation_20260822/visuals/hm091_train_search_control.png)
- [participation event panels](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_09_1_qqq_volume_confirmed_continuation_20260822/visuals/hm091_train_participation_events.png)

## Reproduction

Run:

```powershell
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' scripts/inspect/run_hyp_mom_09_1_qqq_volume_confirmed_continuation.R
```
