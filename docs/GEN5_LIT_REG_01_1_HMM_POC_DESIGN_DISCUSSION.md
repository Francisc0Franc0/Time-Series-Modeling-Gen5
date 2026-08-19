# LIT-REG-01.1 Hidden Markov Regime POC Design Discussion

Status: `APPROVED_SUPERSEDED_BY_FROZEN_CONTRACT`

Date: 2026-08-18

## Where This Fits

This is the design gate for the first Hidden Markov Model exercise following
the closed T1-T5 trend-indicator series. It is a literature-grounded regime
measurement question, not a rescue of the stopped SMA8/SMA14 overlays and not
yet a strategy.

The proposed identifier is `LIT-REG-01.1`:

- `LIT` because Rabiner, Zucchini et al., Hamilton, Ang--Timmermann, and Pohle
  et al. supply the primary intellectual lineage;
- `REG` because the object is a descriptive latent regime model rather than a
  mean-reversion or momentum strategy;
- `01.1` because this would be the first frozen concept in that family.

If approved, implementation should live under `literature_studies/`. This
document does not yet change the frozen literature registry.

## Recommended Minimal Question

> On SPY adjusted daily bars, can a two-state finite Gaussian HMM fitted only
> on completed TRAIN observations produce causal filtered state probabilities
> that add stable, out-of-sample temporal structure beyond both a one-state
> distribution and a two-component static mixture?

This is deliberately a density/state question, not a return or trading claim.

## Why SPY First

Use one market-level context series for the canonical POC:

- one latent state timeline is much easier to inspect than 24-26 separately
  fitted stock models;
- SPY has deep adjusted-daily coverage in the existing Alpaca cache;
- it avoids pretending that hundreds of asset-days are independent state
  transitions;
- it provides a plausible future context variable for multiple traded assets
  without granting it trading authority now;
- QQQ can later serve as one fixed replication rather than a winner-selected
  alternative if the SPY construction passes.

This does not assert that SPY's state is sufficient for AMD, TSLA, or another
asset. Asset-specific and cross-sectional models remain later, separate
questions.

## Recommended Observations

For each completed session `t`, define:

```text
r_t   = log(C_t / C_(t-1))
TR_t  = max(H_t - L_t, |H_t - C_(t-1)|, |L_t - C_(t-1)|)
ntr_t = TR_t / C_t
x_t   = [r_t, log(ntr_t)]
```

Both columns are standardized with TRAIN-only means and standard deviations.
The fitted TRAIN transformation is frozen for the corresponding OOS fold.

### Why not ATR% as the first HMM input?

ATR% is accepted and useful, but ATR(14) is already a persistent rolling
summary. Feeding it into an HMM risks manufacturing long state runs partly
because adjacent inputs share thirteen observations. Daily normalized true
range supplies the current amplitude observation; the HMM transition matrix
must then earn the persistence.

### Why include return?

Normalized true range is unsigned. Daily log return supplies direction and
close-to-close displacement. Its state-conditional mean may be reported, but
the state must not be named or selected according to future profit.

## Model Family

Let the hidden state be `S_t in {1, 2}`. The model contains:

```text
initial probabilities: pi_k = Pr(S_1 = k)
transition matrix:      A_ij = Pr(S_t = j | S_(t-1) = i)
emission model:         x_t | S_t=k ~ N(mu_k, Sigma_k)
```

The primary model uses full two-dimensional covariance matrices. Covariances
must remain positive definite and bounded away from singularity.

### Causal filtering

At the end of session `t`:

```text
prior state probability:     q_(t|t-1) = A' q_(t-1|t-1)
filtered state probability:  q_(t|t) proportional to
                              emission_density(x_t) * q_(t|t-1)
```

`q_(t|t)` may describe the state known after today's close. `A' q_(t|t)` is
the next-session state forecast. Any future strategy could use only one of
these causal objects with a next-open delay.

Smoothed probabilities and a Viterbi path use later observations to revise
historical states. They are permitted only as visibly labeled retrospective
diagnostics.

## Baselines Needed to Interpret an HMM

### B0 — One-state Gaussian

One bivariate Gaussian distribution fitted on TRAIN. This asks whether any
distributional segmentation is useful.

### B1 — Two-component static Gaussian mixture

The same two Gaussian components but no transition dependence. Every date has
the same mixture weights. This is the critical baseline: it asks whether the
HMM learns temporal persistence or merely uses two components to approximate
fat tails and heteroskedastic observations.

### H2 — Two-state Gaussian HMM

The primary model. Its OOS predictive density uses the filtered state
probability and the frozen transition matrix.

### H3 — Three-state Gaussian HMM, diagnostic challenger only

Fit and report a three-state challenger under the same data and controls. It
cannot win merely because AIC, BIC, or TRAIN likelihood is better. The extra
state must be populated, recurrent, emission-distinct, stable across folds,
and incrementally better on held-out predictive evidence. Otherwise retain
two states.

No state count is selected from strategy returns.

## Proposed Development Folds

Reuse the already opened daily development history and keep 2024+ sealed:

| Fold | Expanding TRAIN | OOS development |
|---|---|---|
| F1 | 2016-2019 | 2020 |
| F2 | 2016-2020 | 2021 |
| F3 | 2016-2021 | 2022 |
| F4 | 2016-2022 | 2023 |

At each fold:

1. fit transformations and all model parameters on TRAIN only;
2. carry the final TRAIN filtered probability into OOS;
3. hold parameters fixed for the full OOS year;
4. update only the filtered state probability as each completed OOS bar
   arrives;
5. score the next OOS observation from the probability distribution available
   before observing it.

The annual refit cadence is a proposed audit-friendly compromise, not yet a
claim that annual refitting is optimal.

## State Identity

For the two-state model, labels are assigned after fitting by the TRAIN
emission distributions:

- `CALMER`: lower TRAIN expected `log(ntr)`;
- `TURBULENT`: higher TRAIN expected `log(ntr)`.

The labels are descriptive. State-conditional return means are reported with
uncertainty but do not determine the label. The full component ordering is
applied consistently to the initial probabilities, transition matrix,
emissions, and filtered probability columns.

The three-state challenger, if retained for inspection, is ordered by TRAIN
expected `log(ntr)` as `LOWER_RANGE`, `MIDDLE_RANGE`, and `HIGHER_RANGE`.
Names such as `bull`, `bear`, `risk-on`, or `risk-off` are prohibited unless a
future contract supplies separate, stable evidence for those semantics.

## Fitting Discipline

- Use multiple deterministic initializations; the proposal is 20.
- Keep every initialization's convergence code and TRAIN likelihood.
- Select the converged fit with the greatest TRAIN likelihood, never an OOS
  or strategy outcome.
- Report whether materially different local solutions remain competitive.
- Reject singular covariance, near-zero occupancy, non-finite likelihood, or
  transition matrices on the numerical boundary.
- Use log-space or scaled forward recursion to avoid underflow.
- Prefer explicit, testable base-R mechanics unless a separately approved
  package dependency clearly earns its keep.

## Proposed Stage A — Construction and Synthetic Recovery

1. exact probability normalization and transition-matrix invariants;
2. scale/transform determinism under the frozen TRAIN standardization;
3. exact append causality for historical filtered probabilities;
4. synthetic separable-state recovery after label matching;
5. synthetic weak-separation behavior that remains uncertain rather than
   fabricating confident labels;
6. recovery of known transition ordering and approximate expected duration;
7. deterministic multi-start results;
8. explicit divergence between causal filtered and hindsight-smoothed states
   around synthetic transitions.

Failure stops before reading real-data model comparisons.

## Proposed Stage B — Real-Data Model Evidence

The exact quantitative thresholds remain to be frozen, but the gates should
cover all of the following:

1. **Integrity:** SPY coverage is complete for every fold, TRAIN transforms
   are causal, and 2024+ is absent.
2. **Numerics:** every primary fold has a valid converged H2 fit, no singular
   covariance, and no effectively empty state.
3. **Temporal value:** aggregate OOS sequential log score for H2 exceeds B1,
   not merely B0.
4. **Breadth over time:** H2 beats B1 in at least three of four OOS years; do
   not let one crisis year own the conclusion.
5. **Uncertainty:** a paired moving-block bootstrap of daily H2-minus-B1 log
   scores has a positive lower confidence bound, or the result remains
   inconclusive.
6. **State usability:** both states have material occupancy, recur, and
   generate enough transitions to audit; one COVID-only state is not a
   reusable regime.
7. **Emission semantics:** `CALMER` versus `TURBULENT` ordering and basic
   distributional separation are stable across all folds.
8. **Refit stability:** state identity, transition behavior, and emission
   parameters do not reorder or change implausibly from one expanding fit to
   the next.
9. **Complexity control:** H3 is retained only if its third state is meaningful
   under Pohle-style inspection and improves held-out evidence beyond H2.

No return, Sharpe, PnL, drawdown, hit rate, strategy entry, exit, or allocation
gate belongs in Stage B.

## What Passing Would and Would Not Mean

Passing would mean:

- a small latent-state model captured stable temporal distribution structure;
- filtered probabilities were causally reproducible;
- the transition mechanism added held-out information beyond static
  clustering;
- the model earned a later discussion about a strategy-relative POC.

Passing would not mean:

- the states are the market's true regimes;
- the model predicts return direction profitably;
- `TURBULENT` should be traded, avoided, or shorted;
- the state applies equally to every stock;
- the model is ready for 2024+, live advice, allocation, or leverage.

## Operator-Facing Evidence

The POC should produce:

- a beginner-accessible slide deck with formulas and source-grounded notes;
- SPY price with causal filtered state-probability bands;
- a separate filtered-versus-smoothed hindsight comparison;
- a two-feature emission scatter with state contours;
- per-fold transition matrices and implied expected durations;
- probability and hard-label tapes around representative transitions;
- OOS sequential log-score comparison for B0, B1, H2, and diagnostic H3;
- occupancy, run, transition, optimizer, and state-stability tables;
- synthetic recovery visuals;
- a concise machine-readable model and gate registry.

## Two Serious Alternatives

### Alternative A — Pure textbook univariate return HMM

Fit the same one-, two-, and three-state sequence models using only daily log
return. This is the cleanest Rabiner/Hamilton-style exercise and easiest to
implement. Its limitation is substantive: a Gaussian HMM may mostly separate
ordinary observations from high-variance tails, offering little beyond a
volatility model. Keep it as a possible canonical teaching example, not the
recommended main POC.

### Alternative B — Shared cross-sectional market-context HMM

Fit one HMM to a small synchronized market panel such as SPY/QQQ/IWM returns,
ranges, and perhaps breadth. This could better represent systemic participation
and eventually route stock strategies. It is not minimal: feature redundancy,
cross-asset covariance, breadth construction, missingness, and state meaning
would all change simultaneously. Defer it until a two-observation SPY model
demonstrates stable causal mechanics.

Asset-specific HMMs for AMD, TSLA, or a 24-stock atlas are also deferred. They
would answer a different question and multiply state-matching and effective
sample-size problems before the canonical mechanics are trusted.

## Decisions Required Before Freeze

1. Accept or reject the proposed `LIT-REG-01.1` placement and identifier.
2. Accept SPY as the canonical context series, with QQQ reserved as one fixed
   later replication rather than searched now.
3. Accept `[log return, log normalized true range]` as the two observations.
4. Accept H2 as primary, B0/B1 as required baselines, and H3 as a diagnostic
   challenger subject to meaning/stability rather than information criteria
   alone.
5. Accept the four expanding 2020-2023 OOS development folds and continued
   2024+ seal.
6. Decide exact numerical promotion thresholds in a subsequent frozen
   contract before implementation.

## Current Stop State

The operator approved the six principal design choices. The exact mechanics
and quantitative gates are now frozen in
[GEN5_LIT_REG_01_1_HMM_REGIME_POC_CONTRACT.md](../literature_studies/docs/GEN5_LIT_REG_01_1_HMM_REGIME_POC_CONTRACT.md).
Implementation remains unopened pending a separate explicit approval.
