# HYP-MOM-08.1 QQQ / SPY Relative-Strength Persistence Results

Status: `STOP_HYP_MOM_08_1_NO_SEARCH_ADJUSTED_TRAIN_SURFACE`

## Question

When QQQ has recently outperformed SPY, does that relative style leadership
continue over a short daily horizon after accounting for intercept-only
relative drift, the separate QQQ and SPY return legs, and the fact that nine
lookback/target cells were inspected?

## Frozen design

- Predictor: trailing QQQ-minus-SPY adjusted-close log return.
- Target: next-open-to-exit-open QQQ-minus-SPY log return.
- Lookbacks: `5`, `20`, and `60` sessions.
- Forward horizons: `1`, `5`, and `20` sessions.
- TRAIN: anchors and target endpoints within `2017-01-03` through
  `2020-12-31` after 2016 warm-up.
- Conditional DEVELOPMENT: `2021-01-04` through `2023-12-29`.
- Sealed confirmation: `2024-01-02` through `2025-12-31`.
- Multiplicity control: complete joint circular-shift maximum statistic with
  minimum 60-anchor displacement and a frozen p90 hurdle.

The contract was frozen after a return-blind source/calendar inventory and
before any relative return, forward target, correlation, slope, or loss was
calculated.

## Data and timing integrity

All `6 / 6` source and coverage gates passed.

- QQQ and SPY supplied `1,259` identical adjusted-daily sessions from
  `2016-01-04` through the requested TRAIN end `2020-12-31`.
- Dates were unique and ordered; prices were finite and positive.
- The signal uses the close of anchor session `t`.
- Every target begins at the next session's open and ends at a later open.
- The widest `L60/H20` eligibility rule produced `986` common TRAIN anchors.
- No 2021 or later return target was constructed after the TRAIN stop.

Workbench health is `WARN` only because its generic freshness check compares
the intentionally historical `2020-12-31` query end with the 2026 as-of
session. Both symbols fully cover the requested interval, so the warning has
no evidence-window impact and does not require a refresh.

## TRAIN surface

Eight of nine Pearson correlations and eight of nine slopes were negative.
The only positive cell was also the observed maximum:

| Cell | Correlation | Slope | Spearman |
|---|---:|---:|---:|
| `L60_H20` | `0.075240` | `0.044426` | `0.057931` |

The short and medium cells were reversal-shaped. The most negative
correlation was `L5_H5` at `-0.167542`; its slope was `-0.166624`.

## Search-adjusted falsification

The complete control enumerated `867` admissible joint circular shifts. For
each shift, it retained the largest correlation across the full nine-cell
surface.

| Quantity | Value |
|---|---:|
| Observed maximum | `0.075240` |
| Shift-maximum p90 | `0.151402` |
| Empirical upper-tail probability | `0.321429` |

The observed maximum was positive but less than half the frozen hurdle. The
TRAIN surface therefore failed its family-wise gate and no lookback/horizon
was nominated.

## Separate-leg diagnostic

The QQQ-only and SPY-only predictors were reported against the same forward
QQQ-minus-SPY target. They are controls, not substitute hypotheses.

At `L60_H20`, correlations were:

- relative QQQ-minus-SPY predictor: `0.075240`;
- QQQ return alone: `0.048561`; and
- SPY return alone: `0.019280`.

The relative predictor was the largest in that one cell, but the cell itself
failed the search-adjusted gate. An attractive leg or descriptive ordering
cannot open DEVELOPMENT.

## Decision

Record `STOP_HYP_MOM_08_1_NO_SEARCH_ADJUSTED_TRAIN_SURFACE`.

- Nominate no cell.
- Do not calculate 2021-2023 DEVELOPMENT returns or forecast losses.
- Preserve 2024-2025 confirmation.
- Do not select `L60_H20` because it was the lone positive cell.
- Do not invert the eight wrong-sign cells into a reversal strategy.
- Do not add beta residualization, another market proxy, nearby horizons,
  thresholds, volume, breadth, sectors, regimes, or asset subsets under this
  identifier.

The narrow conclusion is that QQQ-versus-SPY relative strength did not show a
search-adjusted persistence surface in this TRAIN interval. This does not
establish that style leadership never persists, and it does not authorize a
relative-reversal claim.

No strategy, P&L, costs, Sharpe, drawdown, allocation, leverage, or live
behavior was computed.

## Evidence

- [Frozen contract](HYP_MOM_08_1_QQQ_SPY_RELATIVE_STRENGTH_CONTRACT.md)
- [Run report](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_08_1_qqq_spy_relative_strength_20260822/hm081_report.md)
- [Source audit](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_08_1_qqq_spy_relative_strength_20260822/hm081_source_audit.csv)
- [TRAIN surface](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_08_1_qqq_spy_relative_strength_20260822/hm081_train_surface.csv)
- [TRAIN decision](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_08_1_qqq_spy_relative_strength_20260822/hm081_train_decision.csv)
- [Separate-leg comparison](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_08_1_qqq_spy_relative_strength_20260822/hm081_train_leg_comparison.csv)
- [Updated momentum predictor evidence deck](../../literature_studies/presentations/gen5_momentum_predictor_evidence_series.pptx)
- [Surface figure](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_08_1_qqq_spy_relative_strength_20260822/visuals/hm081_train_surface.png)
- [Search-control figure](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_08_1_qqq_spy_relative_strength_20260822/visuals/hm081_train_search_control.png)
- [Separate-leg figure](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_08_1_qqq_spy_relative_strength_20260822/visuals/hm081_train_leg_comparison.png)
