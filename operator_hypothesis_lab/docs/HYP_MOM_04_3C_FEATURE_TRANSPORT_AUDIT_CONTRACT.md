# HYP-MOM-04.3C Feature Transport Audit Contract

Status: `FROZEN_EXECUTED_COMPLETE`

## Purpose

Explain the failed H04.3B temporal replication without trying to rescue it.
This is a retrospective diagnostic audit of already-open DEVELOPMENT evidence,
not a model-selection or strategy-promotion lane.

## Evidence boundary

- Reuse the H04.3B fixed September 2020 SPY cohort.
- Reuse signals `2021Q1-2023Q3` and targets through `2023Q4`.
- Reuse the sector-relative next-quarter target and H04.3B terminal policy.
- Do not access any observation dated `2024-01-01` or later.
- Reconcile exactly the H04.3B `5,124` signal-eligible rows before auditing.

## Frozen feature set

Audit only the four H04.3B inputs:

1. `sector_relative126` — prior six-month return versus eligible sector peers;
2. `trend_r2_63` — goodness of fit of the recent log-price trend;
3. `recovery_from_low252` — distance above the trailing one-year low; and
4. `positive_month_fraction12` — fraction of 12 approximate monthly blocks
   with positive returns.

No new feature, interaction, transformation search, sign flip, subset, weight,
lambda, classifier, or market-state filter is admissible.

## Frozen diagnostics

For each feature, report:

- Spearman IC in each of 11 quarters, its mean, and positive-quarter count;
- mean target in each within-quarter feature quartile;
- top-minus-bottom quartile spread and positive-quarter count;
- top-quartile and top-decile target means and positive-quarter counts;
- within-sector IC by quarter and the number of sectors with positive mean IC;
- sensitivity after excluding all 26 terminal-policy rows; and
- sensitivity after excluding only the two zero-recovery rows.

The audit may describe a relationship as coherent only when its sign, shape,
time breadth, and sector breadth agree. These descriptions confer no promotion
authority.

After the predeclared audit, one mechanical reconciliation may compare the
already-frozen H04.3B TRAIN coefficient signs with the audited DEVELOPMENT
mean-IC signs. This adds no feature, outcome screen, or alternative fit.

## Stop state

The only valid completion state is
`FEATURE_TRANSPORT_AUDIT_COMPLETE_NO_PROMOTION_AUTHORITY`. H04.3B remains
stopped, its comparators remain unpromoted, and 2024+ remains sealed. Any new
confirmation hypothesis requires a separate operator discussion and frozen
contract.
