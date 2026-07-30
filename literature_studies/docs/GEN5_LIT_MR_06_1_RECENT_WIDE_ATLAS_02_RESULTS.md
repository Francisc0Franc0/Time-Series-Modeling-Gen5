# LIT-MR-06.1 Recent Wide Atlas 02 Results

Status: `STOP_LIT_MR_06_1_RECENT_WIDE_ATLAS_02_NO_FULL_PASS`

## Question

Would the unchanged causal buy-on-gap rule produce stronger and better
supported evidence on a newer, materially wider, outcome-blind stock panel?

## Frozen scope

- TRAIN: `2023-01-03` through `2024-12-31`.
- Conditional DEVELOPMENT: `2025-01-02` through `2026-06-30`.
- Primary universe: `305` unique stocks across all eleven Select Sector SPDR
  categories.
- Sector panels: eight panels of `30` stocks plus energy `21`,
  communication services `18`, and materials `26`.
- Strategy mechanics, 09:32 entry, ten fixed cash sleeves, 10/20 bp costs,
  controls, and all eight TRAIN gates were unchanged from Atlas 01.
- The July 2026 holdings registry and coverage screen were frozen before any
  strategy outcome was computed.

The frozen contract is
[Recent Wide Atlas 02](GEN5_LIT_MR_06_1_RECENT_WIDE_ATLAS_02_CONTRACT.md).

## Decision

No panel passed all eight TRAIN gates. Record:

`STOP_LIT_MR_06_1_RECENT_WIDE_ATLAS_02_NO_FULL_PASS`

DEVELOPMENT was not queried. CONFIRMATION from `2026-07-01` onward remains
sealed.

## Primary combined-panel readout

`W01_WIDE_US` was materially stronger than the initial 20-stock broad control:

| Diagnostic | Recent wide panel |
|---|---:|
| Frozen stocks | 305 |
| Selected stock-events | 190 |
| Completed events used by support gate | 185 |
| Portfolio days | 121 |
| Gates passed | 7 / 8 |
| Primary cumulative return | +4.12% |
| Stress cumulative return | +2.21% |
| Same-open noncausal reference | +7.94% |
| Mean primary portfolio-day return | +3.42 bp |
| One-sided 90% bootstrap lower bound | -2.81 bp |
| Mean matched-benchmark excess | +5.14 bp |
| Random-control p90 | -0.83 bp |
| Stock-event hit rate | 54.6% |
| Up/down accuracy | 56.2% |
| Adjusted Sharpe, descriptive TRAIN estimate | 1.32 |
| Maximum drawdown | -2.67% |
| Largest symbol share of positive gross P&L | 7.0% |

The only failed gate was the positive uncertainty bound. The positive point
estimate therefore remains a near-pass, not promotion evidence.

## Primary gate audit

| Gate | Diagnostic | Status |
|---|---|---|
| Integrity and causal timing | 10 / 10 checks | PASS |
| Selected-entry coverage | 97.4% | PASS |
| Support | 185 completed events; 121 days | PASS |
| Mean stock-event return | +22.39 bp | PASS |
| Bootstrap lower 90% | -2.81 bp/day | **FAIL** |
| Matched-benchmark excess | +5.14 bp/day | PASS |
| Random-control separation | +3.42 bp vs -0.83 bp p90 | PASS |
| Stress and concentration | +2.21%; 7.0% maximum positive-P&L share | PASS |

The support gate counts completed events with valid return endpoints; the
summary counts all selected stock-events. Both definitions were frozen and
are reported rather than reconciled after outcomes.

## Sector diagnostics

Financials and health care also reached `7 / 8`, but only because their
positive point estimates and uncertainty bounds occurred in very small
samples:

| Panel | Events | Days | Primary return | Lower 90% | Failed gate |
|---|---:|---:|---:|---:|---|
| Financials | 22 | 19 | +2.35% | +5.32 bp/day | Support |
| Health care | 23 | 21 | +1.29% | +0.57 bp/day | Support |

Their high annualized Sharpe estimates are not reliable with 19 and 21 active
days. They are observations for future hypothesis design, not sector
nominees. Every individual sector panel failed the frozen support gate.

## Initial-versus-recent comparison

| Diagnostic | Atlas 01 broad control | Atlas 02 wide panel |
|---|---:|---:|
| TRAIN dates | 2019-2020 | 2023-2024 |
| Stocks | 20 | 305 |
| Selected stock-events | 19 | 190 |
| Portfolio days | 12 | 121 |
| Primary cumulative return | -1.21% | +4.12% |
| Stress cumulative return | -1.39% | +2.21% |
| Up/down accuracy | 42.1% | 56.2% |
| Gates passed | 2 / 8 | 7 / 8 |

This comparison is descriptive. Both the dates and breadth changed, so it
cannot identify whether regime, universe breadth, current-survivor bias, or
their interaction caused the improvement.

## What we learned

1. The rule is intended for individual stocks. SPY and sector ETFs are
   benchmarks only.
2. Broader cross-sectional coverage can turn an underpowered textbook example
   into a statistically assessable experiment.
3. Breadth solved support for the combined panel, but not uncertainty.
4. Direction accuracy improved above 50%, which is consistent with—but does
   not independently establish—the positive return evidence.
5. The causal delay remains economically material: the same-open curve was
   almost twice the primary causal gain.
6. Current holdings provide a rational, reproducible panel, but not
   point-in-time historical membership.

## Artifacts

- Evidence packet:
  `runs/research_workbench/literature_grounded/lit_mr_06_1_recent_wide_atlas_02_20260730`
- [Evidence deck](../presentations/gen5_lit_mr_06_1_recent_wide_atlas_02_evidence.pptx)
- [Frozen registry](../registries/gen5_lit_mr_06_1_recent_wide_atlas_02_registry.csv)
- Runner:
  `literature_studies/scripts/run_gen5_lit_mr_06_1_recent_wide_atlas_02.ps1`

## Boundary

Do not reinterpret `7 / 8` as a weighted pass, select the best sector after
outcomes, query DEVELOPMENT, tune the bootstrap or support gates, change entry
timing, or add another rescue panel inside this batch. A new test requires a
newly justified and frozen batch or variant.
