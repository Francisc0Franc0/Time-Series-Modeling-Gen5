# HYP-MOM-05.2 Triple-SMA Grid Walk-Forward Results

Status: `STOP_DEVELOPMENT_WFA_FAILED_CONFIRMATION_NOT_RUN`

## Question

Can a conservative training-only selector choose a portable member of a frozen
27-triplet ordered triple-SMA pullback/reclaim family?

This asks a different question from HYP-MOM-05.1. H05.1 tested one fixed
`15/30/45` rule. H05.2 tests the entire policy that selects one global triplet
from prior half-year blocks and applies it to the next unseen block.

## Evidence boundary

- Reused-window development: `2021-01-04` through `2023-12-29`.
- Four expanding outer tests: `2022H1`, `2022H2`, `2023H1`, and `2023H2`.
- Confirmation: `2024-01-02+`, sealed and not queried.
- Registered / eligible: `122 / 119` stocks across 11 sectors.
- APHA and SNE remained incomplete; LI had only 108 of the required 130
  prehistory sessions. All three were excluded without replacement.
- All 17 integrity checks passed.

Because the calendar was inspected in earlier operator-lab work, “outer test”
here means held out from the fold selector, not pristine external confirmation.

## What the selector chose

| Test block | Selected triplet | TRAIN score | One-SE set | Next-block grid percentile |
|---|---|---:|---:|---:|
| `2022H1` | `15 / 30 / 90` | 0.691 | 2 | 51.9% |
| `2022H2` | `15 / 40 / 90` | 0.669 | 4 | 44.4% |
| `2023H1` | `20 / 50 / 120` | 0.594 | 10 | 70.4% |
| `2023H2` | `20 / 50 / 120` | 0.608 | 8 | 29.6% |

The selector moved toward slower and more widely separated horizons and then
stabilized on `20/50/120`. That is an interpretable training preference, but it
did not transport reliably. The selected cell was never the best candidate in
its next block and fell below the grid median in two of four tests.

The one-standard-error plateau was broad in the last three folds but contained
only two candidates in fold 1, failing the frozen minimum-three stability gate.
The latest TRAIN surface also was not a single smooth optimum: `20/50/120`
scored 0.61, while a separate `15/30/60` cell scored 0.60.

## Outer-test result

At 1x primary costs, compounding the four causally selected half-years produced:

- median asset return `-7.25%`;
- `34 / 119` positive assets;
- median Sharpe `-0.448`;
- median maximum drawdown `-14.04%`;
- median exposure `12.60%`;
- median hit rate `25.00%`; and
- median matched-shift percentile `15.0%`, with `0 / 119` assets above the
  80th percentile.

No outer block had a positive median asset return: `2022H1` was exactly zero,
followed by `-3.13%`, `-0.63%`, and `-1.11%`. Zero in `2022H1` reflects broad
non-participation, not evidence of successful loss avoidance: only 22 of 119
assets were positive and the median Sharpe was `-0.844`.

## Entry anatomy

| Entry type | Trades | Hit rate | Median trade | Median hold |
|---|---:|---:|---:|---:|
| Initial ordered-stack activation | 369 | 27.37% | -2.275% | 12 sessions |
| Ordered medium-SMA reclaim | 289 | 27.68% | -1.073% | 3 sessions |

Longer horizon separation reduced H05.1's reclaim dominance: reclaims were 44%
of H05.2 trades rather than 89% of H05.1 trades. It did not repair the concept.
Both initial activations and reclaims had poor hit rates and negative median
trade returns. The failure therefore is broader than immediate reclaim whipsaw.

## Baselines and breadth

At 1x, H05.2's median excess return was:

- `-4.80` percentage points versus buy-and-hold;
- `-3.32` points versus candidate-specific medium-SMA timing; and
- `+3.80` points versus candidate-specific ordered-stack ownership.

Beating the weakest ordered-stack baseline does not rescue a negative absolute
result. Only Energy had a positive sector median (`+0.38%`); the other ten
sectors were negative. Median return was `-1.86%` for the original 22,
`-6.29%` for the diversified core, and `-18.59%` for the retail-attention
cohort. These are descriptive diagnostics, not selection invitations.

## Leverage and costs

Fixed-quantity 1.8x worsened median return to `-15.17%` and median maximum
drawdown to `-24.77%`. Median financing cost was `1.16%` of initial wealth.
There were no 30% maintenance-proxy breaches and no nonpositive-equity assets,
but lack of impairment is not evidence of useful leverage.

The 1x median return remained negative gross (`-6.49%`), primary (`-7.25%`),
and stress (`-7.77%`). Frictions aggravated rather than created the failure.

## Gates and decision

Only `1 / 7` gates passed: integrity. Median return, asset majority, fold
breadth, direct-baseline superiority, matched-timing control, and minimum
training-plateau breadth all failed.

Record `STOP_DEVELOPMENT_WFA_FAILED_CONFIRMATION_NOT_RUN` and keep 2024+ sealed.
The negative result is more informative than the H05.1 fixed-triplet null: a
compact, conservative, globally selected horizon grid did not reveal portable
timing behavior. Do not expand the grid or select the apparent better cells,
assets, sectors, or cohorts under this identifier.

Any future work should begin with a new mechanism-level hypothesis—not a wider
parameter search. Examples such as persistence confirmation, slope, or
volatility normalization require their own theory, frozen rule, and identifier.

## Artifacts

- Contract: `operator_hypothesis_lab/docs/HYP_MOM_05_2_TRIPLE_SMA_GRID_WFA_CONTRACT.md`
- Engine: `operator_hypothesis_lab/R/hyp_mom_05_2_triple_sma_grid_wfa.R`
- Runner: `operator_hypothesis_lab/scripts/run_hyp_mom_05_2_triple_sma_grid_wfa.R`
- Tests: `operator_hypothesis_lab/tests/testthat/test_hyp_mom_05_2_triple_sma_grid_wfa.R`
- Evidence deck: `operator_hypothesis_lab/presentations/hyp_mom_05_2_triple_sma_grid_wfa_evidence.pptx`
- Ignored packet: `runs/research_workbench/operator_hypothesis_lab/hyp_mom_05_2_triple_sma_grid_wfa_20260813/`
