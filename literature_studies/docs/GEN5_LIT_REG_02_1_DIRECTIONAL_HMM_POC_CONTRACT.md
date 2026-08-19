# LIT-REG-02.1 Directional Markov-Switching Proof-of-Mechanism Contract

Status: `FROZEN_IMPLEMENTATION_APPROVED_RESULTS_UNREAD`

Date frozen: 2026-08-19

## Question

Can a package-native two-state Markov-switching AR(1) recover and causally
forecast a known persistent directional return process, and where does that
ability break down as drift separation, persistence, sample length, and noise
realism change?

This is a proof-of-mechanism and detection-boundary exercise. It is not a
market-regime, alpha, or strategy test.

## Numerical Authority

- CRAN package: `hmmTMB` version `1.1.2`.
- Estimation: TMB maximum likelihood through `HMM$fit()`.
- Installation: ignored `.codex_r_libs`; no package files enter git.
- Approved by the operator on 2026-08-19 after the package-specific approval
  gate.
- Six deterministic initializations per case; the converged finite fit with
  greatest TRAIN likelihood is selected without OOS inspection.
- A compact Gen5 recursion independently computes causal filtering,
  likelihood contributions, and append invariance from the selected package
  parameters. It is not a second estimator.

## Model

For states `S_t in {1,2}`:

```text
r_t | S_t=k, r_(t-1) ~ Normal(alpha_k + phi_k*r_(t-1), sigma_k^2)
Pr(S_t=j | S_(t-1)=i) = A_ij
```

The `hmmTMB` observation formula is `ret.mean ~ ret_lag`. Both intercept and
slope are state dependent. Transition probabilities are homogeneous and the
initial distribution is stationary.

Numerically valid fits require:

- optimizer convergence code zero;
- finite likelihood, coefficients, transition probabilities, and positive
  standard deviations;
- `abs(phi_k) < 0.995` for both states;
- transition rows summing to one within `1e-10`; and
- no state with TRAIN filtered expected occupancy below `2%`.

## State Identity

For each fitted state, start from return zero and keep that state fixed for 20
steps under the fitted AR(1). Sum its expected returns. Order the entire model
by this TRAIN-only score:

- lower score: `LESS_FAVORABLE`;
- higher score: `MORE_FAVORABLE`.

The ordering is applied consistently to emissions, transition probabilities,
and causal probabilities. OOS truth and outcomes never define the labels.

## Forecast Target and Causality

Primary horizon: `H=20` completed sessions.

At each eligible OOS origin `t`, after filtering `r_t`, estimate:

```text
p_t = Pr(sum(r_(t+1), ..., r_(t+20)) > 0 | observations through t)
```

The probability is estimated with 2,000 deterministic forward simulations
from the causal filtered distribution, fitted transition matrix, and fitted
AR(1) emissions. Origins advance by 20 sessions for primary scoring so target
intervals do not overlap. A daily probability tape is allowed only for the
single representative teaching case and is not used to inflate evidence.

Smoothed probabilities and Viterbi paths are hindsight-only diagnostics and
cannot enter any gate.

## Baselines and Oracle

- `B0`: the TRAIN non-overlapping 20-session positive-return frequency,
  emitted as one constant probability.
- `B1`: one-state Gaussian AR(1), fit by TRAIN OLS, with the exact Gaussian
  20-session cumulative-return probability.
- `H2`: the two-state `hmmTMB` Markov-switching AR(1).
- `O1`: synthetic oracle using the true current state and true parameters.
  It is a ceiling diagnostic, never a deployable comparator.

Report Brier score, clipped Bernoulli log loss, calibration intercept/slope
where estimable, sign accuracy at `p=0.5`, and probability sharpness. Brier
and log loss are primary; raw accuracy cannot pass a gate by itself.

## Stage A — Teaching Positive Control

Ten cases use seeds `72001:72010`.

```text
total length       = 2,400
TRAIN              = first 1,800
OOS                = final 600
alpha              = [-0.0030, +0.0030]
phi                = [0.10, 0.10]
sigma              = [0.012, 0.012]
A                  = [[0.97,0.03],[0.03,0.97]]
initial state      = stationary
```

All gates are conjunctive:

| Gate | Requirement |
|---:|---|
| A1 | `hmmTMB 1.1.2` is available and all 10 cases produce a numerically valid selected fit. |
| A2 | Appending the final 100 OOS observations changes no earlier causal filtered probability by more than `1e-12`. |
| A3 | Median OOS filtered hard-state accuracy is at least `85%`, and the tenth percentile is at least `75%`. |
| A4 | Median maximum transition-matrix error is at most `0.05`, and the ninetieth percentile is at most `0.10`. |
| A5 | H2 mean Brier score is lower than both B0 and B1, and H2 beats each in at least 8 of 10 cases. |
| A6 | H2 mean log loss is lower than both B0 and B1, and H2 beats each in at least 8 of 10 cases. |
| A7 | O1 mean Brier score is no worse than H2 beyond Monte Carlo tolerance `0.01`; all forecast probabilities and scores are finite. |
| A8 | Repeated execution with the same seeds reproduces selected parameters, filters, and scores within `1e-10`. |

Any Stage A failure stops before Stages B and C. The result is still preserved
as package/mechanics evidence.

## Stage B — Frozen Detection Frontier

Run only after all Stage A gates pass. Every cell uses Gaussian innovations,
`phi=[0.10,0.10]`, `sigma=[0.012,0.012]`, 400 OOS observations, and four
replicates. The grid is the Cartesian product:

- absolute state intercept: `0`, `0.0005`, `0.0015`, `0.0030`;
- self-transition probability: `0.90`, `0.97`;
- TRAIN length: `1,000`, `2,000`.

Non-null states use symmetric intercepts `[-d,+d]`; null cells use identical
zero intercepts. Seeds begin at `73001` in registry order.

Stage B is characterization, not a winner search. For every cell report:

- numerical-fit rate;
- median OOS state accuracy for non-null cells;
- H2-minus-B0 and H2-minus-B1 Brier and log-loss deltas;
- fraction of replicates beating each baseline;
- probability sharpness and calibration;
- state occupancy, transition error, and label stability; and
- false apparent separation in null cells.

The detection boundary is the weakest cell for which at least 3 of 4
replicates are numerically valid and H2 beats both baselines on both Brier and
log loss. This label is descriptive development evidence, not promotion.

## Stage C — Financial-Shaped Synthetic Stress

Run after Stage B completes. Ten cases use seeds `74001:74010`, TRAIN length
2,000, OOS length 600, the moderate directional process
`alpha=[-0.0015,+0.0015]`, `phi=[0.10,0.10]`, and self-transition `0.97`.

Innovations are standardized Student-t with six degrees of freedom and
GARCH(1,1) conditional variance:

```text
h_t = omega + 0.07*epsilon_(t-1)^2 + 0.91*h_(t-1)
omega = (1 - 0.07 - 0.91) * 0.012^2
```

The fitted Gaussian Markov-switching AR(1) is intentionally misspecified.
Report the same recovery and forecasting metrics as Stage A. Stage C has no
promotion gate; it measures how the mechanism degrades under heavy tails and
volatility clustering.

This is fully synthetic financial-shaped noise, not real or semi-synthetic
market evidence. A real-residual semi-synthetic bridge remains a documented
future option requiring a new data contract.

## Required Evidence

- immutable contract and model registry;
- package/version and run manifest;
- complete multistart diagnostics;
- case-level recovery and forecast scorecards;
- Stage A conjunctive gate table;
- Stage B detection-frontier table;
- Stage C stress comparison;
- representative causal probability/state tape;
- high-impact recovery, forecast, and frontier charts;
- beginner-accessible PowerPoint with formulae and speaker-note sources; and
- explicit statement that no market or strategy data were read.

## Boundaries and Verdicts

- Stage A failure:
  `STOP_LIT_REG_02_1_DIRECTIONAL_MECHANISM_QUALIFICATION_FAILED`.
- Stage A pass with B/C complete:
  `PASS_LIT_REG_02_1_DIRECTIONAL_MECHANISM_DETECTION_BOUNDARY_MAPPED`.

The PASS means only that the mechanism works when planted and its detection
boundary was measured. It opens discussion of a separately frozen
semi-synthetic or real-market developmental test. It does not authorize asset
selection, strategy outcomes, PnL, Sharpe, drawdown, entries, exits,
allocation, leverage, confirmation data, live advice, or execution.

## No-Rescue Rule

After outcomes are inspected, do not alter seeds, process parameters, grid,
forecast horizon, simulation count, starts, validity rules, baselines, gates,
or verdict vocabulary. Any Student-t emission, HSMM, transition covariate,
cross-sectional model, alternative horizon, market data, or strategy overlay
requires a separately discussed and frozen variant or concept.
