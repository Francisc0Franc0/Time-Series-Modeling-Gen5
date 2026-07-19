# Gen5.4 Cross-Sectional Asset-Selection POC Plan

Status: X0 complete; X1 complete; `STOP_BEFORE_MODEL_FIT`

Decision date: 2026-07-19

Branch: `codex/Gen5.4-ml-decision-engine-plan`

## Why This Pivot Exists

The earlier five-asset work asked whether exposure could be timed inside a
retrospectively selected high-beta basket. This plan asks a different question:
given a wider, diverse candidate panel at a historical close, can the system
rank which eligible assets are more likely to outperform their contemporaneous
opportunity set over the next several sessions?

The pivot is useful because cross-sectional data provides many same-date
comparisons and makes relative leadership measurable. It does not make price
action intrinsically rich, remove market non-stationarity, or eliminate
selection bias. A larger panel improves the measurement design; it does not
manufacture an economic signal.

## Two Decisions, Kept Separate

1. **Exposure permission:** is the broad environment favorable enough to take
   long risk at all?
2. **Asset ranking:** among point-in-time eligible candidates, which assets have
   the strongest relative opportunity?

A relative winner can still have a negative absolute return. Therefore a
cross-sectional ranking score is not, by itself, a long-entry signal. This POC
opens the ranking question only. Exposure permission, sizing, top-K portfolio
construction, and live advice remain separate gates.

## Frozen X0/X1 Universe

The ranked candidate panel contains 24 stocks across six economic groups:

- semiconductors: `AMD`, `NVDA`, `AVGO`, `MU`, `QCOM`;
- platforms/media: `AAPL`, `MSFT`, `META`, `AMZN`, `NFLX`;
- high-beta/special situations: `TSLA`, `MSTR`;
- defensive consumer/health: `KO`, `PEP`, `WMT`, `COST`, `JNJ`, `UNH`;
- financials: `JPM`, `BAC`, `GS`;
- energy/industrial: `XOM`, `CVX`, `CAT`.

The context-only panel is `SPY`, `QQQ`, `IWM`, `SMH`, `TLT`, and `GLD`. Context
anchors are not eligible ranking targets in X0/X1.

Candidate identity is fixed in advance for this POC. Daily eligibility is
point-in-time and requires price at least `$5`, trailing 60-session median
dollar volume at least `$20 million`, complete backward-looking features, and
at least 20 eligible candidates on the same date.

This is not a point-in-time reconstruction of the historical US equity
universe. It has an explicit survivor and availability limitation. Any later
claim about prospective stock discovery requires historical membership,
delistings, corporate actions, and timestamped fundamental/event availability.

## Observation, Execution, And Target

- Observe adjusted daily OHLCV through close `t`.
- Hypothetically execute at open `t+1`.
- Measure the five-session open-to-open return ending at open `t+6`.
- Subtract the same-date equal-weight h5 return of all eligible candidates.

The primary label is therefore cross-sectional excess return, not an absolute
profit label. Raw h5 return is retained so negative-market relative winners can
be identified rather than mistaken for successful long trades.

Only labels whose endpoint remains inside the quarterly OOS authority enter
diagnostics. Same-date ranks and peer means use no later observations.

## Minimal POC Ladder

### X0 — Universe and timestamp integrity

Verify fixed-panel coverage, daily point-in-time eligibility, minimum
cross-section size, adjusted-bar consistency, and explicit as-of provenance.
No outcome relationship is interpreted until X0 passes.

### X1 — No-model measurement audit

Measure predeclared feature ranks against relative h5 outcomes using daily
Spearman rank IC, quarterly sign stability, top-versus-bottom outcome ordering,
and top-selection group concentration. Fit no model and choose no policy.

The seven frozen primitives are 20- and 60-session momentum, 20-session
market-relative momentum, 20-session economic-group-relative momentum,
60-session drawdown resilience, 20-session low volatility, and a 5-versus-60
session participation ratio.

Promotion requires all of:

- pooled mean daily rank IC above zero;
- pooled top-minus-bottom relative h5 outcome above zero;
- positive mean IC in at least 12 of 20 OOS folds;
- positive outcome ordering in at least 12 of 20 OOS folds;
- no more than 50% of top selections from one economic group.

At least two economically distinct primitives must pass before X2. This rule
prevents a model from being used to decorate one weak idea with complexity.

### X2 — Pooled linear ranker

If admitted, fit a regularized linear cross-sectional ranker with fold-local
preprocessing. Compare it against each surviving primitive and a simple
equal-weight composite. Require stable improvement, not merely a positive
backtest. X2 is currently blocked.

### X3 — Constrained nonlinear challenger

Only if X2 establishes genuine multivariate value, compare one conservative
tree-based challenger under the identical folds, features, labels, and
diagnostics. The nonlinear learner must earn its extra degrees of freedom. X3
is currently blocked.

### X4 — Exposure and portfolio policy

Only after ranking evidence survives model comparison, test top-K selection,
absolute-risk permission, turnover, costs, concentration, and exposure-matched
benchmarks. Ranking and long-entry permission must remain separately auditable.
X4 is currently blocked.

### X5 — Fresh forward confirmation

Freeze the full research contract and evaluate one untouched later window.
Retuning after this confirmation starts a new hypothesis rather than repairing
the old one. X5 is reserved.

## X0/X1 Readout

X0 passed: all 24 candidates met the fixed-panel coverage requirement, the
aligned panel contained 49,296 rows, and all six leakage checks passed.

X1 stopped before model fitting. Economic-group-relative 20-session momentum
was the only primitive to clear every gate: pooled IC `0.0267`, positive IC and
ordering in `15 / 20` folds, top-minus-bottom relative h5 outcome `+42.2 bp`,
and maximum group share `48.1%`.

Sixty-session momentum had the strongest raw ordering (`+61.0 bp`) and passed
both fold-stability gates, but failed the concentration cap at `67.3%`.
Market-relative 20-session momentum ranked identically to ordinary 20-session
momentum because subtracting the same SPY return from every asset on a date
cannot change that date's rank. Low volatility was negatively associated with
the target, and participation supplied no stable independent ordering.

The correct conclusion is not to fit a cleverer ranker. Widening the universe
improved the measurement surface but did not produce two independent OHLCV
signals. The next theory gate should consider one genuinely different,
retail-accessible, point-in-time information family before X2 is reopened.

## OHLCV-Only X1b And C0 Extension

The operator subsequently opened two bounded diagnostics while the external
fundamentals-data path remained blocked:

- X1b tested residual momentum, residual reversal, signed trend efficiency,
  and intraday-minus-overnight information structure as ranking primitives.
- C0 tested 60-session breadth, group participation, low average correlation,
  and low cross-sectional dispersion as exposure-permission conditions.

Residual coefficients use the preceding 126 sessions only. C0 favorable-state
thresholds are medians fitted on each fold's eight-quarter TRAIN window. X1b
candidates must satisfy the original IC, ordering, fold-stability, and group-
concentration gates and have median absolute daily rank correlation no greater
than `0.70` versus group-relative 20-session momentum.

X1b admitted one distinct primitive: intraday-minus-overnight 20-session
structure. It produced pooled rank IC `0.0056`, positive IC and ordering in
`12 / 20` folds, top-minus-bottom relative h5 outcome `+8.2 bp`, maximum group
share `47.6%`, and redundancy correlation `0.22`.

Signed efficiency had stronger raw diagnostics—IC `0.0281`, positive IC in
`15 / 20` folds, ordering in `13 / 20`, and `+24.9 bp` top-minus-bottom—but
failed the frozen group-concentration cap at `51.2%`. Residual momentum failed
IC-fold stability and concentration; residual reversal failed direction and
ordering.

C0 failed decisively. None of the four commonsense risk-on conditions separated
favorable from unfavorable equal-weight h5 outcomes in the required `12 / 20`
folds. Breadth, group participation, and low average correlation were positively
ordered in only `3`, `2`, and `2` folds respectively, with pooled separations
between `-141 bp` and `-157 bp`. Low dispersion was less poor but still negative
at `-23.8 bp` with positive separation in `9 / 20` folds.

The overall result is `STOP_BEFORE_TWO_STAGE_RULES_DESIGN`. The ranking layer now
has two distinct admitted OHLCV primitives when the earlier group-relative
momentum result is included, but the separately required exposure-permission
layer did not pass. Do not implement the two-stage demonstrator by dropping C0
after observing its OOS failure.

## Artifacts

- Packet: `runs/research_workbench/gen54_ml_decision_engine/g54_xs_20260719x0x1/`
- Report: `runs/research_workbench/gen54_ml_decision_engine/g54_xs_20260719x0x1/xs_report.md`
- Feature verdicts: `runs/research_workbench/gen54_ml_decision_engine/g54_xs_20260719x0x1/xs_feature_verdict.csv`
- Leakage audit: `runs/research_workbench/gen54_ml_decision_engine/g54_xs_20260719x0x1/xs_leakage_audit.csv`
- Deck: `presentations/gen5_4_cross_sectional_asset_selection_poc_plan_and_x1_evidence.pptx`
- Dialogue provenance: `docs/GEN5_4_DECISION_DIALOGUE_INDEX.md`
- X1b/C0 packet: `runs/research_workbench/gen54_ml_decision_engine/g54_xs_x1b_c0_20260719/`

## Current Boundary

No model, top-K portfolio, allocation method, performance acceptance, or live
behavior is authorized by X0/X1 or X1b/C0. The current frozen result is
`STOP_BEFORE_TWO_STAGE_RULES_DESIGN`.
