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

## X2a Two-Feature Linear Ranker Confirmation

A later theory session separated ranking combination from exposure permission
and opened one minimal model test. X2a used only the two already admitted ranks:
group-relative 20-session momentum and intraday-minus-overnight 20-session
structure. It compared each raw rank, a fixed 50/50 composite, and one pooled
ordinary least-squares ranker on six quarterly OOS folds from `2025Q1` through
`2026Q2`. Each fold fit only on the preceding eight quarters, purged TRAIN
labels crossing its boundary, and retained only OOS labels ending inside the
quarter.

The model failed decisively despite passing every integrity and concentration
check. Mean daily OOS IC was `-0.0485`, only `1 / 6` quarters had positive IC,
top-minus-bottom relative h5 outcome averaged `-129.5 bp`, and only `1 / 6`
quarters ordered positively. Its IC lift versus the best frozen comparator was
`-0.0965`.

Raw group-relative momentum remained the strongest frozen comparator with mean
IC `0.0479`, positive quarterly IC in `4 / 6`, and mean top-minus-bottom
relative h5 outcome `+72.3 bp`, although its ordering was positive in only
`3 / 6`. The fixed 50/50 composite was weaker and its maximum group share was
`51.1%`, narrowly above the frozen cap.

Record `STOP_X2A_MULTIVARIATE_RANKING`. The sign and magnitude instability in
the TRAIN-only coefficients is evidence against adding model complexity here.
Do not tune weights, interactions, regularization, nonlinear models, or a
top-five portfolio on these inspected outcomes.

## C1 Portfolio-Risk Forecasting Audit

The next theory session corrected the role of the exposure layer. C1 did not ask
OHLCV market internals to predict five-day return direction. It asked whether
stress measurements available after close `t` could order the realized
volatility of an executable equal-weight reference basket over the next `h5`
and `h20` open-to-open sessions.

The four frozen stress measurements were trailing 20-session basket realized
volatility, 20-session SPY downside volatility, SPY drawdown from its trailing
126-session high, and 60-session average cross-sectional correlation. Each fold
used the preceding eight-quarter TRAIN median to define its high-stress state.
Promotion required positive mean correlation and high-minus-low risk separation,
at least `12 / 20` positive-correlation folds and `12 / 20` positive-separation
folds, and a 25%-75% high-state share at both horizons.

The first pre-interpretation render reused X1's 20-name cross-sectional minimum
and therefore blanked most of 2023Q3 when only 18-19 names were individually
eligible. That rule protects ranking breadth but is not necessary for a risk
reference basket. The authority packet instead freezes a minimum of 18 of the
24 individually point-in-time-eligible names. The discarded render is not used
as evidence.

Only SPY 126-session drawdown passed one horizon. At `h5` it produced positive
rank correlation in `18 / 20` folds, positive high-minus-low separation in
`12 / 20`, mean fold rank correlation `0.244`, annualized realized-volatility
separation `+0.082`, and a 43.9% high-state share. At `h20` it fell to `9 / 20`
positive-correlation folds, `7 / 20` positive-separation folds, and mean
correlation `0.002`.

Trailing basket volatility, SPY downside volatility, and average correlation
all failed at least one stability and direction gate at each horizon. C1 is
therefore `STOP_BEFORE_RISK_SCALER_DESIGN`. The result supports a possible
short-horizon drawdown-risk mechanism, but it does not authorize a continuous
scaler by deleting the predeclared `h20` requirement after inspection.

## C2 Option-Implied Risk Audit

C2 opened one genuinely different, retail-accessible risk input: the official
Cboe VIX close. A credentialed preflight through the existing Alpaca stock-bars
provider returned zero rows for `VIX` while returning seven rows for `VIXY` in
the same window. `VIXY` was not accepted as a substitute because it is a traded
rolling VIX-futures ETF rather than the Cboe VIX index. Alpaca remains the
adjusted daily OHLCV authority; Cboe is isolated as a research-only index-data
provider.

The provider audit accepted 1,780 official VIX rows from 2018-01-02 through
2024-12-31, matched 100% of evaluation sessions without filling, admitted no
future rows, and passed all nine leakage checks. C2 then reused the C1 basket,
execution timing, 20 quarterly folds, eight-quarter TRAIN windows, and h5/h20
forward realized-risk targets. The only feature was the same-session VIX close.

VIX passed continuous risk ordering at both horizons. Direct rank correlation
was positive in `15 / 20` folds at h5 and `12 / 20` at h20, with mean
correlations `0.272` and `0.131`. Partial rank correlation controlling for SPY
drawdown was positive in `15 / 20` folds at both horizons, with means `0.155`
and `0.220`. The information is therefore not merely a restatement of trailing
equity drawdown.

The frozen TRAIN-median high/low state did not transport. High-minus-low future
risk was positive in only `10 / 20` h5 folds and `8 / 20` h20 folds, below the
required `12 / 20`, even though pooled separation remained positive. C2 is
therefore `STOP_THRESHOLD_INSTABILITY`. It admits VIX as continuous measurement
evidence but does not authorize threshold search, a scaler, target volatility,
allocation, replay, or live behavior.

## Artifacts

- Packet: `runs/research_workbench/gen54_ml_decision_engine/g54_xs_20260719x0x1/`
- Report: `runs/research_workbench/gen54_ml_decision_engine/g54_xs_20260719x0x1/xs_report.md`
- Feature verdicts: `runs/research_workbench/gen54_ml_decision_engine/g54_xs_20260719x0x1/xs_feature_verdict.csv`
- Leakage audit: `runs/research_workbench/gen54_ml_decision_engine/g54_xs_20260719x0x1/xs_leakage_audit.csv`
- Deck: `presentations/gen5_4_cross_sectional_asset_selection_poc_plan_and_x1_evidence.pptx`
- Dialogue provenance: `docs/GEN5_4_DECISION_DIALOGUE_INDEX.md`
- X1b/C0 packet: `runs/research_workbench/gen54_ml_decision_engine/g54_xs_x1b_c0_20260719/`
- C1 authority packet: `runs/research_workbench/gen54_ml_decision_engine/g54_xs_c1_risk_20260719v2/`
- C1 deck: `presentations/gen5_4_cross_sectional_c1_risk_evidence_update.pptx`
- C2 authority packet: `runs/research_workbench/gen54_ml_decision_engine/g54_c2_vix_risk_20260721/`
- C2 deck: `presentations/gen5_4_c2_option_implied_risk_evidence_update.pptx`
- X2a contract: `docs/GEN5_4_CROSS_SECTIONAL_X2A_LINEAR_RANKER_CONTRACT.md`
- X2a authority packet: `runs/research_workbench/gen54_ml_decision_engine/g54_xs_x2a_20260726/`
- X2a deck: `presentations/gen5_4_cross_sectional_x2a_linear_ranker_evidence.pptx`

## Current Boundary

X2a authorized and completed one ranking-only linear model, then stopped it.
No top-K portfolio, exposure scaler, allocation method, performance acceptance,
or live behavior is authorized by X0/X1, X1b/C0, X2a, C1, or C2. The ranking
architecture is `STOP_X2A_MULTIVARIATE_RANKING`; the two-stage design remains
closed. The risk lane has multi-horizon continuous VIX evidence but remains
stopped before scaler design because its frozen state conversion was unstable.
The separate event-conditioned lane passed E0 point-in-time information-cycle
construction and then completed one frozen E1 development audit. E1 produced
`465` non-overlapping signals across all issuers and quarters, but only `26.2%`
received a same-issuer zero-news price-pattern control against the frozen `70%`
minimum. Record `STOP_E1_DEVELOPMENT_MECHANICS`. This does not reopen X2a,
authorize event-conditioned ranking, or permit post-result relaxation of the
control design.
