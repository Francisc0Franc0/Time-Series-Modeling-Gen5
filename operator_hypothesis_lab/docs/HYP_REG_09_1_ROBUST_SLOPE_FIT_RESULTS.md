# HYP-REG-09.1 Volatility-Normalized Robust Slope and Fit Results

Status: `STOP_ROBUST_SLOPE_FIT_STRATEGY_GATES_FAILED_CONFIRMATION_NOT_RUN`

## Bottom Line

The measurement worked; the proposed use did not.

The 60-session Theil-Sen slope, volatility-normalized strength, and independent
Spearman path-quality score passed every frozen construction gate. They were
causal, scale invariant, append invariant, directionally correct on synthetic
paths, and usable across the full 24-stock panel. However, requiring a fresh
SMA8/SMA14 cross-up to have both positive slope and a causally unusual
`HIGH_QUALITY` path produced a sparse entry policy that was materially worse
than the unchanged parent and ordinary exposure-matched timing.

This is a useful educational STOP. It shows that a coherent description of an
orderly upward path is not automatically a good permission rule for entering
a short moving-average momentum strategy.

## Frozen Construction

For every 60 completed adjusted closes, the primary robust slope was:

```text
b_TS = median[(log(P_j) - log(P_i)) / (j - i)] for every i < j
```

The slope sign supplied direction. Strength and quality remained separate:

```text
normalized_strength = b_TS * sqrt(59) / sd(diff(log(P)))
path_quality         = abs(SpearmanCorr(session_index, log(P)))
```

Current quality was ranked only against the prior 252 completed quality
observations. Causal hysteresis entered `HIGH_QUALITY` at the 70th percentile
and retained it through the 60th percentile; `LOW_QUALITY` used 30/40. A
120-session version was durability evidence only and could not replace the
60-session primary.

The Theil-Sen estimator follows Theil's rank-invariant regression construction
and Sen's median-of-pairwise-slopes formulation. Spearman rank correlation is
used only as a monotonic path-quality description, not as an independent-error
regression test or a claim about future return.

## Stage A — Measurement Audit

All `7 / 7` frozen construction gates passed:

- complete 26-asset coverage, at least 503 prehistory sessions, and no 2024+
  access;
- clean synthetic rises had positive slope on 100% of eligible observations,
  while clean declines had 0% positive slope;
- median path quality ordered as intended: clean rise `1.000`, clean decline
  `1.000`, noisy rise `0.758`, random walk `0.612`, reversal `0.049`;
- price-scale invariance held to machine precision;
- appending future data changed no previously calculated value;
- state and eligibility semantics had zero violations;
- all `24 / 24` primary stocks had usable HIGH/LOW states and at least 3%
  eligible sessions; median eligibility was `24.0%`.

The 60- and 120-session slope signs agreed on a median `70.5%` of dates, but
their path-quality association was only `0.184`. That supports treating the
120-session view as a genuinely different durability lens rather than a rescue
or duplicate confirmation.

## Stage B — Unchanged Strategy Replay

The parent was the already-audited daily SMA8/SMA14 long/cash rule. A fresh
cross-up entered next open only when signal-close strength was positive and
quality state was `HIGH_QUALITY`; skipped signals were not deferred. Parent
exits, 1x leverage, 5 bp per side, annual compounding, and baselines were
unchanged.

Parent reproduction passed all `156 / 156` retained cells with a maximum
difference of `4.44e-15`. The primary stock comparison used 144 asset-year
cells.

| Metric | Unfiltered parent | Orderly-up entry gate |
|---|---:|---:|
| Median annual return | 8.95% | -0.11% |
| Median maximum drawdown | -14.59% | -4.63% |
| Median Sharpe | 0.642 | -0.278 |
| Median exposure | 53.88% | 6.02% |
| Median turnover | 19.67 | 3.99 |
| Trades | 1,394 | 273 |
| Positive asset-year fraction | 70.14% | 31.94% |

The lower drawdown was mostly the mechanical result of being in cash. It did
not come with an acceptable return or Sharpe bargain.

## What the Entry Audit Revealed

The hard gate did not isolate superior parent trades:

| Signal-close group | Trades | Hit rate | Mean trade | Median trade |
|---|---:|---:|---:|---:|
| Non-positive slope | 613 | 50.57% | 2.21% | 0.13% |
| Positive slope, not HIGH quality | 508 | 41.93% | 0.65% | -0.68% |
| Positive slope and HIGH quality | 273 | 43.96% | 0.25% | -0.57% |

An orderly recent rise was therefore not a favorable cross-up entry context in
this parent. In practice, it often admitted a late or already-mature move while
excluding many of the parent's large convex winners.

## Breadth and Falsification

- only `2 / 24` stocks improved over the six-year development span;
- only `1 / 6` years had positive panel-median excess, and that year was 2018;
- 2019-2023 each had negative median excess;
- the actual policy ranked at only the `26.2nd` percentile of 40
  exposure-nearest controls selected from 200 deterministic circular
  rotations;
- the actual median return was `-0.11%`, equal to the median of the selected
  controls to reported precision.

The policy passed only integrity, exact parent reproduction, and construction
integrity: `3 / 9` gates. Return, asset breadth, calendar breadth, protection
plus Sharpe, absolute viability, and timing specificity all failed.

## Decision Boundary

Record
`STOP_ROBUST_SLOPE_FIT_STRATEGY_GATES_FAILED_CONFIRMATION_NOT_RUN`.

Retain the measurement implementation as an auditable descriptive tool. Do
not rescue this policy by changing 60/120 windows, adding a strength threshold,
selecting assets or years, replacing Theil-Sen or Spearman, softening the
quality state, stacking ATR%, changing the SMA parent, adding leverage, or
opening 2024+.

The next roadmap discussion may open T3 multi-horizon direction agreement as a
genuinely different question. It must not inherit favorable choices from this
failed policy.

## Artifacts

- Contract: `docs/GEN5_HYP_REG_09_1_ROBUST_SLOPE_FIT_CONTRACT.md`
- Registry: `operator_hypothesis_lab/registries/hyp_reg_09_1_robust_slope_fit_registry.csv`
- Runner: `operator_hypothesis_lab/scripts/run_hyp_reg_09_1_robust_slope_fit_poc.R`
- Packet: `runs/research_workbench/operator_hypothesis_lab/hyp_reg_09_1_robust_slope_fit_20260816`
- Evidence deck: `operator_hypothesis_lab/presentations/hyp_reg_09_1_robust_slope_fit_evidence.pptx`

## Literature Anchors

- Henri Theil (1950), “A Rank-Invariant Method of Linear and Polynomial
  Regression Analysis”: <https://ir.cwi.nl/pub/18445>
- Pranab K. Sen (1968), “Estimates of the Regression Coefficient Based on
  Kendall's Tau”: <https://doi.org/10.1080/01621459.1968.10480934>
- Charles Spearman (1904), “The Proof and Measurement of Association between
  Two Things”: <https://doi.org/10.2307/1412159>
