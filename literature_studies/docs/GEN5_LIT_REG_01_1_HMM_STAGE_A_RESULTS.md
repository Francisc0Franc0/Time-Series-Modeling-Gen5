# LIT-REG-01.1 HMM Stage A Results

Status: `STOP_LIT_REG_01_1_ENGINE_OR_SYNTHETIC_GATES_FAILED_REAL_DATA_NOT_READ`

Date: 2026-08-19

## Question

Can the dependency-free Gaussian HMM engine satisfy all frozen mathematical,
causal, deterministic, synthetic-recovery, uncertainty, duration, and
numerical-reliability gates before any SPY result is read?

## Boundary Honored

- The committed `LIT_REG_01_1_SYNTHETIC_V1` fixtures used 50 strong and 50
  weak two-state simulations of 1,500 observations each.
- Fixture seeds, parameters, and assertions were committed before execution.
- No Alpaca query or SPY observation was read.
- No 2024+ observation, strategy, return outcome, allocation, leverage, or
  live behavior entered the run.
- The final authoritative packet is
  `runs/research_workbench/literature_studies/lit_reg_01_1_hmm_stage_a_20260819`.

## Gate Readout

| Gate | Frozen object | Observed | Status |
|---|---|---|---|
| A1 | Engine invariants and brute-force likelihood agreement | Forward minus brute-force log likelihood `0`; H2/H3 probability invariants passed | `PASS` |
| A2 | Deterministic replay | Maximum selected-fit, parameter, probability, and likelihood difference `0` | `PASS` |
| A3 | Append causality | Prior filtered-probability difference `0`; smoothing revised history by as much as `0.353` | `PASS` |
| A4 | Strong-state classification | Median `99.9%`; tenth percentile `99.7%` | `PASS` |
| A5 | Transition recovery | Median maximum error `0.0092`; ninetieth percentile `0.0206` | `PASS` |
| A6 | Weak-state uncertainty | Entropy `0.005` strong versus `0.448` weak; mean maximum confidence fell by `0.220` | `PASS` |
| A7 | Ordering and duration | Median maximum implied-duration relative error `17.2%` | `PASS` |
| A8 | Zero invalid fits | `77/100` valid fits | `FAIL` |

The gate is conjunctive. Seven passes cannot override A8.

## What Failed

The strong-separation surface was numerically reliable in 49 of 50 cases.
The weak-separation surface was reliable in only 28 of 50:

| Fixture | Converged/valid | Likelihood-decrease code | Maximum-iteration code |
|---|---:|---:|---:|
| Strong | 49 | 1 | 0 |
| Weak | 28 | 9 | 13 |

The result is narrower than “HMMs do not work.” The engine demonstrated exact
likelihood mechanics, deterministic replay, causal append invariance, excellent
recovery under clear separation, reasonable transition/duration recovery, and
lower confidence under ambiguity. It did not demonstrate the frozen level of
optimizer reliability when states overlap.

## Interpretation

This is an engine-qualification STOP, not a market-regime null result. The
experiment never reached SPY, B0/B1/H2/H3 held-out scoring, temporal-order
controls, occupancy/stability gates, or H3 complexity judgment.

The weak fixtures are important rather than adversarial decoration. Real
financial regimes may overlap, and a state model must be able to express that
uncertainty without producing unstable or unreported optimization outcomes.
The passing A6 result says confidence behaved sensibly in the valid weak fits;
A8 says the engine could not produce a valid fit often enough under the frozen
standard.

## Implementation Audit

The first serial qualification attempt was interrupted before producing any
gate output because expected transition counts were calculated row by row. The
calculation was replaced by the algebraically identical vectorized scaled
forward--backward sum and revalidated. Independent synthetic cases were then
scheduled across base-R workers without changing seeds or mechanics.

The next complete fit attempt exposed a reporter defect: invalid cases caused
an `NA` quantile error. No gate table was produced. The reporter was corrected
so invalid cases become explicit failed evidence. The final eight-worker run
above is the authoritative result.

## Artifacts

- Frozen contract:
  [GEN5_LIT_REG_01_1_HMM_REGIME_POC_CONTRACT.md](GEN5_LIT_REG_01_1_HMM_REGIME_POC_CONTRACT.md)
- Model registry:
  [gen5_lit_reg_01_1_hmm_model_registry.csv](../registries/gen5_lit_reg_01_1_hmm_model_registry.csv)
- Evidence deck:
  `literature_studies/presentations/gen5_lit_reg_01_1_hmm_stage_a_evidence.pptx`
- Run packet:
  `runs/research_workbench/literature_studies/lit_reg_01_1_hmm_stage_a_20260819`

## Stop and No-Rescue Boundary

Record:

`STOP_LIT_REG_01_1_ENGINE_OR_SYNTHETIC_GATES_FAILED_REAL_DATA_NOT_READ`

Do not run the frozen SPY folds, relax A8, discard weak cases, raise the
iteration ceiling, permit likelihood decreases, change the weak fixtures, or
add a package within `01.1` after seeing this outcome. A new numerical method,
optimizer discipline, emission family, or fixture policy requires a separately
discussed and frozen substantive variant.
