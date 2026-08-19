# LIT-REG-01.1 Two-State Hidden Markov Regime POC Contract

Status: `STOP_LIT_REG_01_1_ENGINE_OR_SYNTHETIC_GATES_FAILED_REAL_DATA_NOT_READ`

Date frozen: 2026-08-19

## Place in the Literature-Study Progression

`LIT-REG-01.1` opens the first regime-model family in Literature-Grounded
Strategy Research. Rabiner (1989) and Zucchini, MacDonald, and Langrock (2016)
anchor the HMM mechanics; Hamilton (1989) and Ang and Timmermann (2012) anchor
the financial-regime interpretation; Pohle et al. (2017) anchor the
state-count discipline.

This is a descriptive state-model POC. It does not rescue the stopped T1-T5
SMA8/SMA14 overlays, authorize a trading strategy, or claim that a latent
state is a true economic regime.

## Frozen Research Question

> On SPY adjusted daily bars, can a two-state finite Gaussian HMM fitted only
> on completed TRAIN observations produce causal filtered state probabilities
> that add stable out-of-sample temporal structure beyond both a one-state
> Gaussian distribution and a two-component static Gaussian mixture?

## Frozen Scope

- Context instrument: `SPY` only.
- Provider surface: existing canonical Alpaca adjusted daily OHLCV cache.
- Explicit as-of timestamp for any bounded query:
  `2026-08-18 17:30:00 America/New_York`.
- Requested history: `2016-01-04` through `2023-12-29`.
- `2024-01-02` onward remains sealed and must not be loaded, read, scored, or
  plotted by this POC.
- Model cadence: one expanding TRAIN fit per annual fold; parameters remain
  frozen throughout that fold's OOS year.
- Output cadence: after-close state probabilities only.
- No strategy, PnL, Sharpe, drawdown, hit rate, entry, exit, allocation,
  leverage, live advice, or execution calculation.

No provider expansion or new market-data dependency is authorized. If the
existing cache reports a material coverage warning, refresh may extend only
through `2023-12-29`; otherwise stop with the exact warning.

## Frozen Observations

For completed session `t`:

```text
r_t   = log(C_t / C_(t-1))
TR_t  = max(H_t - L_t, abs(H_t - C_(t-1)), abs(L_t - C_(t-1)))
ntr_t = TR_t / C_t
z_t   = [r_t, log(ntr_t)]
```

Requirements:

- `O_t`, `H_t`, `L_t`, and `C_t` are adjusted values from the same canonical
  bar row.
- Require positive finite prices, `H_t >= max(O_t,C_t,L_t)`, and
  `L_t <= min(O_t,C_t,H_t)`.
- Require `TR_t > 0` and `ntr_t > 0`; do not add an arbitrary epsilon to make
  invalid bars usable.
- The first requested row exists only to supply `C_(t-1)` and is not itself an
  observation.

Within fold `f`, standardize each column using only that fold's TRAIN sample
mean and sample standard deviation:

```text
x_(t,j) = (z_(t,j) - mean_train_j) / sd_train_j
```

Both TRAIN standard deviations must be positive and finite. The TRAIN means
and standard deviations are frozen for that fold's OOS transformation.

### Why normalized true range, not ATR%, is primary

ATR(14) is already a rolling persistent statistic. Adjacent values share
thirteen underlying bars, so an HMM could inherit apparent persistence from
the feature construction. Daily normalized true range supplies one current
amplitude observation and forces the transition model to earn persistence.
The accepted ATR% sensor is not joined in this POC.

## Frozen Development Folds

| Fold | TRAIN | OOS development |
|---|---|---|
| `F1` | 2016-01-04 through 2019-12-31 | 2020-01-02 through 2020-12-31 |
| `F2` | 2016-01-04 through 2020-12-31 | 2021-01-04 through 2021-12-31 |
| `F3` | 2016-01-04 through 2021-12-31 | 2022-01-03 through 2022-12-30 |
| `F4` | 2016-01-04 through 2022-12-30 | 2023-01-03 through 2023-12-29 |

For each fold:

1. fit the transformation and model parameters on TRAIN only;
2. carry the last TRAIN filtered state probability into OOS;
3. before observing OOS `x_t`, calculate its predictive density from the
   prior state probability;
4. after scoring, update the filtered probability with `x_t`;
5. never refit parameters inside the OOS year.

The full 2016-2023 surface is reused development evidence. It is not fresh
confirmation.

## Frozen Model Registry

### B0 — One-state Gaussian

Fit one bivariate Gaussian distribution by TRAIN maximum likelihood. This is
the no-regime density baseline.

### B1 — Two-component static Gaussian mixture

Fit two full-covariance Gaussian components by EM. Mixture weights are fixed
through OOS and do not depend on the preceding observation. This is the
required fat-tail/clustering baseline.

### H2 — Two-state Gaussian HMM

This is the primary model:

```text
S_t in {1,2}
pi_k = Pr(S_1 = k)
A_ij = Pr(S_t = j | S_(t-1) = i)
x_t | S_t=k ~ N(mu_k, Sigma_k)
```

H2 alone can earn descriptive promotion.

### H3 — Three-state Gaussian HMM

H3 is a diagnostic challenger. It cannot stop an otherwise passing H2, and it
cannot replace H2 merely through TRAIN likelihood, AIC, or BIC. It is retained
only if it passes the separate H3 complexity gate below.

## Frozen State Identity

After each TRAIN fit, permute the complete fitted parameter set according to
TRAIN emission mean `log(ntr)` in original units:

- H2 lower expected log normalized range: `CALMER`;
- H2 higher expected log normalized range: `TURBULENT`;
- H3 ordered labels: `LOWER_RANGE`, `MIDDLE_RANGE`, `HIGHER_RANGE`.

Apply the same permutation to emissions, `pi`, transition-matrix rows and
columns, and every probability column. State-conditional return means are
reported with uncertainty but never determine identity. `Bull`, `bear`,
`risk-on`, and `risk-off` labels are prohibited.

The hard state used in occupancy and tapes is the maximum filtered
probability, with an exact tie broken toward the lower-range state. The full
probability vector remains authoritative.

## Frozen Causal Inference

Let `q_(t-1|t-1)` be the filtered column vector after the preceding close:

```text
q_(t|t-1) = A' q_(t-1|t-1)

p(x_t | information through t-1)
  = sum_k q_(t|t-1,k) * phi(x_t; mu_k, Sigma_k)

q_(t|t,k) proportional to
  q_(t|t-1,k) * phi(x_t; mu_k, Sigma_k)
```

Scale or log-space the recursion to avoid underflow. Every probability vector
must be finite, nonnegative, and sum to one within `1e-12`.

Smoothed probabilities and Viterbi paths may be computed only after the causal
ledger is complete. They must carry `RETROSPECTIVE_HINDSIGHT_ONLY` labels and
must never enter a gate, OOS predictive score, or future strategy interface.

## Frozen Estimation Discipline

Implement explicit, testable mechanics without adding a package dependency.
Any later dependency proposal requires separate operator approval.

For B1, H2, and H3 in every fold:

- use 20 deterministic initializations;
- initialization seeds are `61001:61020` for B1/H2 and `63001:63020` for H3;
- initialize emission membership from seeded TRAIN k-means centers;
- initialize B1 mixture weights from the seeded cluster proportions;
- for H2/H3, cycle initial self-transition probabilities through
  `0.80, 0.90, 0.95, 0.98`, distributing the remaining probability equally
  across other states;
- for H2/H3, initialize `pi` from the transition matrix's stationary
  distribution;
- update full covariance matrices with a minimum eigenvalue floor of `1e-4`
  in TRAIN-standardized units;
- clamp fitted mixture and transition probabilities to
  `[1e-6, 1 - 1e-6]` before renormalization;
- allow at most 1,000 EM iterations;
- declare convergence after absolute log-likelihood improvement per TRAIN
  observation is below `1e-8` for five consecutive iterations;
- reject any iteration whose likelihood decreases by more than `1e-8` per
  observation;
- choose the valid converged fit with greatest TRAIN likelihood only.

Record all initialization seeds, convergence codes, iterations, likelihoods,
covariance eigenvalues, posterior occupancies, and selected fit IDs.

## Frozen Scores and Controls

### Sequential OOS log score

For each OOS observation, record the log predictive density available before
observing it. Define:

```text
d_t = log_score_H2_t - log_score_B1_t
```

Report fold and aggregate means and sums for every model. B1's mixture weights
remain fixed, whereas H2's predictive weights evolve causally.

### Moving-block uncertainty

- Statistic: aggregate mean `d_t`.
- Resample within each OOS year so fold boundaries are never crossed.
- Moving-block length: 20 sessions.
- Replicates: 2,000.
- Seed: `61201`.
- Interval: percentile 95% confidence interval.

### Temporal-order control

Within each OOS year, divide observations into consecutive 20-session blocks,
leaving the final shorter block intact. Generate 200 deterministic
permutations of whole-block order using seed `61202`. For every permutation:

- begin from the same last-TRAIN filtered probability as the actual OOS year;
- retain within-block observation order;
- score H2 sequentially without parameter refitting;
- subtract the order-invariant B1 log score.

Report the percentile rank of the actual aggregate H2-minus-B1 score among
the 200 controls plus actual.

## Stage A — Engine and Synthetic Gates

All eight gates must pass before reading the real-data model comparison.

| Gate | Frozen requirement |
|---:|---|
| A1 | B0, B1, H2, and H3 density, probability, covariance, and transition invariants pass; short sequences of length at most eight match brute-force likelihood enumeration within `1e-10`. |
| A2 | Repeated runs with the frozen seeds reproduce selected parameters, probabilities, labels, and likelihoods within `1e-12`. |
| A3 | Appending observations changes no prior H2 filtered probability by more than `1e-12`; smoothing is separately labeled and demonstrably may revise history. |
| A4 | Across 50 frozen strong-separation simulations of length 1,500, after label matching, median filtered classification accuracy is at least 90% and the tenth percentile is at least 85%. |
| A5 | Across the same simulations, median maximum absolute transition-probability error is at most 0.03 and the ninetieth percentile is at most 0.08. |
| A6 | Across 50 frozen weak-separation simulations, mean posterior entropy exceeds the strong-separation mean and mean maximum posterior confidence is at least 0.10 lower; the engine must express uncertainty rather than force confident labels. |
| A7 | Synthetic state ordering, expected-duration calculation, and permutation of `pi`, `A`, emissions, and probabilities are exact; implied-duration relative error is at most 25% at the simulation median. |
| A8 | No synthetic fit has a non-finite likelihood, non-positive-definite covariance after flooring, invalid probability vector, or unreported convergence failure. |

Synthetic fixtures, parameters, seeds, and expected assertions must be
committed before the real-data runner is executed.

## Stage B — Real-Data H2 Promotion Gates

H2 earns descriptive promotion only if all nine gates pass.

| Gate | Frozen requirement |
|---:|---|
| B1 | SPY coverage, OHLC integrity, fold boundaries, TRAIN-only transformations, unique dates, and causal scoring all pass; zero 2024+ observations are read. |
| B2 | Every fold has a valid converged H2 fit; all covariance eigenvalues are in `[1e-4, 100]`; no TRAIN posterior expected state occupancy is below 5%; at least 5 of 20 starts finish within `1e-4` log-likelihood per TRAIN observation of the selected optimum. |
| B3 | Aggregate mean OOS H2 log score exceeds both B0 and B1, and H2 exceeds B1 in at least three of the four OOS years. |
| B4 | The 95% moving-block-bootstrap lower bound for aggregate mean `H2 - B1` daily log score is strictly positive. |
| B5 | Actual temporal ordering ranks at or above the 90th percentile of the 200 whole-block permutation controls. |
| B6 | Each H2 state has aggregate posterior expected OOS occupancy between 10% and 90%, hard filtered occupancy of at least 5% in every OOS fold, and appears in all four folds. |
| B7 | There are at least 20 aggregate completed hard-state switches, at least two in each OOS year, and aggregate median completed run duration is between 2 and 126 sessions. |
| B8 | Both TRAIN self-transition probabilities exceed 0.50 in every fold; `TURBULENT` has higher posterior-weighted OOS mean log normalized range in every fold and higher return variance in at least three of four folds. |
| B9 | Across each of the three adjacent expanding refits, hard-state agreement on their common trailing 252 TRAIN observations is at least 70% and Pearson correlation of `TURBULENT` filtered probability is at least 0.70 after frozen label matching. |

Gate passage is conjunctive. No weighted score or near-pass can override a
failure.

## Separate H3 Complexity Gate

H3 is retained as meaningful evidence only if all conditions hold:

1. every fold satisfies B2's numerical and replicated-optimum requirements;
2. every state has at least 10% aggregate posterior expected OOS occupancy,
   at least 5% hard occupancy in every fold, and at least five completed
   aggregate entries;
3. ordered emission semantics remain distinct in every fold;
4. H3 exceeds H2 OOS sequential log score in at least three of four years;
5. the 95% moving-block-bootstrap lower bound for `H3 - H2` is positive;
6. actual H3 ordering ranks at or above the 90th percentile of its temporal
   controls; and
7. adjacent-refit hard-state agreement after ordered label matching is at
   least 60% for all three comparisons.

If any condition fails, record `H3_NOT_JUSTIFIED_RETAIN_H2_PRIMARY`. H3 failure
does not cause H2 to fail.

## Required Evidence Packet

- explicit run specification and data-health report;
- frozen model registry and transformation ledger;
- all initialization and convergence diagnostics;
- synthetic fixture definitions, recovery table, and visuals;
- one row per session with causal prior and filtered probabilities;
- separately labeled smoothed/Viterbi diagnostic ledger;
- B0/B1/H2/H3 fold and daily predictive log scores;
- block-bootstrap draws and interval;
- temporal-order control distribution;
- fold emissions, covariance matrices, transition matrices, stationary
  probabilities, and implied durations;
- occupancy, hard-run, switch, and refit-stability tables;
- representative causal transition tapes;
- SPY price/probability, emission scatter, filtered-versus-smoothed, and
  stability visuals;
- a beginner-accessible PowerPoint with formulae and source references in
  speaker notes; and
- an immutable Stage A, Stage B, H3, and final verdict table.

## Verdict Vocabulary

- Any Stage A failure:
  `STOP_LIT_REG_01_1_ENGINE_OR_SYNTHETIC_GATES_FAILED_REAL_DATA_NOT_READ`.
- Stage A passes but any B1/B2 integrity or numerical gate fails:
  `STOP_LIT_REG_01_1_REAL_DATA_INTEGRITY_OR_FIT_FAILED`.
- B3, B4, or B5 fails:
  `STOP_LIT_REG_01_1_NO_INCREMENTAL_TEMPORAL_VALUE`.
- B6, B7, B8, or B9 fails:
  `STOP_LIT_REG_01_1_STATE_USABILITY_OR_STABILITY_FAILED`.
- All H2 gates pass:
  `DESCRIPTIVE_PROMOTION_LIT_REG_01_1_STRATEGY_DISCUSSION_OPEN`.

A passing H2 opens only discussion of a separately frozen strategy-relative
POC. It does not open 2024+, strategy calculations, allocation, leverage,
live advice, or execution.

## No-Rescue Rules

After any real-data outcome is read, do not change:

- SPY or add QQQ/other assets;
- the two observations or their transformations;
- Gaussian full-covariance emissions;
- state counts, labels, or primary/challenger roles;
- fold dates or annual refit cadence;
- initialization count/seeds, covariance floor, or convergence rules;
- bootstrap/permutation design;
- gate thresholds; or
- the 2024+ seal.

A return-only HMM, Student-t emission model, cross-sectional context HMM,
asset-specific HMM, time-varying transition model, hidden semi-Markov model,
or strategy overlay requires a new literature-grounded concept or substantive
variant with its own ex ante contract.

## Current Stop State

Implementation was approved and Stage A was executed on 2026-08-19. Gates A1
through A7 passed, but A8 failed because only 77 of 100 synthetic fits were
valid under the frozen numerical rules. The real SPY comparison was not read.

See
[GEN5_LIT_REG_01_1_HMM_STAGE_A_RESULTS.md](GEN5_LIT_REG_01_1_HMM_STAGE_A_RESULTS.md).
The frozen verdict is
`STOP_LIT_REG_01_1_ENGINE_OR_SYNTHETIC_GATES_FAILED_REAL_DATA_NOT_READ`.
