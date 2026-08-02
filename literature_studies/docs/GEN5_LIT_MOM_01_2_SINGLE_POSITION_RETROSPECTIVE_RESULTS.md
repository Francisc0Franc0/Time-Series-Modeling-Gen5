# LIT-MOM-01.2 Long-Only Single-Position Retrospective Results

Status:

- `RETROSPECTIVE_EXPLORATION_COMPLETE_LIT_MOM_01_2`
- `RETROSPECTIVE_EXPLORATION_COMPLETE_LIT_MOM_01_2_STOCK_ATLAS_01`
- `RETROSPECTIVE_EXPLORATION_COMPLETE_LIT_MOM_01_2_STOCK_ATLAS_02`

## Operator correction and evidence boundary

`LIT-MOM-01.2` is now authoritatively long-only. Negative and zero rolling
lookback returns mean cash; only a positive lookback return can start a trade.
The operator explicitly preserved the `01.2` identifier and every other
mechanic rather than creating a new decimal variant.

The prior long/short implementation at commit `70f1c20` is retained only as
`PRE_CORRECTION_LONG_SHORT_DIAGNOSTIC`. It is not the definition or current
performance record of `01.2`.

All results below reuse the already inspected 2021-2023 retrospective window.
They teach how the hypothesis behaves; they are not fresh OOS confirmation,
asset-selection evidence, or portfolio authority. Sealed 2024+ data were not
queried.

## Frozen mechanics

- Every asset evaluates all 49 predeclared `L/H` cells on TRAIN.
- `CHAN_MIN_STEP=min(L,H)` remains the primary selector; `STEP_L=L` and
  `STRICT_L_PLUS_H=L+H` remain sensitivity views.
- The correlation screen retains both positive and negative TRAIN outcomes.
  Long-only applies to the executable policy, not to selection-data filtering.
- A positive selected-`L` return at the decision close enters at the next open.
- One fixed-quantity position uses all current equity after entry cost, holds
  exactly `H` open-to-open intervals, exits, and reinvests the resulting equity.
- While invested, new signals are ignored. After exit, a new qualifying signal
  may enter at that same open.
- Gross, 5 bp-per-side primary, and 10 bp-per-side stress regimes are reported.
  Short borrow is exactly zero in every regime.

## SHY worked example

TRAIN again selected `L=60`, `H=5`; the selector was unchanged by the
long-only correction.

| TRAIN inference view | Pairs | Correlation | Sign consistency |
|---|---:|---:|---:|
| `CHAN_MIN_STEP` | 201 | 0.2084 | 60.2% |
| `STEP_L` | 17 | 0.2449 | 58.8% |
| `STRICT_L_PLUS_H` | 16 | 0.1995 | 68.8% |

The retrospective policy completed 69 long trades. No short trade or borrow
charge was generated.

| Cost regime | Cumulative return | Maximum drawdown |
|---|---:|---:|
| Gross | +0.22% | -3.11% |
| Primary | -6.46% | -7.87% |
| Stress | -12.70% | -13.35% |

The 69 long calls were correct about direction 44.93% of the time. Mean
primary trade return was -0.0965%. This is a useful reminder that the positive
TRAIN correlation was not a guarantee of positive retrospective direction
accuracy or implementable P&L.

## Stock Atlas 01

The frozen 22-stock, eleven-sector panel independently searched all 49 TRAIN
cells for each asset, for 1,078 TRAIN evaluations. Each selected rule was then
replayed long-only in the known window.

| Atlas 01 breadth readout | Result |
|---|---:|
| Assets replayed | 22 |
| Positive gross / primary / stress paths | 17 / 16 / 15 |
| Median primary return | +17.96% |
| Mean primary return | +23.82% |
| Worst primary maximum drawdown | -49.73% |
| Mean retrospective long-call accuracy | 54.54% |

The long-only correction materially changed the descriptive result, but it did
not create authority to nominate the strongest names. All 22 outcomes were
already known when this correction was requested.

## Stock Atlas 02: 2020 breadth + attention

Atlas 02 froze 100 additional names with zero overlap to Atlas 01: 75
sector-diversified stocks drawn from SPY's June 30, 2020 SEC filing and 25
stocks documented in contemporaneous 2020 Robinhood/Robintrack coverage.
Coverage rules stopped nine names before strategy interpretation, leaving 91
eligible replays and 4,459 TRAIN horizon evaluations.

| Atlas 02 breadth readout | All eligible | Diversified core | Retail attention 2020 |
|---|---:|---:|---:|
| Eligible assets | 91 | 74 | 17 |
| Positive primary paths | 50 | 45 | 5 |
| Positive stress paths | 47 | 42 | 5 |
| Median primary return | +6.92% | +11.69% | -19.95% |
| Mean primary return | +17.01% | +21.60% | -3.00% |
| Worst primary maximum drawdown | -86.30% | -- | -- |

Across eligible assets, mean retrospective long-call accuracy was 53.69%.
Every completed trade was long, total borrow was zero, and all integrity checks
passed. The cohort contrast is descriptive only: the core sample is
survivor-prone and the eligible attention cohort is small.

## Research significance bookmark

The operator identifies this lane as one of the most encouraging Gen5.x
research results so far for two reasons:

1. It presents a plausible surface for disciplined refinement and further
   inquiry rather than an unambiguous mechanism null.
2. It combines a rigorous literature-derived horizon-selection framework with
   an operator-origin long-only, full-capital swing-trading hypothesis.

Codex concurs with that characterization at the **research-program** level.
The breadth of positive retrospective paths, above-chance average long-call
accuracy, and meaningful differences between frozen cohorts justify careful
auditing and theory-led follow-up. They do not yet establish deployable alpha.
The evidence remains exposed to a known retrospective window, per-asset
horizon selection, correlated market exposure, survivor-prone universes, and
large path-level drawdowns. This bookmark therefore means
`PROMISING_FOR_AUDIT_AND_REFINEMENT`, not `STRATEGY_CONFIRMED`.

**Subsequent evidence:** Audit 01 completed the predeclared exposure,
matched-random-timing, fixed-horizon, SPY-regression, and environment
attribution. The audit passed only 2 of 11 diagnostics and found no incremental
timing evidence in the inspected window. This bookmark remains historically
correct as the reason the audit was warranted, but its forward status is
superseded by `STOP_LIT_MOM_01_2_AUDIT_01_NO_INCREMENTAL_TIMING`. See the
[Audit 01 results](GEN5_LIT_MOM_01_2_AUDIT_01_EXPOSURE_SELECTION_RESULTS.md).

## Interpretation and decision

The corrected lane now answers the operator's intended question cleanly:
positive momentum can authorize a concentrated long swing; negative momentum
means cash, not a short. In this known sample, that asymmetry produced much
stronger breadth results than the archived long/short diagnostic, while SHY
itself remained cost-negative.

Record the three retrospective-complete statuses above. Do not promote names,
form a portfolio, tune the 49-cell grid from these outcomes, reinterpret cohort
differences causally, or query sealed 2024+ data without a separate operator
gate.

## Artifacts

- Base contract:
  `literature_studies/docs/GEN5_LIT_MOM_01_2_SINGLE_POSITION_RETROSPECTIVE_CONTRACT.md`
- Atlas 01 contract:
  `literature_studies/docs/GEN5_LIT_MOM_01_2_STOCK_ATLAS_01_RETROSPECTIVE_CONTRACT.md`
- Atlas 02 contract:
  `literature_studies/docs/GEN5_LIT_MOM_01_2_STOCK_ATLAS_02_2020_BREADTH_ATTENTION_CONTRACT.md`
- Atlas 02 registry:
  `literature_studies/registries/gen5_lit_mom_01_2_stock_atlas_02_2020_breadth_attention_registry.csv`
- SHY evidence packet:
  `runs/research_workbench/literature_grounded/lit_mom_01_2_long_only_single_position_retrospective_20260802`
- Atlas 01 evidence packet:
  `runs/research_workbench/literature_grounded/lit_mom_01_2_long_only_stock_atlas_01_retrospective_20260802`
- Atlas 02 evidence packet:
  `runs/research_workbench/literature_grounded/lit_mom_01_2_long_only_stock_atlas_02_2020_breadth_attention_20260802`
- Authoritative deck:
  `literature_studies/presentations/gen5_lit_mom_01_2_long_only_retrospective_evidence.pptx`
- Attribution-audit results:
  `literature_studies/docs/GEN5_LIT_MOM_01_2_AUDIT_01_EXPOSURE_SELECTION_RESULTS.md`
- Attribution-audit deck:
  `literature_studies/presentations/gen5_lit_mom_01_2_audit_01_exposure_selection_evidence.pptx`
- Archived pre-correction deck:
  `literature_studies/presentations/gen5_lit_mom_01_2_single_position_retrospective_evidence.pptx`
