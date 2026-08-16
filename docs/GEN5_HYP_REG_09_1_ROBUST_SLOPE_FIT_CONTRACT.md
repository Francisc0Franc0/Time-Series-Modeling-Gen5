# HYP-REG-09.1 Volatility-Normalized Robust Slope and Fit Contract

Status: `EXECUTED_STOP_ROBUST_SLOPE_FIT_STRATEGY_GATES_FAILED_CONFIRMATION_NOT_RUN`

## Question

Can a causal, asset-relative measure of positive robust slope and unusually
orderly recent price travel improve fresh next-open entries in the unchanged
daily SMA8/SMA14 long/cash parent?

The lane separates three properties that are often collapsed into “trend”:

- direction: the sign of a robust log-price slope;
- strength: displacement relative to realized return noise;
- quality: how monotonically price traveled through the estimation window.

## Evidence Boundary

- Identifier: `HYP-REG-09.1`.
- Evidence label: `DEVELOPMENT_REUSED_WINDOW`.
- Analysis: 2018-01-02 through 2023-12-29.
- Panel: the frozen 24-stock strategy panel plus SPY and QQQ references.
- Bars: adjusted daily OHLCV with explicit as-of timestamp
  `2026-08-15 17:30:00 America/New_York`.
- Confirmation: 2024-01-02 onward remains sealed unless all strategy-relative
  development gates pass and the operator separately opens confirmation.
- No horizon, threshold, feature, asset, or strategy search is authorized.

## Stage A — Measurement Construction

For `n` completed closes, fit log price against session index using the
Theil-Sen slope:

```text
b_TS = median[(log(P_j) - log(P_i)) / (j - i)]  for every i < j
```

Primary window: `n = 60` sessions. Durability-only window: `n = 120` sessions.

Normalize the primary slope as total fitted displacement relative to random
walk-scale realized noise:

```text
normalized_strength = b_TS * sqrt(n - 1) / sd(diff(log(P)))
```

Measure path quality independently:

```text
path_quality = abs(SpearmanCorr(session_index, log(P)))
```

`path_quality` is high for an orderly rise or decline. It has no direction.
The sign of `normalized_strength` retains direction.

Rank the current 60-session `path_quality` against the prior 252 completed
quality observations, excluding the current row. Use causal hysteresis:

- enter `HIGH_QUALITY` at percentile `>= 70`; remain while `>= 60`;
- enter `LOW_QUALITY` at percentile `<= 30`; remain while `<= 40`;
- otherwise assign `MEDIUM_QUALITY` when the measurement is finite.

The 120-session construction is durability evidence only. It cannot replace
or rescue the 60-session construction.

Stage A must establish complete boundary-safe coverage; expected signed and
quality ordering on seeded clean, noisy, random-walk, and reversal paths;
volatility-scale invariance; append invariance; exact state semantics; and
usable two-sided state occupancy before any strategy outcome is accessed.

## Stage B — Frozen Strategy Contact

- Parent: unchanged daily SMA8/SMA14 long/cash.
- Signal: fresh close-date SMA8-above-SMA14 cross.
- Entry: next open, 1x long, only when the signal-date 60-session robust slope
  is positive and the state is `HIGH_QUALITY`.
- A rejected signal is skipped, not deferred.
- Exit: next open after the unchanged parent SMA8-below-SMA14 cross.
- No candidate-driven exit or position sizing.
- Costs: 5 bp per side primary; 10 bp per side stress.
- Annual cells reset at the start of each asset-year and compound internally.
- Baselines: unfiltered parent, buy-and-hold, and cash.
- Controls: 200 deterministic within-asset/year circular rotations of the
  complete eligibility flag. Select the 40 exposure-nearest controls using
  exposure only before reading control returns.

## Gates and Stop Rules

All nine common strategy gates remain required: causal integrity, exact parent
reproduction, construction integrity, median return above parent, at least
15/24 stocks improved, at least 4/6 positive median-excess years, no worse
median drawdown and Sharpe, positive absolute median return, and at least an
80th-percentile return versus exposure-nearest controls.

This is an educational reused-window development test. Do not rescue a failed
result by changing 60/120 windows, replacing Theil-Sen or Spearman, changing
70/60 hysteresis, adding a strength-magnitude threshold, selecting assets or
years, stacking ATR%, adding leverage, changing strategy mechanics, or opening
2024+.

## Executed Outcome

Stage A passed all `7 / 7` construction gates, but the entry policy passed only
`3 / 9` strategy gates. Median annual return fell from `8.95%` for the parent
to `-0.11%`; only `2 / 24` stocks and `1 / 6` years improved, and actual timing
ranked at the `26.2nd` percentile of exposure-nearest controls. Record
`STOP_ROBUST_SLOPE_FIT_STRATEGY_GATES_FAILED_CONFIRMATION_NOT_RUN`; retain the
measurement, prohibit rescue, and keep 2024+ sealed. See
`operator_hypothesis_lab/docs/HYP_REG_09_1_ROBUST_SLOPE_FIT_RESULTS.md`.
