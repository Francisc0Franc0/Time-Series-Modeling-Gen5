# LIT-REG-02.1 Directional HMM Stage A Results

Status: `STOP_LIT_REG_02_1_DIRECTIONAL_MECHANISM_QUALIFICATION_FAILED`

Date executed: 2026-08-19

## Bottom Line

The package-native two-state Markov-switching AR(1) produced a valid,
deterministic, causal fit in all ten teaching simulations and improved proper
20-session direction-probability scores over both frozen baselines in nine of
ten cases. It nevertheless failed the frozen hard-state recovery and
transition-tail gates. Because Stage A was conjunctive, the detection frontier
and financial-shaped stress stages were not run.

This is neither a market null nor a strategy result. It is a useful separation
between two ideas that are often conflated: a model can improve probabilistic
forward-direction forecasts without decoding the exact daily hidden state at
very high accuracy.

## Evidence Boundary

- `market_data_read=FALSE`
- `semi_synthetic_market_data_read=FALSE`
- `confirmation_data_read=FALSE`
- `strategy_data_read=FALSE`
- No Alpaca query, real market return, real residual, 2024+ observation,
  strategy, PnL, Sharpe, drawdown, entry, exit, allocation, leverage, or live
  behavior entered the run.
- Stage B's 64-case detection frontier and Stage C's ten financial-shaped
  synthetic cases were structurally not executed.

## Frozen Stage A Scorecard

| Gate | Result | Observed evidence |
|---:|---|---|
| A1 | `PASS` | `hmmTMB 1.1.2`; valid selected fits `10/10`. |
| A2 | `PASS` | Appending 100 observations changed no earlier causal filtered probability; maximum difference `0`. |
| A3 | `FAIL` | Median OOS hard-state accuracy `72.1%`; tenth percentile `64.7%`, below `85%` and `75%`. |
| A4 | `FAIL` | Median maximum transition error `0.0344` passed its component, but the ninetieth percentile was `0.1289`, above `0.10`. |
| A5 | `PASS` | Mean Brier: H2 `0.2363`, B0 `0.2485`, B1 `0.2523`; H2 beat each in `9/10` cases. |
| A6 | `PASS` | Mean log loss: H2 `0.6653`, B0 `0.6903`, B1 `0.6978`; H2 beat each in `9/10` cases. |
| A7 | `PASS` | Oracle mean Brier `0.2003` versus H2 `0.2363`; every probability and score was finite. |
| A8 | `PASS` | Repeated parameters, causal probabilities, and scores matched exactly; maximum difference `0`. |

## What Worked

The package dependency earned its keep in this limited role. All ten cases had
a valid selected multistart fit, every package likelihood agreed with the
explicit Gen5 causal recursion within the frozen tolerance, and repeated
execution was exact. This differs materially from `LIT-REG-01.2`, where weak
and null fits often failed numerically before scientific classification.

The central forward-probability evidence also worked. The HMM beat a constant
TRAIN up-probability baseline and a one-state Gaussian AR(1) on both Brier
score and log loss in nine of ten independently seeded OOS simulations. The
oracle remained better, as it should: knowing the true current state is more
informative than estimating it through noisy returns.

## What Failed

The model did not reconstruct the exact daily state sequence at the very high
rate demanded by the teaching gate. Daily return distributions still overlap
substantially even with planted drifts of `-30` and `+30` bp. A soft filtered
probability can therefore retain useful information while the corresponding
hard `argmax` state label is wrong on many individual dates.

Transition estimation was usually good: the median maximum error was `0.0344`.
Two cases were materially worse, producing a ninetieth-percentile error of
`0.1289`. The frozen gate correctly prevents a clean claim that the package
recovered persistence reliably across the entire teaching batch.

## Interpretation

The most important lesson is not “directional HMMs failed.” The narrower
result is:

1. the selected package architecture is numerically viable on all ten planted
   directional cases;
2. its soft probabilities add average OOS directional information beyond the
   frozen no-state baselines in this engineered setting;
3. exact day-by-day state decoding is materially harder than probabilistic
   swing-horizon forecasting; and
4. the frozen contract required both, so Stage A stopped.

This tension suggests that a future forecast-first variant could reasonably
make proper probability scores primary and state-recovery accuracy a
diagnostic. That decision cannot be applied retrospectively to `02.1`. It
would require a new contract and should still retain an oracle ceiling,
transition diagnostics, and null/weak characterization.

## Preserved Future Paths

- `LIT-REG-02.2` forecast-first synthetic detection frontier: substantively
  reframe qualification around Brier/log-loss value while retaining state
  recovery as diagnostic evidence.
- Stronger teaching positive control: useful only as a visibly easier engine
  demonstration, never as a replacement for the stopped `02.1` evidence.
- More TRAIN history or higher state persistence: valid power-map axes, not
  reactive repairs to this run.
- Financial-shaped synthetic noise: the already frozen Stage C design can
  inform a future contract, but was not executed here.
- Real-residual semi-synthetic bridge: inject a frozen directional process into
  predeclared pre-2024 residual blocks after a separate data contract.
- Honest market TRAIN/OOS test: use one canonical series and a fixed
  replication atlas only after mechanism qualification; do not choose the
  cleanest asset retrospectively.
- Transition covariates, HSMM duration, cross-sectional/shared states, and
  Bayesian priors remain later model families, not automatic rescue steps.

## STOP

Preserve
`STOP_LIT_REG_02_1_DIRECTIONAL_MECHANISM_QUALIFICATION_FAILED`. Do not lower
the state-accuracy gate, delete the two high-transition-error cases, strengthen
the planted drift, lengthen TRAIN, run the frozen downstream stages, or touch
market/strategy data under `02.1` after inspecting these outcomes.

## Evidence Packet

Authoritative ignored packet:
`runs/research_workbench/literature_studies/lit_reg_02_1_directional_hmm_poc_20260819`

Key files:

- `run_spec.csv`
- `stage_a_positive_registry.csv`
- `stage_a_case_summary.csv`
- `stage_a_forecasts.csv`
- `stage_a_fit_diagnostics.csv`
- `stage_a_causality_determinism_checks.csv`
- `stage_a_gates.csv`
- `stage_a_teaching_probability_tape.csv`
- `stage_a_teaching_probability_tape.png`
- `stage_a_forecast_scores.png`
- `verdict.txt`
