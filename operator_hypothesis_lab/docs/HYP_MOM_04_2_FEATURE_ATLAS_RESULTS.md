# HYP-MOM-04.2 Feature Atlas Results

Status: `STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN`

## Question

Can a controlled atlas of causal OHLCV features identify an interpretable
feature family or predefined basket whose relationship with next-quarter
relative return transports through time inside TRAIN?

This lane was motivated by a useful visual research practice: plot each
feature against the desired outcome, inspect the shape, and then ask whether
the apparent relationship repeats. The plots were never promotion tests.

## Frozen scope

- 481 coverage-eligible identities from the September 2020 SPY deployment
  cohort;
- 7,208 stock-quarter rows across 15 signal quarters, `2017Q1-2020Q3`;
- 33 causal price, trend, path, risk, participation, and relative-strength
  features;
- next-quarter open-to-open return relative to the eligible-universe mean;
- nine predefined candidates: eight Ridge baskets and one fixed-sign score;
- two nested three-quarter outer validation blocks; and
- 200 within-quarter full-search permutations.

No observation dated `2021-01-01` or later was queried. The effective temporal
sample is 15 quarters, not 7,208 independent experiments.

## What the feature plots showed

The pooled plots were informative but not sufficient:

| Feature | Mean quarterly IC | Positive quarters | Readout |
|---|---:|---:|---|
| `beta126` | `+0.0609` | `8 / 15` | Largest pooled mean; upper deciles bent upward, but the sign was not stable. |
| `rv126` | `+0.0512` | `9 / 15` | Similar pooled risk-seeking shape. |
| `trend_r2_63` | `+0.0433` | `10 / 15` | Modest trend-quality association. |
| `recovery_from_low252` | `+0.0366` | `12 / 15` | Best sign frequency, but small average magnitude. |
| `momentum12_1` | `-0.0015` | `9 / 15` | Classic momentum was essentially flat. |
| `volatility_ratio` | `-0.0637` | `4 / 15` | Most consistently adverse average relationship. |

The quarter-by-feature heatmap supplied the missing context: green and red
frequently alternated within the same feature row. Twenty-one feature pairs
also exceeded the frozen `0.85` absolute rank-correlation threshold, showing
that additional indicators often represented the same underlying state.

Scatter displays clip each axis to its 1st-99th percentiles for readability.
All reported statistics use every finite observation.

## Nested candidate search

Every candidate's best inner-validation mean IC was negative in both outer
rehearsals. The mechanical selections were:

| Outer fold | Earlier TRAIN quarters | Selected candidate | Lambda | Inner mean IC |
|---|---:|---|---:|---:|
| 1 | 9 | `RIDGE_TREND_QUALITY` | `100` | `-0.0063` |
| 2 | 12 | `RIDGE_RELATIVE_STRENGTH` | `10` | `-0.0084` |

The changing candidate is itself evidence of instability. Selection still
continued exactly as frozen so the outer blocks could measure the complete
procedure rather than only an attractive hand-selected basket.

## Outer validation

| Metric | Result |
|---|---:|
| Mean outer rank IC | `-0.1071` |
| Positive outer IC quarters | `3 / 6` |
| Mean outer top-quartile excess | `-2.23 pp` |
| Positive top-quartile quarters | `4 / 6` |
| Frozen original-six mean outer IC | `-0.0623` |
| Selected-minus-original mean IC | `-0.0448` |

The largest failure was `2020Q3`: rank IC was `-0.6732` and the selected
top-quartile excess was `-13.34 pp`. This is not merely one unlucky trade. It
shows that a cross-sectional relationship that looked usable in earlier
quarters reversed sharply in a later environment.

## Search-adjusted null

The observed mean outer IC (`-0.1071`) was below every one of the 200
full-search permutation outcomes. The search-adjusted p-value was `1.000`.
Repeating basket and lambda selection inside every null draw prevents the
feature search from receiving a free statistical pass.

## Gates and decision

Three of nine gates passed:

- integrity and sample breadth;
- sector-contribution concentration (`33.53%`, below the `35%` ceiling).

Six failed:

- outer IC;
- both-block transport;
- outer top-quartile excess;
- search-adjusted evidence;
- improvement over the original-six challenger; and
- selection/coefficient stability.

Record `STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN`. The feature atlas is valuable as
an educational and hypothesis-formation surface, especially for seeing why
beta, realized volatility, and recovery can look interesting in pooled TRAIN.
It did not identify a stable feature basket for this target and sampling
design. No feature, sign, threshold, basket, or lambda may be rescued under
this identifier.

Changing the target, decision frequency, feature data source, universe, or
model family would require a new frozen lane and a new rationale. The reserved
OOS period remains uncontaminated.

## Evidence

- packet:
  `runs/research_workbench/operator_hypothesis_lab/hyp_mom_04_2_feature_atlas_train_20260811/`;
- contract:
  `operator_hypothesis_lab/docs/HYP_MOM_04_2_FEATURE_ATLAS_CONTRACT.md`; and
- deck:
  `operator_hypothesis_lab/presentations/hyp_mom_04_2_feature_atlas_evidence.pptx`.
