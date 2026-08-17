# HYP-REG-10.1 Multi-Horizon Direction Agreement Contract

Status: `STOP_MULTI_HORIZON_AGREEMENT_STRATEGY_GATES_FAILED_CONFIRMATION_NOT_RUN`

## Question

Can causal agreement in volatility-normalized price direction across short,
medium, and long horizons improve fresh next-open entries in the unchanged
daily SMA8/SMA14 long/cash parent?

This is not a lookback-selection exercise. The three horizons are one
predeclared description of cross-scale alignment.

## Evidence Boundary

- Identifier: `HYP-REG-10.1`.
- Evidence label: `DEVELOPMENT_REUSED_WINDOW`.
- Analysis: 2018-01-02 through 2023-12-29.
- Panel: the frozen 24-stock strategy panel plus SPY and QQQ references.
- Bars: adjusted daily OHLCV with explicit as-of timestamp
  `2026-08-15 17:30:00 America/New_York`.
- Confirmation: 2024-01-02 onward remains sealed unless every development
  strategy gate passes and the operator separately opens confirmation.
- No horizon, threshold, feature, asset, or strategy search is authorized.

## Stage A — Measurement Construction

Freeze horizons `h = 20, 60, 120` completed sessions. For each horizon:

```text
R_h(t) = log(P_t / P_(t-h))
V_h(t) = sd[diff(log(P_(t-h), ..., P_t))] * sqrt(h)
Z_h(t) = R_h(t) / V_h(t)
S_h(t) = sign(Z_h(t))
```

`Z_h` is signed displacement relative to realized noise at the same scale.
Its sign supplies direction. The three windows overlap and are not independent
votes, p-values, or separate confirmations.

Primary state:

- `FULL_UP`: `S20 = S60 = S120 = +1`;
- `FULL_DOWN`: `S20 = S60 = S120 = -1`;
- `SHORT_OPPOSES_UP`: `S20 = -1`, `S60 = S120 = +1`;
- `SHORT_OPPOSES_DOWN`: `S20 = +1`, `S60 = S120 = -1`;
- `MIXED`: every other finite sign pattern.

Preserve `agreement_score = (S20 + S60 + S120) / 3` and the fraction of signs
on the majority side. Separately mark a one-session `SHORT_JOINS_UP` or
`SHORT_JOINS_DOWN` event when the 60/120 context is unchanged, yesterday's
short sign opposed that context, and today's short sign newly agrees. These
events are descriptive only.

Stage A must establish complete boundary-safe coverage; exact expected states
on seeded clean-up, clean-down, short-reversal-up, and short-reversal-down
paths; price-scale invariance; append invariance; exact state and join-event
semantics; and usable real-panel `FULL_UP`/`FULL_DOWN` occupancy before any
strategy outcome is accessed.

## Stage B — Frozen Strategy Contact

- Parent: unchanged daily SMA8/SMA14 long/cash.
- Signal: fresh close-date SMA8-above-SMA14 cross.
- Entry: next open, 1x long, only when the signal-date state is `FULL_UP`.
- A rejected signal is skipped, not deferred.
- Exit: next open after the unchanged parent SMA8-below-SMA14 cross.
- No transition-event entry, candidate-driven exit, or position sizing.
- Costs: 5 bp per side primary; 10 bp per side stress.
- Annual cells reset at each asset-year start and compound internally.
- Baselines: unfiltered parent, buy-and-hold, and cash.
- Controls: 200 deterministic within-asset/year circular rotations of the
  complete `FULL_UP` eligibility flag. Select 40 exposure-nearest controls
  using exposure only before reading their returns.

## Gates and Stop Rules

All nine common strategy gates remain required: causal integrity, exact parent
reproduction, construction integrity, median return above parent, at least
15/24 stocks improved, at least 4/6 positive median-excess years, no worse
median drawdown and Sharpe, positive absolute median return, and at least an
80th-percentile return versus exposure-nearest controls.

Do not rescue a failed result by changing 20/60/120, adding magnitude
thresholds, using majority-up instead of `FULL_UP`, selecting join/opposition
events, choosing assets or years, stacking ATR%, adding leverage, changing the
SMA parent, or opening 2024+.

## Post-Series HMM Bookmark — Not Opened

After T1–T5 are complete, if none earns promotion, discuss Hidden Markov
Models as a distinct lane. Before freezing any HMM:

- inventory operator-provided PDFs and primary literature;
- decide whether it belongs in Literature Studies or Operator Hypothesis Lab;
- define observable inputs, state-count discipline, causal filtering versus
  retrospective smoothing, label interpretation, and held-out validation;
- prohibit return-selected state labels and post-hoc state relabeling.

This bookmark does not authorize an HMM implementation, data query, state
count, strategy, or confirmation access.

## Completed Readout

All 7/7 construction gates passed: the fixed state recovered every intended
seeded path family, was price-scale and append invariant, retained exact state
and join semantics, and had usable two-sided occupancy across all 24 primary
stocks. The unchanged parent reproduced 156/156 annual cells.

The `FULL_UP` fresh-entry gate then passed only 3/9 strategy gates. Median
annual return fell from 8.95% to -0.68%, only 1/24 stocks and 1/6 years
improved, median Sharpe fell from 0.642 to -0.203, and actual timing ranked at
the 12.5th percentile of exposure-nearest controls. Improved median drawdown
(-7.69% versus -14.59%) was purchased by collapsing median exposure to 17.50%
and did not satisfy the frozen protection-and-Sharpe bargain.

Retain the measurement, stop the binary policy, keep 2024+ sealed, and do not
open a rescue. The detailed readout is in
`operator_hypothesis_lab/docs/HYP_REG_10_1_MULTI_HORIZON_AGREEMENT_RESULTS.md`.
