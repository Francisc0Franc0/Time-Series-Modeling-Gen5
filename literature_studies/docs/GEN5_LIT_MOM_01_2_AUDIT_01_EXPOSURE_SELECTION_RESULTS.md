# LIT-MOM-01.2 Audit 01: Exposure and Selection Results

Status: `STOP_LIT_MOM_01_2_AUDIT_01_NO_INCREMENTAL_TIMING`

Evidence label: `RETROSPECTIVE_ATTRIBUTION_AUDIT`

## Bottom line

The encouraging raw `LIT-MOM-01.2` stock-atlas result was worth auditing, but
the attribution audit changes its interpretation. Across 113 stocks, the
selected policy earned a positive median return, yet it did not outperform
simple ownership, matched exposure, matched random timing, the canonical
`250/25` reference, or broad-market regression often enough to support an
incremental timing-alpha claim.

The frozen diagnostic scorecard passed 2 of 11 lines:

- all integrity checks passed; and
- per-asset TRAIN selection beat the fixed `60/5` tutorial reference.

Every attribution diagnostic that could substantively support incremental
timing value missed its frozen threshold. Stop this lane before factor or
filter mining. Confirmation data from 2024 onward remain sealed.

## Boundary and integrity

- TRAIN: 2017-01-03 through 2020-12-31.
- Retrospective audit: 2021-01-04 through 2023-12-29.
- Universe: SHY, 22 Atlas 01 stocks, and 91 eligible Atlas 02 stocks; 114
  histories total and 113 stocks.
- Costs: 5 bp per entry and 5 bp per exit for trade-based policies.
- Matched random timing: 1,000 seeded schedules per asset.
- Sector-cluster uncertainty: 5,000 seeded resamples across eleven sector
  clusters.
- All integrity checks passed and 2024+ observations were excluded.

`XLC` retains the already known `partial_history` query-health warning because
the ETF began after the common 2016 reference-query start. It fully covers the
2021-2023 audit window and the required pre-window lookback, so no requested
audit observation is missing. Reference caches also appear stale relative to
the 2026 run timestamp because the query was intentionally bounded at the end
of 2023; this is provenance, not a refresh requirement for the frozen window.

## Baseline attribution

Across 113 stock paths:

- median selected-policy return: **+9.59%**;
- median buy-and-hold return: **+23.46%**;
- assets beating buy-and-hold: **30/113 (26.5%)**;
- median excess versus buy-and-hold: **-13.31 percentage points**;
- assets beating constant exposure: **29/113 (25.7%)**;
- median excess versus constant exposure: **-11.81 percentage points**; and
- median excess versus consecutive always-long `H` blocks:
  **-3.56 percentage points**.

The sector-cluster 90% interval for median excess versus buy-and-hold was
`[-20.02, -7.30]` percentage points. The corresponding interval versus
constant exposure was `[-18.86, -7.95]`. Those intervals are entirely
negative.

The important distinction is exposure opportunity. Buy-and-hold is a useful
upper-level comparator but carries more exposure. Constant exposure applies
the strategy's actual average invested fraction every day, removing the
signal calendar while keeping comparable market opportunity. Failure against
that control is direct evidence against incremental signal timing in the
inspected window.

## Matched-random timing

The selected policy beat the median of 1,000 matched random schedules on
**51/113** stocks. Its median random percentile was **48.6%**.

Each random schedule retained the asset's selected `H`, observed trade count,
non-overlap rule, costs, and current-equity compounding. Only the calendar was
randomized. The selected dates therefore behaved like ordinary dates under a
matched execution structure rather than a persistently advantageous momentum
calendar.

## Horizon selection

- median selected minus fixed `250/25`: **-1.25 percentage points**;
- sector-cluster 90% interval: `[-8.26, +4.17]`;
- median selected minus fixed `60/5`: **+15.77 percentage points**; and
- sector-cluster 90% interval: `[+10.54, +26.70]`.

Per-asset TRAIN selection clearly improved on the fixed `60/5` tutorial
reference. It did not improve on Chan's canonical `250/25` reference at the
cross-sectional median. This is useful process evidence, but it does not
validate the 49-cell selector as a source of OOS value.

## Broad-market attribution

- median daily-return beta versus SPY: **0.576**;
- median annualized OLS intercept: **-0.92%**; and
- positive estimated intercepts: **54/113 (47.8%)**.

This single-factor regression is diagnostic, not a complete asset-pricing
model. It nevertheless provides no cross-sectional majority evidence that the
selected policy retained a positive return component after broad-market
co-movement.

## Environment description

All supported frozen environment cells had positive mean trade returns. The
largest contrasts were counter-cyclical rather than a simple risk-on story:

- SPY 60-session trend non-positive: **+0.63%** mean trade return versus
  **+0.23%** when positive;
- sector-ETF 60-session trend non-positive: **+0.68%** versus **+0.16%** when
  positive; and
- market trend non-positive plus high volatility: **+0.63%**.

These cells pool executed trades and satisfy the frozen minimum of 100 trades
and 20 assets. They are conditional descriptions only. The audit did not
adjust these comparisons for multiple testing, establish causality, or test an
implementable environment filter. Because the overall timing policy failed
matched exposure and matched random timing, these cells cannot rescue the
strategy on the same inspected data.

## Decision

The earlier `PROMISING_FOR_AUDIT_AND_REFINEMENT` bookmark was appropriate as a
reason to run this audit. It is now superseded by a more precise conclusion:

`STOP_LIT_MOM_01_2_AUDIT_01_NO_INCREMENTAL_TIMING`

What remains valuable is the research process: a literature-grounded signal,
an operator-origin execution hypothesis, broad causal replays, and a frozen
attribution ladder produced a useful falsification rather than a vague null.
Do not use the 2021-2023 environment cells to tune filters. Reopen only through
a separately justified hypothesis and operator-approved contract that
preserves untouched confirmation evidence.

## Artifacts

- Contract:
  `literature_studies/docs/GEN5_LIT_MOM_01_2_AUDIT_01_EXPOSURE_SELECTION_CONTRACT.md`
- Helper:
  `literature_studies/R/gen5_lit_mom_01_2_audit_01_exposure_selection.R`
- Runner:
  `literature_studies/scripts/run_gen5_lit_mom_01_2_audit_01_exposure_selection.R`
- Focused tests:
  `literature_studies/tests/testthat/test_gen5_lit_mom_01_2_audit_01_exposure_selection.R`
- Evidence packet:
  `runs/research_workbench/literature_grounded/lit_mom_01_2_audit_01_exposure_selection_20260802`
- Evidence deck:
  `literature_studies/presentations/gen5_lit_mom_01_2_audit_01_exposure_selection_evidence.pptx`
