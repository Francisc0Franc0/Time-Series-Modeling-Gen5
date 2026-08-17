# HYP-REG-12.1 Causal Upper-Range Persistence Results

Status: `STOP_RANGE_PERSISTENCE_STRATEGY_GATES_FAILED_CONFIRMATION_NOT_RUN`

## Question and Boundary

Can sustained residence in the upper quarter of the preceding 63-session
close range improve fresh next-open entries in the unchanged daily SMA8/SMA14
long/cash parent?

This is `DEVELOPMENT_REUSED_WINDOW` evidence over 2018-2023. The panel contains
24 primary stocks plus SPY and QQQ references. The range length, 0.75/0.25
thresholds, three-of-five persistence rule, ten-session event ledger, parent,
costs, and gates were frozen before the run. The 2024+ interval remained
sealed.

## Measurement

The current close is located in the preceding 63 completed closes:

```text
RP_t = (P_t - prior_low_63) / (prior_high_63 - prior_low_63)
```

`RP_t` is uncapped. `UPPER_PERSISTENT` requires `RP_t >= 0.75` now and on at
least three of the latest five causal observations. A symmetric lower state is
retained for construction checks. A separate event ledger starts when
`RP_t > 1`, freezes the old range high as its boundary, and records ten
non-extending sessions of hold, retest, and failure behavior.

## Stage A — Clean Positive Measurement Result

All 7/7 construction gates passed:

- 26/26 assets had complete coverage and at least 503 prehistory sessions;
- clean synthetic up/down paths ended in the intended state on 100% of paths;
- breakout-hold and rapid-failure fixtures expressed their intended outcome
  on 100% of paths;
- maximum price-scale difference was `2.44e-15` and states were identical;
- all 19 append-causality columns were exactly unchanged;
- there were zero state or event-boundary semantic violations;
- 24/24 stocks had 10%-60% upper-state occupancy and at least three eligible
  fresh SMA cross-ups.

Median `UPPER_PERSISTENT` occupancy was 38.3%. Across 940 completed primary
stock breakout events in the analysis window, 36.1% failed within three
sessions, 63.1% were still above the frozen boundary on session ten, and the
median event spent 80% of its ten sessions above the boundary. The measurement
therefore describes a real and interpretable aspect of the price path.

## Stage B — Hard Entry Gate Failed

The entry-only overlay passed 3/9 strategy gates:

| Metric | Parent | Upper-persistence gate |
|---|---:|---:|
| Median annual return | 8.95% | 0.00% |
| Median maximum drawdown | -14.59% | -8.04% |
| Median Sharpe | 0.642 | -0.132 |
| Median exposure | 53.88% | 15.91% |
| Trades | 1,394 | 480 |
| Positive annual cells | 70.1% | 41.0% |

Only JPM improved over the six-year compounded comparison, so asset breadth
was 1/24. Only 2018 had positive median excess return, so calendar breadth was
1/6. At 10 bp per side, median annual return was -0.18%.

The actual schedule ranked at the 61.3rd percentile of the 40
exposure-nearest circular controls and did not beat their median return. The
drawdown improvement was chiefly a low-exposure/cash effect, not a superior
return-and-risk bargain.

## Trade-Level Interpretation

The parent trade audit argues against treating the failure as mere scarcity:

| Entry context | Trades | Hit rate | Median trade |
|---|---:|---:|---:|
| Other | 811 | 48.0% | -0.15% |
| Upper but not persistent | 103 | 45.6% | -0.28% |
| `UPPER_PERSISTENT` | 480 | 43.1% | -0.68% |

The range state is a good description of sustained strength, but requiring a
fresh short-SMA cross only after price is already persistently high in its
quarterly range appears late or extended. This is an inference from the frozen
audit, not authority to invert the state, change the parent, or create a direct
breakout entry after seeing the result.

## Decision

Record `STOP_RANGE_PERSISTENCE_STRATEGY_GATES_FAILED_CONFIRMATION_NOT_RUN`.
Retain the continuous range-position and breakout-event ledgers as descriptive
research artifacts. Do not change 63 sessions, the thresholds, persistence
count, event horizon, parent, costs, assets, or ATR join to rescue the lane.
Do not access 2024+.

T5 completes the precommitted T1-T5 trend-indicator series without a promoted
hard entry filter. The previously bookmarked next gate is a literature-first
discussion of Hidden Markov Models. It must begin with source inventory,
identifiability and state-stability cautions, a minimal frozen question, and a
fresh decision about whether an HMM is a descriptive state model or a trading
authority. No HMM implementation is authorized by this result alone.

This closeout is scoped to the common validation design. The SMA8/SMA14 parent
was one controlled test of whether the candidate measurement improved a
specific causal decision on the tested daily or 30-minute surface. Failure
does not establish that range persistence or any other T1-T5 concept is
categorically useless. Reuse would require a genuinely new, predeclared
question and validation design rather than a reactive rescue of this result.

## Evidence Packet

`runs/research_workbench/operator_hypothesis_lab/hyp_reg_12_1_range_persistence_20260817`
