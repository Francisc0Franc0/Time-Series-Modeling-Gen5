# Return-Geometry Abnormal-Volume Veto (2018-2023 TRAIN)

## Question

The applicability atlas showed one unusually coherent visual clue: rebound-rule
events with the highest abnormal dollar volume subsequently underperformed.
This slice freezes that clue as one causal veto and asks whether it survives
cross-sectional, sector, severity-matched, participation, and calendar
diagnostics without changing the stopped underlying rule.

This is an internal TRAIN falsification of a post-hoc clue. It is not an edge
test, a model-selection exercise, or permission to open later outcomes.

## Frozen Veto

- Underlying rule: signed ER20 DOWN, bottom causal quintile of prior negative
  20-session returns, next-open entry, 20 held sessions, non-overlap, and 10 bp
  round-trip cost.
- Daily abnormal dollar volume:
  `log(current 20-session median dollar volume / preceding 126-session median)`.
- Causal rank: each day's feature is compared with up to 504 strictly prior
  daily observations; at least 252 are required.
- `HIGH_VETO`: causal abnormal-volume percentile at or above 60%.
- `NORMAL_RETAIN`: causal percentile below 60%.
- Outcome: net next-open 20-session log return minus the same asset's
  unconditional TRAIN drift.
- Primary surface: 1,548 frozen events across the balanced 88-stock,
  11-sector core. All 2,221 atlas events remain in the audit ledger.
- Post-2023 outcomes remain sealed.

The 60% boundary was chosen before this slice was run because it exactly maps
the atlas clue—the highest two of five causal-percentile bins—into one simple
veto. It was not tuned after seeing the event outcomes.

## Predeclared Cross-Sectional Checks

All seven frozen checks pass:

1. causal-percentile coverage is complete for the core;
2. asset-balanced high-minus-normal contrast is negative;
3. at least 60% of comparable assets have a negative contrast;
4. at least 7 of 11 sector median contrasts are negative;
5. same-asset, prior-loss-severity-matched contrast is negative;
6. at least 50% of events are retained; and
7. the retained event mean improves versus the original rule.

## Readout

- `HIGH_VETO`: 625 events; event-pooled excess `-1.22%` per trade;
  asset-balanced excess `-1.13%`.
- `NORMAL_RETAIN`: 923 events; event-pooled excess `+0.41%` per trade;
  asset-balanced excess `+0.48%`.
- Asset-balanced high-minus-normal contrast: `-160 bp/trade`.
- Same-asset, closest-loss-severity matched contrast: `-179 bp/trade`.
- Asset breadth: 55/88 comparable assets favor the veto.
- Sector breadth: 8/11 sector medians favor the veto.
- Participation: 59.6% of core events remain.
- The original event-pooled excess is `-25 bp/trade`; the retained subset is
  `+41 bp/trade`; removed high-volume events are `-122 bp/trade`.

The median prior loss is similar in the two states (`-9.36%` retained versus
`-9.74%` vetoed), and the within-asset matched comparison remains negative.
That makes simple loss-severity confounding an incomplete explanation.

All four eligible atlas cohorts also have negative high-minus-normal
contrasts, but they share the same discovery era and are diagnostic rather
than independent replication.

## The Brake: Calendar Instability

The veto direction appears in only 3 of 6 TRAIN calendar years:

- supports the veto: 2018, 2020, and 2021;
- reverses: 2019, 2022, and 2023.

The latest TRAIN year, 2023, has a positive high-minus-normal contrast. The
very large 2020 separation also raises the possibility that the aggregate
result is partly crisis-sensitive.

Calendar stability was not substituted as a new post-hoc pass/fail gate. It is
reported as a separate diagnostic that qualifies the seven frozen gate passes
and blocks a clean promotion claim.

## Interpretation

This is the first upstream descriptor in this lane to behave like a plausible
failure-state veto rather than a merely nonmonotone visual feature. It removes
about 40% of events and materially improves the average retained outcome under
both pooled and asset-balanced views. The same direction survives sector
breadth and local severity matching.

However, the effect does not transport reliably through time. The defensible
conclusion is therefore not “high volume creates an edge.” It is:

> Within this TRAIN sample, unusually high causal abnormal volume identifies a
> cross-sectionally broad subset of rebound events with worse outcomes, but the
> separation is temporally unstable and not ready for OOS promotion.

## Artifacts

- Packet:
  `runs/research_workbench/operator_hypothesis_lab/return_geometry_abnormal_volume_veto_20260828/`
- Frozen specification: `run_spec.csv`
- Status and diagnostics: `status.csv`, `train_veto_gates.csv`,
  `temporal_diagnostic.csv`
- Event ledger: `event_veto_ledger.csv`
- Contrasts: `asset_veto_contrasts.csv`, `sector_veto_contrasts.csv`,
  `year_veto_contrasts.csv`, `cohort_veto_diagnostics.csv`
- Matched controls: `severity_matched_pairs.csv`
- Running deck:
  `operator_hypothesis_lab/presentations/return_geometry_edge_promotion_huddle.pptx`

## Status and Boundary

`TRAIN_VOLUME_VETO_CROSS_SECTIONAL_SUPPORT_TEMPORALLY_UNSTABLE_STOP_BEFORE_OOS`

Do not retune the 60% threshold, combine features, select favorable years or
sectors, or query post-2023 outcomes from this packet. The next gate remains an
operator decision after reviewing whether temporal instability stops the
candidate or motivates one separately frozen mechanism test.
