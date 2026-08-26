# TSLA Prior-Return Sign Asymmetry, 2018–2023

## Question

Does pooling positive and negative prior cumulative log returns hide different relationships with TSLA's following cumulative log return?

This is a descriptive measurement slice. It does not define an entry, exit, position, strategy, or performance claim.

## Fixed Design

- Asset: TSLA adjusted daily OHLCV from Alpaca SIP.
- Analysis window: 2018-01-02 through 2023-12-29. No post-2023 data were read.
- Prior and forward horizons: `1, 2, 3, 4, 5, 10, 15, 20, 25` sessions.
- Prior return: `X = log(close[t] / close[t-p])`.
- Following return: `Y = log(close[t+f] / close[t])`; the future begins after anchor close `t`.
- Sign branches: `X < 0` and `X > 0`. Exact zeros are excluded and counted. Negative returns remain negative rather than being converted to absolute magnitudes.
- Descriptive branch statistics: count, mean/median future return, probability the future return is positive, Pearson correlation, Spearman correlation, OLS slope, and HAC interval.
- Direct asymmetry model: `Y ~ X * I(X > 0)`, allowing both the intercept and slope to differ across sign branches.
- Primary null: the positive-branch slope equals the negative-branch slope.
- Uncertainty: Newey-West/HAC with lag `max(p + f - 1, floor(4 * (n / 100)^(2/9)))`.
- Multiplicity: BH-FDR across 81 unfiltered slope-interaction tests, 162 ER20 state-specific tests, and 243 ATR% state-specific tests.

The ER20 labels are the prior causal `ER20 < 0.30` red/sideways and `ER20 >= 0.30` green/trending states. The ATR% labels are the accepted HYP-REG-01.1 TSLA LOW/MEDIUM/HIGH states based on Wilder ATR14/close, a prior-252 percentile excluding the current row, and the frozen hysteresis rules. Both states are assigned at the anchor close before the forward return begins.

## How to Read the Branch Slopes

- Positive prior return and positive slope: larger gains align with larger future gains—upside continuation.
- Positive prior return and negative slope: larger gains align with weaker future returns—giveback.
- Negative prior return and positive slope: because `X` stays negative, larger losses align with more negative future returns—downside continuation.
- Negative prior return and negative slope: larger losses align with higher future returns—rebound geometry.

The positive-minus-negative correlation panels are descriptive. Any black outline comes from the direct slope-interaction test after the stated BH correction.

## Adjacent-Session 1×1 Result

The original 1,509-pair sample is reproduced exactly:

| Prior branch | n | Pearson | Spearman | OLS slope | Mean next return | P(next up) |
|---|---:|---:|---:|---:|---:|---:|
| Negative | 717 | -0.1293 | -0.0543 | -0.1819 | +0.101% | 52.9% |
| Positive | 792 | +0.0376 | +0.0171 | +0.0530 | +0.222% | 52.1% |

The positive-minus-negative slope difference is `+0.2349`, with a HAC 95% interval `[+0.0901, +0.3796]`, raw p=`0.0015`, and BH q=`0.0442` across the full unfiltered 81-cell family.

This is not ordinary sign persistence. A negative prior day does not simply make the next day more likely to be up: the observed up probabilities are 52.9% after a negative return and 52.1% after a positive return. The result is primarily a within-negative-branch rebound slope: more-negative prior observations align with higher following returns. Its Spearman magnitude is smaller than Pearson, so tail leverage remains a live concern.

## Unfiltered 9×9 Result

Four direct slope-asymmetry tests survive the 81-cell BH correction:

| Prior | Forward | Negative slope | Positive slope | Difference | Raw p | BH q |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 1 | -0.1819 | +0.0530 | +0.2349 | 0.0015 | 0.0442 |
| 20 | 4 | -0.1377 | +0.0149 | +0.1526 | 0.0022 | 0.0442 |
| 20 | 5 | -0.1707 | +0.0233 | +0.1941 | 0.0014 | 0.0442 |
| 20 | 10 | -0.2831 | +0.0441 | +0.3272 | 0.0021 | 0.0442 |

The medium-horizon cluster is coherent: after negative 20-session returns, the relationship with the next 4–10 sessions is negative, while the positive-prior branch is near zero. Rank correlations in the negative branch are also negative (`-0.127` to `-0.175`), so the cluster is not purely a single Pearson cell. The cells are nevertheless highly dependent because they share observations and nested horizons.

## ER20 Result

No ER20 state-specific slope-asymmetry test survives BH-FDR: `0/162`.

Red/sideways and green/trending maps visibly reorganize the branch correlations, but the direct positive-versus-negative slope difference is not multiplicity-stable once the two states and 81 horizons per state are treated as one family. ER20 and the prior-return variable are both functions of TSLA's trailing price path, so the maps are descriptive conditioning—not causal moderation.

## ATR% Result

Five ATR% state-specific slope-asymmetry tests survive the 243-test BH family:

| ATR% state | Prior | Forward | Negative slope | Positive slope | Difference | BH q |
|---|---:|---:|---:|---:|---:|---:|
| HIGH | 1 | 1 | -0.3051 | +0.0478 | +0.3530 | 0.0380 |
| LOW | 20 | 15 | -1.0235 | +0.1020 | +1.1255 | 0.0374 |
| LOW | 20 | 20 | -1.3195 | +0.1115 | +1.4310 | 0.0374 |
| LOW | 25 | 15 | -0.8450 | +0.0654 | +0.9104 | 0.0489 |
| LOW | 25 | 20 | -1.0785 | +0.0359 | +1.1144 | 0.0380 |

The LOW-state long-horizon negative branches contain only 165–167 observations, versus roughly 394–401 positive observations. Their Spearman correlations (`-0.406` to `-0.456`) are at least as negative as Pearson, so the geometry is not explained by Pearson alone. But the average future return after a negative prior return is still slightly negative in those LOW-state cells. The slope says that more-severe losses within the negative branch align with less-negative or more-positive futures; it does not say the branch as a whole has positive expected return.

The HIGH-state 1×1 survivor resembles the aggregate adjacent-session result and suggests the next-day rebound slope is concentrated in high movement-capacity periods. Because ATR% and prior return use the same asset history, this may partly be conditioning geometry.

## Decision

`DESCRIPTIVE_SIGN_ASYMMETRY_FOUND_STOP_BEFORE_RULE`

The aggregate surface was washing out a real in-sample asymmetry. The asymmetry is not “green follows green.” It is mainly rebound geometry inside the negative-prior branch, with:

- an adjacent-session survivor concentrated in HIGH ATR%, and
- a coherent 20–25 prior / 15–20 forward cluster in LOW ATR%.

This does not open a strategy gate. The result was discovered on the same 2018–2023 research surface, the survivor cells are dependent, the 1×1 Pearson effect is stronger than its rank counterpart, and the state variables share TSLA history with the predictor.

The next narrow gate, if approved, should freeze only the survivor cells and test outlier sensitivity plus temporal stability without changing horizons, states, or the 2023 boundary. No trading rule should be formulated before that check.

## Artifacts

- Script: `scripts/inspect/run_tsla_prior_return_sign_asymmetry.R`
- Packet: `runs/research_workbench/operator_hypothesis_lab/tsla_prior_return_sign_asymmetry_20260825`
- Running deck: `operator_hypothesis_lab/presentations/tsla_descriptive_microscope_evidence.pptx`
- Main tables: `one_by_one_branch_summary.csv`, `one_by_one_asymmetry_test.csv`, `unfiltered_asymmetry_tests.csv`, `er20_asymmetry_tests.csv`, and `atrp_asymmetry_tests.csv`
- Main visuals: the 1×1 sign-split scatter and the unfiltered, ER20, and ATR% sign-branch heatmap panels under `visuals/`
