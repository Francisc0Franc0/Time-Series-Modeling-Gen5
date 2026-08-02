# LIT-MOM-01.2 Audit 01: Representative Trade-Tape Review

Status: `RETROSPECTIVE_DESCRIPTIVE_TRADE_TAPE_REVIEW_COMPLETE`

Evidence label: `OUTCOME_AWARE_VISUAL_AUDIT_NOT_FREQUENCY_EVIDENCE`

Governing strategy status:
`STOP_LIT_MOM_01_2_AUDIT_01_NO_INCREMENTAL_TIMING`

## Bottom line

Eight deterministically selected tapes show that `LIT-MOM-01.2` did not
express one stable path mechanism in the inspected 2021-2023 window. Similar
positive endpoints arose from ordinary exposure, rebound dependence, a small
number of outsized trades, or selective loss avoidance. Negative paths arose
from cost erosion, missed recoveries, and prolonged high-beta cyclicality.

This review is useful because it turns cross-sectional summaries into
auditable behavior. It does not estimate how common any archetype is, nominate
an asset, validate an environment filter, reopen the strategy, or inspect the
sealed 2024+ confirmation period.

## Frozen sample

Selection was outcome-aware but frozen before any individual tape was viewed.
The eight unique archetypes deliberately span a worked-mechanics anchor, the
robust cross-sectional center, contrasting failures, unusual survivors,
drawdown risk, cohort behavior, and market-state asymmetry.

| Archetype | Asset | L/H | Primary return | Excess vs buy-and-hold | Random percentile | Maximum drawdown | Visual read |
|---|---:|---:|---:|---:|---:|---:|---|
| Tutorial anchor | SHY | 60/5 | -6.46% | -5.71 pp | 62.4% | -7.87% | Many tiny round trips convert a nearly flat asset into steady cost erosion. |
| Cross-sectional medoid | HD | 10/10 | +21.87% | -17.84 pp | 48.6% | -33.24% | A typical positive path shadows ordinary exposure and misses much of the recovery. |
| Positive but exposure-dominated | UNP | 5/5 | +5.36% | -20.78 pp | 48.3% | -33.55% | One hundred short blocks create churn without timing advantage. |
| Attribution survivor | F | 10/10 | +174.92% | +114.46 pp | 98.9% | -39.93% | A few 20-30% winners create a genuine-looking survivor and concentration question. |
| Random-timing disappointment | TJX | 25/25 | +9.76% | -33.86 pp | 15.4% | -29.62% | The strategy participates in losses and misses much of the later rally. |
| Deep-drawdown positive finish | META | 25/25 | +46.54% | +15.81 pp | 75.6% | -61.23% | The endpoint requires surviving a severe 2022 collapse before the rebound. |
| Attention-cohort medoid | AAL | 10/10 | -28.54% | -16.46 pp | 26.5% | -68.45% | Early gains devolve into serial cyclicality, whipsaw, and prolonged loss. |
| Countercyclical trade mix | NKE | 10/10 | +9.03% | +30.19 pp | 86.5% | -30.02% | Selective loss avoidance looks more important than ordinary trend capture. |

The sample is deliberately not a winner reel. `SHY`, `HD`, `UNP`, `TJX`, and
`AAL` expose different failure modes; `F`, `META`, and `NKE` expose three
different ways a path can look encouraging.

## What the tapes teach

### Positive return is not a mechanism

`HD` and `UNP` finish positive but trail both asset ownership and
exposure-matched controls. `TJX` finishes positive while landing at only the
15th percentile of matched random calendars. These paths are consistent with
ordinary market opportunity plus an unhelpful calendar, not incremental
timing.

### Endpoint return can hide unusable path risk

`META` ends ahead of buy-and-hold but suffers a 61.23% strategy drawdown.
`AAL` shows the complementary failure: an early gain above 50% eventually
becomes a 28.54% loss and 68.45% drawdown. Any later refinement would need to
explain the path, not merely improve the endpoint average.

### The best-looking paths raise narrower questions

`F` passes several retrospective attribution diagnostics, but its wealth path
visibly depends on a small number of large winners. `NKE` instead appears to
benefit from avoiding part of an asset-level decline: its 13 signals generated
when the SPY 60-session trend was down or flat averaged +2.57%, compared with
-0.37% across 40 signals in positive market-trend states. Its annualized SPY
intercept remained negative, so this is a state-asymmetry prompt, not filter
evidence.

## Organic follow-up hypotheses

The most useful next questions are narrower than “does momentum work?”:

1. **Trade-contribution concentration.** What fraction of a path's terminal
   gain comes from its top one, three, and five trades? `F` is the clearest
   motivation, but the diagnostic should be defined cross-sectionally before
   inspecting more individual winners.
2. **Crash avoidance versus rebound capture.** Decompose excess return into
   participation during asset drawdowns, avoidance of negative sessions, and
   capture of subsequent recoveries. `NKE` and `META` suggest materially
   different economic behaviors despite both finishing ahead of buy-and-hold.
3. **State asymmetry.** Test whether the down/flat-versus-up trade-return
   contrast survives a predeclared cross-asset aggregation, multiplicity
   control, and untouched data. The current environment cells and `NKE` tape
   are hypothesis generators only.

Turnover/cost burden and time-under-water should remain standard diagnostics,
especially for short `H` selections such as `SHY` and `UNP`. They do not need
new strategy nomenclature unless the operator later changes mechanics.

## Decision

Record
`RETROSPECTIVE_DESCRIPTIVE_TRADE_TAPE_REVIEW_COMPLETE` while preserving
`STOP_LIT_MOM_01_2_AUDIT_01_NO_INCREMENTAL_TIMING`.

No factor, filter, horizon change, asset-selection rule, portfolio rule, or
confirmation replay is authorized by this review. Any follow-up should first
freeze one of the narrower diagnostic questions above and preserve 2024+ as
untouched evidence.

## Artifacts

- Review contract:
  `literature_studies/docs/GEN5_LIT_MOM_01_2_AUDIT_01_TRADE_TAPE_REVIEW_CONTRACT.md`
- Helper:
  `literature_studies/R/gen5_lit_mom_01_2_audit_01_trade_tapes.R`
- Runner:
  `literature_studies/scripts/run_gen5_lit_mom_01_2_audit_01_trade_tapes.R`
- Focused tests:
  `literature_studies/tests/testthat/test_gen5_lit_mom_01_2_audit_01_trade_tapes.R`
- Evidence packet:
  `runs/research_workbench/literature_grounded/lit_mom_01_2_audit_01_representative_trade_tapes_20260803`
- Representative-tape deck:
  `literature_studies/presentations/gen5_lit_mom_01_2_audit_01_representative_trade_tapes.pptx`
