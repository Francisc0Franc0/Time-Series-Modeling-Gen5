# HYP-MOM-04.3C Feature Transport Audit Results

Status: `FEATURE_TRANSPORT_AUDIT_COMPLETE_NO_PROMOTION_AUTHORITY`

## Question

Why did H04.3B's four-feature Ridge model fail in `2021Q1-2023Q3`? Did every
input fail, did a relationship exist only in the upper tail, or did TRAIN
directions fail to transport?

## Evidence boundary and integrity

The audit reused H04.3B's 479 signal-eligible identities, 11 DEVELOPMENT
quarters, sector-relative target, and terminal policy. All `5,124` eligible
rows reconciled. The last accessed bar remained `2023-12-29`; 2024+ remained
sealed. No feature, subset, model, weight, sign, threshold, or state was added.

## How to read the diagnostics

Spearman IC asks whether the feature ranks the entire cross-section correctly.
A positive top-quartile mean asks a narrower question: did the broad upper
quarter outperform its sector peers on average? A top-decile result checks
whether that behavior becomes stronger among the most extreme observations.

These can disagree. A positive top quartile alongside a negative top decile
means the apparent upper-tail result is not concentrated in the strongest
signals; the extreme tail actually deteriorates. That is weaker evidence than
a monotonic quartile curve and strengthening decile result.

## Feature readout

| Feature | Mean IC | Positive IC quarters | Mean Q4 target | Positive Q4 quarters | Mean D10 target | Positive mean-IC sectors |
|---|---:|---:|---:|---:|---:|---:|
| Sector-relative 126-session return | +0.0042 | 6 / 11 | +0.302% | 7 / 11 | -0.665% | 5 / 11 |
| 63-session trend R2 | -0.0220 | 4 / 11 | -0.544% | 5 / 11 | -0.778% | 3 / 11 |
| Recovery from 252-session low | -0.0203 | 5 / 11 | +0.014% | 4 / 11 | +0.261% | 6 / 11 |
| Positive-month fraction | +0.0072 | 5 / 11 | +0.031% | 7 / 11 | -0.199% | 9 / 11 |

### Sector momentum: a broad-quartile hint, not an extreme-tail signal

Sector momentum's Q4 averaged `+0.302%` and was positive in `7 / 11` quarters,
but the top decile averaged `-0.665%`. Its mean IC was essentially zero and only
five sectors had positive mean IC. The quartile curve was also non-monotonic:
Q2 was the worst group. The result does not support the simple story that
"more sector-relative momentum is steadily better."

### Positive-month fraction: broad sector sign, negligible magnitude

This feature had positive mean IC in nine sectors and a positive Q4-minus-Q1
spread in `8 / 11` quarters. However, mean IC was only `+0.0072`, Q4 averaged
just `+0.031%`, the best average outcome occurred in Q2 rather than Q4, and the
top decile was negative. Breadth without magnitude or monotonic shape is not a
tradeable finding.

### Trend R2: the clearest adverse input

Trend R2 showed a smooth inverse pooled quartile shape: Q1 averaged `+0.400%`
while Q4 averaged `-0.544%`. Q4-minus-Q1 was negative in `8 / 11` quarters,
and only three sectors had positive mean IC. This helps explain H04.3B because
the frozen TRAIN model assigned trend R2 a positive coefficient. It does not
authorize reversing the sign after inspection; a low-R2 hypothesis would be a
new, separately justified question.

### Recovery from low: no coherent shape

Mean IC was negative, quartile means were nearly flat and non-monotonic, and
sector signs split `6 / 11`. Its positive top-decile mean occurred in only
`5 / 11` quarters. There is no stable rank or tail interpretation here.

## Why Ridge was worse

The frozen H04.3B TRAIN coefficients and DEVELOPMENT marginal IC signs agreed
for only one of four inputs:

| Feature | Frozen TRAIN coefficient | DEVELOPMENT mean IC | Sign agrees? |
|---|---:|---:|---|
| Sector momentum | -0.00492 | +0.00415 | No |
| Trend R2 | +0.00203 | -0.02195 | No |
| Recovery from low | +0.00520 | -0.02029 | No |
| Positive-month fraction | +0.00019 | +0.00724 | Yes |

This comparison is mechanical, not causal: a multivariate Ridge coefficient is
conditional on the other features, while univariate IC is marginal. Still, the
three sign disagreements show why combining these TRAIN relationships could
rank later observations worse than the simple momentum comparator.

## Terminal sensitivity

Excluding all 26 terminal-policy rows changed sector momentum mean IC from
`+0.0042` to `+0.0015` and Q4 mean from `+0.302%` to `+0.256%`. Excluding only
FRC and SIVB changed them to `+0.0031` and `+0.292%`. Other features were
similarly stable. Corporate-action resolution did not drive the conclusion.

## Decision

No feature combines meaningful magnitude, monotonic shape, time stability,
extreme-tail confirmation, and sector breadth. Record
`FEATURE_TRANSPORT_AUDIT_COMPLETE_NO_PROMOTION_AUTHORITY`.

- Preserve H04.3B's STOP.
- Do not promote sector momentum or positive-month fraction.
- Do not reverse trend R2 under the inspected identifier.
- Do not open 2024+ merely because one retrospective curve is visually clean.

The next operator discussion should decide whether the inverse trend-quality
relationship has enough economic rationale to warrant a new minimal hypothesis
or whether this supervised branch should be set down in favor of a different
question. No automatic confirmation run is recommended.

## Artifacts

- Contract: `operator_hypothesis_lab/docs/HYP_MOM_04_3C_FEATURE_TRANSPORT_AUDIT_CONTRACT.md`
- Runner: `operator_hypothesis_lab/scripts/run_hyp_mom_04_3c_feature_transport_audit.R`
- Engine: `operator_hypothesis_lab/R/hyp_mom_04_3c_engine.R`
- Ignored packet: `runs/research_workbench/operator_hypothesis_lab/hyp_mom_04_3c_feature_transport_audit_20260811/`
- Deck: `operator_hypothesis_lab/presentations/hyp_mom_04_3c_feature_transport_audit_evidence.pptx`
