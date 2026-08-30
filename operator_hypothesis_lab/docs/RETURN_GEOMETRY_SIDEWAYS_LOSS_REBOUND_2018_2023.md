# Sideways Loss Rebound Matched-Control Baseline (2018-2023 TRAIN)

## Purpose

The daily continuation line was stopped after sign attribution showed that its
20-session ER20-sideways result came from negative rather than positive prior
returns. This document opens that observation under a separate mean-reversion
identity:

> After a negative completed 20-session return, does an inefficient sideways
> path identify a better rebound environment than negative return alone?

This is distinct from the earlier `PROTO-MR-01` persistent-selloff rebound. The
earlier rule required signed ER20 `<= -0.30` and a bottom-quintile negative R20.
The present branch requires negative R20 with unsigned ER20 `< 0.30`: a net loss
reached through choppy, inefficient movement rather than an orderly decline.

## Frozen Matched-Control Slice

- Evidence: adjusted daily bars from 2018 through 2023 TRAIN.
- Universe: all 129 frozen atlas instruments remain visible.
- Primary aggregation: 88 full-history stocks, asset first, sector second, and
  equal-sector median across 11 GICS sectors.
- Signal information: completed close `t` only.
- Primary: `R20 < 0` and causal `ER20 < 0.30`.
- Controls:
  - `R20 < 0` regardless of ER20 state;
  - `R20 < 0` and `ER20 >= 0.30`;
  - `ER20 < 0.30` regardless of prior-return sign; and
  - unconditional same-asset 20-session open-to-open drift.
- Execution: enter open `t+1`, exit after 20 held sessions, ignore intervening
  signals within each rule, and subtract 10 bp round trip.
- Post-2023 outcomes remain sealed.

The 20-session horizon and ER20 cutoff are inherited, data-informed TRAIN
descriptors. They were not re-optimized in this slice.

## Results

All 20 construction checks passed.

The sideways-loss branch retained the earlier modest excess over drift:

- equal-sector excess: `+5.75 bp/trade`;
- core event-pooled excess: `+3.73 bp/trade`;
- positive-excess sector medians: `7/11`; and
- core trades: `4,138`.

The missing matched control changes the interpretation. Negative R20 without an
ER20 gate produced `+7.95 bp/trade` equal-sector excess and approximately
`+0.11 bp/trade` core event-pooled excess. Sideways-loss therefore:

- trails negative-only by `5.59 bp/trade` under equal-sector weighting; and
- leads negative-only by `4.33 bp/trade` under event-pooled weighting.

The weighting lenses disagree, so inefficient sideways movement has not earned
incremental-gate status. The primary exceeds the sideways-all control by about
`11 bp/trade` under both lenses, confirming that negative prior return matters.
The trending-negative control is especially heterogeneous: `+15.06 bp/trade`
equal-sector excess but `-22.18 bp/trade` event-pooled.

Calendar context is also unstable. The primary has positive event-pooled excess
in only `2/6` TRAIN years, 2019 and 2021, and is negative in 2018, 2020, 2022,
and 2023.

## Interpretation

The new line is conceptually distinct from the persistent-selloff rebound, but
its first matched-control test does not support ER20-sideways as an incremental
permission gate. The data are more consistent with a broad negative-prior
rebound whose apparent state advantage depends on weighting and calendar
composition.

Because each rule applies its own non-overlap clock, the comparisons describe
deployable rule populations rather than a causal treatment effect or algebraic
decomposition of ER20 state.

## Status

`TRAIN_SIDEWAYS_LOSS_REBOUND_BASELINE_COMPLETE_STOP_BEFORE_RULE_OR_OOS`

Do not add severity, retune ER20, select sectors or years, change the inherited
20-session horizon, or query post-2023 outcomes. The next step is an operator
huddle, not another automatic feature or threshold search.

## Artifacts

- Packet:
  `runs/research_workbench/operator_hypothesis_lab/return_geometry_sideways_loss_rebound_baseline_20260829`.
- Runner:
  `scripts/inspect/run_return_geometry_sideways_loss_rebound.R`.
- Helpers:
  `operator_hypothesis_lab/R/return_geometry_sideways_loss_rebound.R`.
- Deck:
  `operator_hypothesis_lab/presentations/return_geometry_sideways_loss_rebound_lab.pptx`.
- Candidate ledger:
  `operator_hypothesis_lab/registries/proto_strategy_ledger.xlsx`.
