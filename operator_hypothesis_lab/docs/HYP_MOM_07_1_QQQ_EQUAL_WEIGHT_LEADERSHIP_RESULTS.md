# HYP-MOM-07.1 QQQ / Equal-Weight Leadership Results

Status: `STOP_HYP_MOM_07_1_NO_SEARCH_ADJUSTED_TRAIN_SURFACE`

## Question

When modified-cap-weighted Nasdaq-100 exposure recently outperforms the same
universe under equal weighting, does that relative leadership persist over a
short forward horizon?

## Source decision

The return-blind source audit passed all `5 / 5` gates.

- `QQQ` and `QQEW` each supplied `1,259` aligned Alpaca SIP adjusted-daily
  sessions from `2016-01-04` through `2020-12-31`.
- Nasdaq documents NDXE as the equal-weighted version of the Nasdaq-100,
  containing the same securities and rebalancing quarterly.
- First Trust documents `QQEW` inception on `2006-04-19` and an underlying
  index change effective `2025-12-22`.
- The contract therefore permits the historical investable proxy only through
  `2025-12-19`. The current run ended in 2020, and no post-change observation
  entered the experiment.

The workbench emitted stale-cache WARNs because the deliberately bounded TRAIN
query ended in 2020 while the explicit as-of date was August 2026. Both symbols
fully covered the requested window, so those WARNs do not affect this result.

## Frozen test

The common TRAIN panel contained `986` signal anchors. It crossed trailing
QQQ-minus-QQEW log-return lookbacks `{5,20,60}` with future next-open
QQQ-minus-QQEW log-return horizons `{1,5,20}`.

The global statistic was the maximum Pearson correlation across all nine
cells. Every admissible joint circular shift with at least 60 anchors of
displacement contributed one null maximum; there were `867` such controls.
TRAIN could nominate a cell only if its observed maximum was positive and
strictly above the 90th percentile of those shift maxima.

## Result

Every frozen cell pointed against persistence.

| Cell | Correlation | Slope |
|---|---:|---:|
| `L20_H1` (least negative) | `-0.038244` | `-0.011339` |
| `L60_H1` | `-0.041267` | `-0.008071` |
| `L5_H20` | `-0.059376` | `-0.111307` |
| `L60_H20` | `-0.061357` | `-0.041359` |
| `L20_H5` | `-0.063399` | `-0.035218` |
| `L5_H5` | `-0.067977` | `-0.069271` |
| `L5_H1` | `-0.074243` | `-0.040381` |
| `L60_H5` | `-0.087211` | `-0.031956` |
| `L20_H20` | `-0.162043` | `-0.165590` |

The observed global maximum was `-0.038244`. The complete circular-shift
maximum-statistic p90 was `+0.166329`, and the empirical upper-tail probability
was `1.000000`.

This is stronger than a merely underpowered positive result: the complete
surface had the wrong sign for the stated persistence mechanism. It does not
establish exploitable reversal, because reversal was not the registered
alternative and received no independent confirmation design.

## Decision

Record `STOP_HYP_MOM_07_1_NO_SEARCH_ADJUSTED_TRAIN_SURFACE`.

- Nominate no cell.
- Do not query or calculate 2021-2023 DEVELOPMENT.
- Preserve 2024-2025 confirmation unread.
- Do not reverse the sign, change the ETF proxy, search neighboring horizons,
  add breadth/volume/semiconductor context, or construct a pair trade under
  this identifier.
- Continue to `QQQ-S2`, the separately bookmarked semiconductor-to-QQQ
  intraday lead-lag proposition, only under its own frozen contract.

No strategy, P&L, Sharpe, drawdown, allocation, leverage, or live behavior was
computed.

## Future wrong-sign question

The complete negative TRAIN surface is bookmarked as motivation for a future,
independent relative-reversal hypothesis. The bookmark is not a sign flip or
rescue of this result: `HYP-MOM-07.1` remains stopped, its later evidence stays
sealed, and no reversal performance claim has been made. A future test must
use a new identifier, reversal-specific contract, and fresh evidence boundary.

## Evidence

- [Frozen contract](HYP_MOM_07_1_QQQ_EQUAL_WEIGHT_LEADERSHIP_CONTRACT.md)
- [Run report](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_07_1_qqq_equal_weight_leadership_20260822/hm071_report.md)
- [Source audit](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_07_1_qqq_equal_weight_leadership_20260822/hm071_source_audit.csv)
- [TRAIN surface](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_07_1_qqq_equal_weight_leadership_20260822/hm071_train_surface.csv)
- [Search-adjusted decision](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_07_1_qqq_equal_weight_leadership_20260822/hm071_train_decision.csv)
- [Surface figure](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_07_1_qqq_equal_weight_leadership_20260822/visuals/hm071_train_surface.png)
- [Search-control figure](../../runs/research_workbench/operator_hypothesis_lab/hyp_mom_07_1_qqq_equal_weight_leadership_20260822/visuals/hm071_train_search_control.png)
- [Updated momentum predictor evidence deck](../../literature_studies/presentations/gen5_momentum_predictor_evidence_series.pptx)
