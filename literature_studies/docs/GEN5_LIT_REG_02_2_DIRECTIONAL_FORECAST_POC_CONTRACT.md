# LIT-REG-02.2 Directional HMM Forecast-Skill Frontier Contract

Status: `FROZEN_IMPLEMENTATION_APPROVED_RESULTS_UNREAD`

Date frozen: 2026-08-19

## Question

Can the `LIT-REG-02.1` Markov-switching AR(1) architecture deliver calibrated,
causal H20 direction probabilities that repeatedly outperform three frozen
non-oracle baselines under fresh planted evidence, and where does that
forecast advantage disappear as signal, persistence, history, and noise
realism change?

This is a synthetic forecast-skill and detection-frontier exercise. It is not
a market-regime, alpha, or strategy test.

## Inherited Numerical Authority

- CRAN `hmmTMB` version `1.1.2`, installed only in ignored
  `.codex_r_libs`.
- The unchanged two-state state-dependent-intercept, AR(1)-slope, variance,
  and homogeneous-transition model from `02.1`.
- Six deterministic TRAIN-only starts; select the valid fit with greatest
  TRAIN likelihood.
- TRAIN-earned state ordering and the explicit Gen5 causal forward filter.
- H20 probabilities estimated from 2,000 deterministic forward paths.
- Non-overlapping H20 scoring origins.

The model remains:

```text
r_t | S_t=k, r_(t-1) ~ Normal(alpha_k + phi_k*r_(t-1), sigma_k^2)
Pr(S_t=j | S_(t-1)=i) = A_ij
```

Smoothed probabilities and Viterbi paths remain hindsight-only and cannot
enter any forecast or gate.

## Frozen Forecast Authorities

| ID | Authority | Purpose |
|---|---|---|
| `B0` | Constant TRAIN non-overlapping H20 positive-return frequency | Base-rate baseline |
| `B1` | One-state Gaussian AR(1) with exact H20 Gaussian probability | No-regime dynamic baseline |
| `B2` | Fixed-penalty ridge logistic using causal return summaries | Stronger direct forecast challenger |
| `H2` | Two-state `hmmTMB` Markov-switching Gaussian AR(1) | Primary candidate |
| `O1` | True planted state and parameters | Synthetic oracle ceiling only |

### B2 fixed challenger

At each non-overlapping TRAIN origin, construct only:

- latest one-session return;
- trailing five-session cumulative return;
- trailing 20-session cumulative return; and
- trailing 20-session realized standard deviation.

The binary target is the subsequent H20 cumulative-return sign. Standardize
features using TRAIN means and standard deviations. Fit logistic regression
with an unpenalized intercept and a fixed ridge penalty `lambda=1` on all four
slopes. Use base-R deterministic optimization; do not tune the penalty,
features, horizon, or threshold. OOS features may use only returns observed
through the forecast origin.

## Primary Metrics

- Brier score;
- clipped Bernoulli log loss;
- paired candidate-minus-baseline score differences;
- case win rates;
- pooled calibration intercept and slope;
- probability sharpness; and
- oracle distance.

Accuracy at `p=0.5`, hard-state accuracy, transition error, occupancy, and
state-label stability are diagnostics. They cannot promote or stop `02.2`
unless they expose a numerical or causal failure.

## Stage A — Fresh Forecast Confirmation

Twenty-four independent cases use seeds `75001:75024`, disjoint from every
`02.1` seed. Each case uses:

```text
total length       = 2,400
TRAIN              = first 1,800
OOS                = final 600
alpha              = [-0.0030, +0.0030]
phi                = [0.10, 0.10]
sigma              = [0.012, 0.012]
A                  = [[0.97,0.03],[0.03,0.97]]
```

For paired score differences, report a deterministic one-sided 90% upper
confidence bound using the Student-t sampling distribution across cases.

All gates are conjunctive:

| Gate | Requirement |
|---:|---|
| `A1` | `hmmTMB 1.1.2` is available; H2 and B2 are numerically valid in all 24 cases. |
| `A2` | Appending the final 100 observations changes no earlier causal H2 filtered probability by more than `1e-12`. |
| `A3` | Repeating the first case reproduces H2 parameters, H2/B2 probabilities, filters, and scores within `1e-10`. |
| `A4` | H2 mean Brier is lower than B0, B1, and B2; H2 beats each in at least 15 of 24 cases; every paired one-sided 90% upper confidence bound is below zero. |
| `A5` | H2 mean log loss is lower than B0, B1, and B2; H2 beats each in at least 15 of 24 cases; every paired one-sided 90% upper confidence bound is below zero. |
| `A6` | Pooled H2 calibration intercept is between `-0.50` and `+0.50`, slope is between `0.50` and `1.50`, and pooled probability standard deviation is at least `0.03`. |
| `A7` | O1 mean Brier is no worse than H2 beyond Monte Carlo tolerance `0.01`; all probabilities and scores are finite. |
| `A8` | Stage A seeds are exactly `75001:75024`, are unique, and do not overlap `72001:74010`; B2 TRAIN targets and OOS features satisfy the frozen causal-origin audit. |

Any Stage A failure records
`STOP_LIT_REG_02_2_FRESH_FORECAST_CONFIRMATION_FAILED` and stops before Stages
B and C. No gate, seed, feature, penalty, or fixture may be changed after
inspection.

## Stage B — Still-Unread Forecast Frontier

Run only after all Stage A gates pass. Inherit the never-executed `02.1`
64-case Cartesian grid and seeds `73001:73064`:

- absolute state intercept `d`: `0`, `0.0005`, `0.0015`, `0.0030`;
- self-transition probability: `0.90`, `0.97`;
- TRAIN length: `1,000`, `2,000`;
- four replicates per cell;
- OOS length `400`, `phi=[0.10,0.10]`, `sigma=[0.012,0.012]`.

Non-null states use `[-d,+d]`; null states use `[0,0]`.

A cell is forecast-detectable only if at least three fits are valid, mean H2
Brier and log loss are lower than all three baselines, and at least three of
four replicates beat all three baselines on both scores. This is a descriptive
boundary label, not market promotion. Report null-cell false detections,
calibration, sharpness, state diagnostics, and gains versus the best baseline.

## Stage C — Financial-Shaped Synthetic Stress

Run after Stage B completes. Inherit the never-executed `02.1` seeds
`74001:74010`, TRAIN `2,000`, OOS `600`, `alpha=[-0.0015,+0.0015]`,
`phi=[0.10,0.10]`, self-transition `0.97`, and standardized Student-t(6)
GARCH(1,1) innovations:

```text
h_t = omega + 0.07*epsilon_(t-1)^2 + 0.91*h_(t-1)
omega = (1 - 0.07 - 0.91) * 0.012^2
```

The fitted Gaussian model is deliberately misspecified. Stage C has no
promotion gate; report degradation versus Stage A and every baseline.

## Verdicts and Boundaries

- Stage A failure:
  `STOP_LIT_REG_02_2_FRESH_FORECAST_CONFIRMATION_FAILED`.
- Stage A pass with Stages B and C completed:
  `COMPLETE_LIT_REG_02_2_SYNTHETIC_FORECAST_FRONTIER_MAPPED_MARKET_NOT_OPENED`.

The COMPLETE verdict opens only a discussion of a separately frozen
semi-synthetic or honest market TRAIN/OOS developmental test. It does not
authorize market selection, strategy outcomes, thresholds, entries, exits,
PnL, Sharpe, drawdown, allocation, leverage, live advice, or execution.

## Required Evidence

- immutable decision, contract, and model registry;
- run manifest and complete multistart diagnostics;
- Stage A case forecasts, score table, calibration, gates, and causal replay;
- Stage B case and cell frontier tables including null behavior;
- Stage C stress comparison;
- representative probability tape;
- high-impact calibration, skill, frontier, and stress visuals;
- beginner-accessible PowerPoint with formulae and speaker-note sources; and
- explicit confirmation that no market or strategy data were read.

## No-Rescue Rule

Do not change the inspected `02.1` result or the `02.2` seeds, signal levels,
history lengths, persistence values, features, ridge penalty, horizon,
simulation count, starts, baselines, confidence level, calibration bounds,
gates, or verdict vocabulary. Alternative horizons, emissions, covariates,
HSMMs, cross-sectional states, market data, or strategy contact require a new
discussion and contract.
