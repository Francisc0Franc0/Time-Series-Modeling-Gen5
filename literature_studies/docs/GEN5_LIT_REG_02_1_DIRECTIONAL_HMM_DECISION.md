# LIT-REG-02.1 Directional HMM Decision

Status: `APPROVED_SUPERSEDED_BY_FROZEN_CONTRACT`

Date: 2026-08-19

## Decision in Plain Language

The first two HMM exercises did not reject a directional HMM. `LIT-REG-01.1`
stopped during synthetic engine qualification before market data were read.
`LIT-REG-01.2` intentionally removed direction and stopped because weak and
null volatility simulations too often ended as numerical failures rather than
valid abstentions.

The operator approved a separate direction-first lane because it is the most
interesting current learning question. The lane will first demonstrate a
known directional latent process, map the boundary where that process becomes
undetectable, and stress it with financial-shaped noise. It will not start by
searching market assets for an attractive chart.

## Why the Earlier Qualification Blocked Progress

The previous Stage A combined two different milestones:

1. recover a clear hidden process when one truly exists; and
2. reliably decide whether weak or absent structure warrants a two-state model.

Clear-state recovery succeeded. Weak/null classification and numerical
reliability did not. That production-quality conjunction was defensible, but
it prevented a student-style proof of mechanism from proceeding. `02.1`
therefore keeps null and weak cases visible while separating positive-control
qualification from detection-boundary characterization.

## Why Direction Is Harder Than Volatility

Daily drift is normally small relative to daily noise. If a true favorable
state has mean daily return `0.05%` and standard deviation `1.20%`, even an
oracle that knows the state has only about a `51.7%` chance of predicting a
positive next day under a Gaussian approximation. If the state persists for
20 sessions, the cumulative direction is more detectable, which motivates a
swing-horizon target rather than colored one-day calls.

An HMM can also infer the present state well yet forecast direction poorly.
State recovery, forward-probability calibration, and strategy value are three
different questions and must remain separate.

## Candidate Paths Considered

| Path | Serious use | Why not primary now |
|---|---|---|
| Two-state Gaussian return HMM | Smallest direction-varying emission model | Ignores within-state return dependence |
| Two-state Markov-switching AR(1) | State-dependent drift, persistence/reversal, and variance | Selected: closest match to the directional question |
| Bernoulli HMM on return signs | Directly models up/down observations | Discards magnitude and leaves daily sign very noisy |
| Hidden semi-Markov direction model | Explicit non-geometric regime durations | Duration complexity is premature before a basic mechanism works |
| Time-varying transition HMM | Breadth, volatility, or macro variables can change switch odds | Opens feature selection and transition-covariate scope too early |
| Cross-sectional/shared-state HMM | Infers a common state from many assets | Requires a materially more complex dependence model |
| Asset-specific atlas | Tests transport across assets | Valuable only after one fixed mechanism is qualified |
| Bayesian HMM | Priors and posterior parameter uncertainty | Heavier computation and prior judgment do not solve a vague target |

## Selected Model and Target

The selected candidate is a two-state Markov-switching Gaussian AR(1):

```text
r_t = alpha[S_t] + phi[S_t] * r_(t-1) + sigma[S_t] * epsilon_t
Pr(S_t = j | S_(t-1) = i) = A[i,j]
```

The model is fitted with CRAN `hmmTMB` `1.1.2`, using its documented
autoregressive-HMM formulation and TMB maximum likelihood. A small explicit
Gen5 forward recursion is retained only to compute causal filtered
probabilities and to audit append invariance.

At the close of session `t`, the primary forecast object is:

```text
Pr(sum(r_(t+1), ..., r_(t+20)) > 0 | information through t)
```

State labels are earned from TRAIN parameters. The state with the larger
fixed-state 20-session expected cumulative return is `MORE_FAVORABLE`; the
other is `LESS_FAVORABLE`. No OOS return may determine or flip those labels.

## Breadth Decision

More assets do not repair weak identification inside a separately fitted time
series. Breadth will later be used as replication evidence under one unchanged
specification, not as a search for the ticker that produces the cleanest
states. A shared cross-sectional HMM is a different future concept.

## Evidence Ladder

1. Easy synthetic positive controls prove that the fitted model can recover a
   known persistent directional process and issue causal 20-session forecasts.
2. A frozen detection frontier varies drift separation, state persistence,
   and sample length. It maps power instead of forcing every weak/null case
   into a clean binary verdict.
3. Fully synthetic Student-t GARCH noise supplies a financial-shaped
   misspecification bridge while preserving known latent truth.
4. A future semi-synthetic market-residual exercise may inject frozen drift
   into real pre-2024 residual blocks, but it is not opened here.
5. Honest market TRAIN/OOS evidence and any strategy contact require a new
   discussion after the mechanism packet is reviewed.

## What Counts as Working

Raw hit rate is not sufficient. The candidate must be compared with the
unconditional TRAIN up frequency and a single-regime AR(1) using the same
return history. Report Brier score, log loss, calibration, state recovery,
transition recovery, and the synthetic oracle ceiling. A model can pass the
teaching positive control while failing under realistic signal-to-noise; that
is a useful detection-boundary result, not a contradiction.

## Professional Boundary

The engineered positive control proves machinery, not alpha. Synthetic or
financial-shaped success cannot authorize a market state, strategy, PnL,
allocation, leverage, or live behavior. Conversely, failure near realistic
drift levels would show that this specification lacks power under those
conditions; it would not prove that all HMMs are categorically useless.
