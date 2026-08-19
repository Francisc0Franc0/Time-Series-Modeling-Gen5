# LIT-REG-01.2 HMM Volatility-State POC Contract

Status: `FROZEN_IMPLEMENTATION_APPROVED_RESULTS_UNREAD`

Date frozen: 2026-08-19

## Place in the HMM Research Lineage

`LIT-REG-01.2` is a substantive variant of the stopped `LIT-REG-01.1`
Gaussian HMM exercise. It does not relax or overwrite that result.

`01.1` established correct likelihood, causal-filtering, deterministic, and
clear-state recovery mechanics, but its dependency-free optimizer produced a
valid selected fit in only 77 of 100 frozen synthetic cases. No market data
were read. `01.2` narrows the scientific target to persistent volatility
states, removes return direction and the H3 challenger, adds an independently
maintained numerical reference, and permits a formal no-regime abstention.

The separately bookmarked `LIT-REG-02.1` directional-state track is not opened
by this contract. No directional label, return-sign forecast, or strategy
calculation may enter `01.2`.

## Frozen Research Question

> On adjusted daily bars, can a two-state univariate Gaussian HMM fitted only
> on completed TRAIN observations produce causal next-session normalized-range
> density forecasts that add stable out-of-sample temporal information beyond
> a one-state Gaussian, a static two-component Gaussian mixture, and a
> continuous Gaussian AR(1) persistence model?

This asks whether Markov state memory earns its complexity in a volatility-
appropriate niche. It does not ask whether the next return is positive or
whether any strategy is profitable.

## Frozen Scope and Data Seal

- Development instrument: `SPY`.
- Frozen replication instruments, opened only if SPY Stage B passes:
  `QQQ`, `IWM`, `EFA`, and `TLT`.
- Provider: existing canonical Alpaca adjusted daily OHLCV only.
- Explicit as-of timestamp: `2026-08-18 17:30:00 America/New_York`.
- Requested history: `2016-01-04` through `2023-12-29`.
- `2024-01-02` onward remains sealed and must not be loaded, read, scored, or
  plotted.
- Model cadence: one expanding TRAIN fit per annual fold; parameters remain
  frozen through that fold's OOS year.
- Output cadence: causal after-close filtered probability and next-session
  predictive distribution.
- No strategy, return-direction target, PnL, Sharpe, drawdown, hit rate,
  entry, exit, allocation, leverage, live advice, or execution calculation.

If a requested cache range has a material coverage warning, refresh may extend
only through `2023-12-29`. Otherwise stop with the exact warning.

## Frozen Observation

For completed session `t`:

```text
TR_t  = max(H_t - L_t, abs(H_t - C_(t-1)), abs(L_t - C_(t-1)))
ntr_t = TR_t / C_t
y_t   = log(ntr_t)
```

Requirements:

- adjusted `O_t`, `H_t`, `L_t`, and `C_t` come from the same canonical row;
- prices are positive and finite with valid OHLC geometry;
- `TR_t > 0` and `ntr_t > 0`; no epsilon may repair an invalid bar;
- the first requested row supplies `C_(t-1)` and is not an observation; and
- no rolling ATR, return sign, return magnitude, volume, breadth, or external
  volatility series enters the model.

Within fold `f`, standardize using TRAIN only:

```text
x_t = (y_t - mean_train) / sd_train
```

The TRAIN mean and sample standard deviation remain frozen in OOS.

### Why single-session range

Volatility clustering supplies the substantive reason to test state memory.
Single-session normalized range is deliberately not a rolling statistic:
adjacent ATR values reuse underlying bars and could manufacture the apparent
persistence the transition matrix is supposed to earn.

## Frozen Development Folds

| Fold | TRAIN | OOS development |
|---|---|---|
| `F1` | 2016-01-04 through 2019-12-31 | 2020-01-02 through 2020-12-31 |
| `F2` | 2016-01-04 through 2020-12-31 | 2021-01-04 through 2021-12-31 |
| `F3` | 2016-01-04 through 2021-12-31 | 2022-01-03 through 2022-12-30 |
| `F4` | 2016-01-04 through 2022-12-30 | 2023-01-03 through 2023-12-29 |

For each fold, fit transformations and parameters on TRAIN only. Score each
OOS observation before using it to update the filtered state. Carry the final
TRAIN filtered probability and observed `x` into OOS where required. Never
refit parameters inside an OOS year.

The entire 2016-2023 surface is development evidence, not fresh confirmation.

## Frozen Model Registry

### B0 — One-state Gaussian

TRAIN mean and maximum-likelihood variance. This is the no-regime density
baseline.

### B1 — Static two-component Gaussian mixture

Two univariate Gaussian components fitted by deterministic multistart EM.
Mixture weights remain fixed OOS. This asks whether two marginal volatility
populations explain the data without Markov memory.

### B2 — Gaussian AR(1)

Fit by TRAIN OLS:

```text
x_t = alpha + phi * x_(t-1) + epsilon_t
```

Clamp `phi` to `[-0.99, 0.99]`, refit `alpha` conditional on the clamped value,
and estimate the Gaussian innovation standard deviation by maximum likelihood.
At every OOS close, the observed current `x_t` becomes the next prediction's
lag. This is the continuous-persistence baseline.

### H2 — Two-state Gaussian HMM

```text
S_t in {1,2}
Pr(S_t=j | S_(t-1)=i) = A_ij
x_t | S_t=k ~ Normal(mu_k, sigma_k^2)
```

H2 is the only candidate model. There is no H3 challenger in `01.2`.

## Frozen Numerical Authority

- Reference estimator: CRAN `HiddenMarkov` version `1.8-14`.
- Local installation: ignored `.codex_r_libs`; no package files enter git.
- Model object: univariate `dthmm`, Gaussian emissions, stationary initial
  distribution, Baum-Welch fitting.
- The package fit is the parameter-estimation authority.
- The explicit Gen5 forward recursion independently recomputes likelihoods,
  causal filtered probabilities, and OOS scores from the selected parameters.
- Any reference/Gen5 disagreement beyond a frozen tolerance is a numerical
  failure, not a near-pass.

The operator explicitly approved this dependency on 2026-08-19. Archived
`depmixS4` and the much larger `hmmTMB` dependency surface are not used.

## Frozen Estimation Discipline

For B1 and H2:

- 12 deterministic starts;
- seeds `62101:62112` for B1 and `62201:62212` for H2;
- seeded one-dimensional k-means initializes emission membership;
- H2 initial self-transition cycles through `0.80, 0.90, 0.95, 0.98`;
- the initial state distribution is stationary;
- emission standard deviations below `0.01` standardized units invalidate a
  fit rather than being floored after estimation;
- transition probabilities must be finite and strictly inside `(0,1)`;
- maximum 1,000 Baum-Welch iterations;
- convergence tolerance `1e-6` in absolute log likelihood;
- likelihood decreases are invalid;
- choose the valid converged start with greatest TRAIN likelihood; and
- record every start, initialization, convergence result, iteration count,
  likelihood, emission parameter, transition probability, and occupancy.

B0 and B2 have closed-form/OLS fits and no multistart search.

## Frozen Identification and Abstention Policy

A numerically valid H2 fit earns `VALID_TWO_STATE_MODEL` only when all hold:

1. both posterior expected TRAIN occupancies are at least 10%;
2. both self-transition probabilities exceed 0.50;
3. standardized emission separation is at least `0.75`:

```text
abs(mu_2 - mu_1) / sqrt((sigma_1^2 + sigma_2^2) / 2) >= 0.75
```

4. H2 TRAIN BIC is lower than both B0 and B1 TRAIN BIC; and
5. the selected package likelihood and Gen5 forward likelihood differ by no
   more than `1e-8` per observation.

A valid fit that misses any of conditions 1-4 becomes
`TWO_STATES_NOT_IDENTIFIABLE_USE_BASELINE`. This is an admissible statistical
abstention, not an optimizer error. Condition 5 failure or absence of any valid
selected fit becomes `NUMERICAL_FAILURE`.

State labels are assigned only after fitting by ordered TRAIN emission mean:

- lower expected `log(ntr)`: `CALMER_RANGE`;
- higher expected `log(ntr)`: `TURBULENT_RANGE`.

Directional labels are prohibited.

## Frozen Causal Forecasts and Targets

With filtered probability `q_(t|t)` after close `t`:

```text
q_(t+1|t) = A' q_(t|t)
```

The next observation's predictive density is the state-weighted Gaussian
mixture under `q_(t+1|t)`. The HMM log score must be recorded before observing
`x_(t+1)`.

Define the fold-specific high-range event threshold as the TRAIN 80th
percentile of `y`. Every model produces a causal probability that the next
session exceeds that fixed threshold. Report Brier score and calibration by
decile. This target concerns future volatility amplitude, never return sign.

Smoothed probabilities and Viterbi paths may appear only as separately labeled
`RETROSPECTIVE_HINDSIGHT_ONLY` diagnostics. They cannot enter any gate.

## Stage A — Reference, Engine, and Synthetic Qualification

No market-data function may be called until all eight gates pass. Freeze 20
strong, 20 weak, and 20 null simulations, each length 1,200, before execution.

| Gate | Frozen requirement |
|---:|---|
| A1 | `HiddenMarkov` 1.8-14 is available; package and Gen5 short-sequence likelihoods agree within `1e-10`; all probability and variance invariants pass. |
| A2 | Repeated package/Gen5 runs reproduce selected parameters, labels, likelihoods, and filtered probabilities within `1e-10`. |
| A3 | Appending observations changes no prior causal filtered probability by more than `1e-12`; smoothing is separately labeled and demonstrably may revise history. |
| A4 | All 20 strong cases avoid numerical failure; at least 18 receive `VALID_TWO_STATE_MODEL`; median filtered state accuracy is at least 90% and the tenth percentile at least 85%. |
| A5 | On strong cases, median maximum absolute transition error is at most 0.05 and the ninetieth percentile at most 0.10. |
| A6 | At least 14 of 20 weak cases abstain; weak-case mean posterior entropy exceeds strong-case entropy and mean maximum confidence is at least 0.10 lower. |
| A7 | At least 18 of 20 null one-state cases abstain and no more than two are promoted as two-state models. |
| A8 | Every one of the 60 cases ends as `VALID_TWO_STATE_MODEL` or `TWO_STATES_NOT_IDENTIFIABLE_USE_BASELINE`; there are zero numerical failures, unclassified cases, invalid probabilities, or invalid variances. |

The strong fixtures use persistent, clearly separated Gaussian states. Weak
fixtures use the same persistent chain with strongly overlapping emissions.
Null fixtures are one-state iid Gaussian observations. Exact parameters,
seeds, and expected labels must be committed before Stage A runs.

Any Stage A failure stops before adjusted daily bars are queried.

## Stage B — SPY Descriptive-Promotion Gates

Run only if all Stage A gates pass. H2 earns SPY descriptive promotion only if
all nine gates pass.

| Gate | Frozen requirement |
|---:|---|
| B1 | SPY coverage, OHLC integrity, boundaries, TRAIN-only transformations, unique dates, causal scoring, and the 2024+ seal all pass. |
| B2 | Every fold has zero numerical failures and package/Gen5 likelihood agreement within `1e-8` per TRAIN observation. |
| B3 | Every fold returns `VALID_TWO_STATE_MODEL`; no fold abstains. |
| B4 | Aggregate mean H2 OOS log score exceeds both B1 and B2, and H2 beats each comparator in at least three of four OOS years. |
| B5 | Separate 95% moving-block-bootstrap lower bounds for mean `H2-B1` and `H2-B2` OOS log score are strictly positive. |
| B6 | Actual H2 temporal ordering ranks at or above the 90th percentile of 200 whole-20-session-block order controls relative to both B1 and B2. |
| B7 | H2 aggregate high-range-event Brier score is lower than both B1 and B2 and is lower than each in at least three of four years. |
| B8 | Both states occur in every fold; aggregate expected occupancy is 10%-90%; hard occupancy is at least 5% per fold; at least 20 aggregate completed switches occur; and median completed duration is 2-126 sessions. |
| B9 | Across adjacent expanding refits, common trailing-252-session hard-state agreement is at least 70% and `TURBULENT_RANGE` filtered-probability correlation is at least 0.70. |

Moving-block uncertainty uses 20-session blocks, 2,000 replicates, seed
`62301`, and never crosses OOS-year boundaries. Temporal-order controls use
200 whole-block permutations with seed `62302`, preserve within-block order,
and restart each OOS year from the same last-TRAIN filtered probability.

## Stage C — Frozen Cross-Asset Replication

Run only if all SPY Stage B gates pass. Apply the unchanged observation,
models, identification policy, folds, thresholds, and causal scoring to QQQ,
IWM, EFA, and TLT independently.

Replication promotion requires all of:

1. at least three of four instruments return `VALID_TWO_STATE_MODEL` in all
   four folds;
2. at least three instruments have positive aggregate mean H2-minus-B1 and
   H2-minus-B2 OOS log score;
3. pooled equal-instrument H2 log score exceeds both comparators with separate
   positive 95% block-bootstrap lower bounds; and
4. the higher-mean state remains `TURBULENT_RANGE` by realized OOS normalized
   range in every valid instrument/fold.

Failure records useful SPY-only or instrument-specific evidence but does not
open a generic asset-level regime-filter claim.

## Required Evidence

- immutable contract, model registry, package/version ledger, and run spec;
- Stage A fixtures and complete fit/abstention diagnostics;
- package-versus-Gen5 likelihood and probability comparisons;
- daily causal priors, filtered probabilities, predictive log scores, and
  high-range probabilities for every executed market fold;
- bootstrap and temporal-order-control distributions;
- state parameters, occupancy, durations, switches, and refit stability;
- representative causal transition tapes;
- focused charts for predictive scores, calibration, state probabilities,
  transition behavior, and abstention diagnostics;
- beginner-accessible PowerPoint with formulae and page/section-grounded
  speaker-note references; and
- explicit Stage A, Stage B, Stage C, and final verdict tables.

## Verdict Vocabulary

- Any Stage A failure:
  `STOP_LIT_REG_01_2_REFERENCE_OR_SYNTHETIC_GATES_FAILED_MARKET_DATA_NOT_READ`.
- Stage A passes but B1/B2 fails:
  `STOP_LIT_REG_01_2_REAL_DATA_INTEGRITY_OR_NUMERICAL_FAILURE`.
- B3 fails:
  `STOP_LIT_REG_01_2_TWO_STATES_NOT_IDENTIFIABLE_ON_SPY`.
- B4-B7 fails:
  `STOP_LIT_REG_01_2_NO_INCREMENTAL_VOLATILITY_FORECAST_VALUE`.
- B8/B9 fails:
  `STOP_LIT_REG_01_2_STATE_USABILITY_OR_STABILITY_FAILED`.
- Stage B passes but Stage C fails:
  `SPY_DESCRIPTIVE_ONLY_LIT_REG_01_2_CROSS_ASSET_REPLICATION_FAILED`.
- All stages pass:
  `DESCRIPTIVE_PROMOTION_LIT_REG_01_2_STRATEGY_DISCUSSION_OPEN`.

A passing result opens only discussion of a separately frozen strategy-
relative test. It does not authorize strategy outcomes, 2024+ confirmation,
allocation, leverage, live advice, or execution.

## No-Rescue Rules

After a stage's outcomes are read, do not change its instruments, observation,
folds, reference package/version, state count, emission family, starts, seeds,
abstention policy, baselines, high-range threshold, bootstrap, temporal-order
control, or gates. Do not add rolling ATR, returns, VIX, breadth, or a strategy
to rescue the result.

A directional HMM, Student-t HMM, autoregressive-emission HMM, hidden
semi-Markov model, Markov-switching GARCH model, cross-sectional HMM, or
strategy overlay requires a separately discussed and frozen concept or
substantive variant.
