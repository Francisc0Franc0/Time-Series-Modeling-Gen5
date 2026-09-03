# Operator Hypothesis Lab

This area contains minimal quantitative hypotheses that originate in the
operator's own observations and questions. It is intentionally separate from:

- mainline Gen5.x system and pipeline research; and
- `literature_studies/`, whose primary hypotheses come from published sources.

The lab permits fast, technical, and sometimes freeform discovery while
preserving explicit evidence labels. Reusing an inspected window is acceptable
only in `DISCOVERY`; it never becomes fresh validation through repetition.

## Evidence stages

1. `DISCOVERY_REUSED_WINDOW`: learn the mechanics, inspect distributions and
   tapes, and generate candidate explanations. No promotion authority.
2. `FROZEN_REPLICATION`: freeze signal, timing, exits, costs, universe, metrics,
   and selection before testing a wider or otherwise distinct dataset.
3. `UNTOUCHED_VALIDATION`: evaluate only a small number of predeclared
   survivors on untouched assets or time. Stronger claims begin here, not in
   discovery.

Every result must name its evidence stage. Exploratory variants and failed
questions remain part of the record.

## Current lanes

`HYP-MOM-01.1` asks what happens after two consecutive completed daily candles
both gap above the prior close and finish green. The discovery rule observes
the second completed candle after close, enters at the next open, and exits
after five open-to-open intervals. It is long-only and evaluated separately
for each asset; it does not define a portfolio or live behavior.

See the [nomenclature](docs/OPERATOR_HYPOTHESIS_LAB_NOMENCLATURE.md) and
[discovery contract](docs/HYP_MOM_01_1_TWO_GREEN_GAP_UPS_DISCOVERY_CONTRACT.md).
The completed [discovery readout](docs/HYP_MOM_01_1_TWO_GREEN_GAP_UPS_DISCOVERY_RESULTS.md)
records `DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY`: the rule produced a
slight majority of winning trades, but its losing tail made mean expectancy
negative and ordinary ownership/random-timing controls were unfavorable.

The follow-up [Diagnostic Atlas 01 contract](docs/HYP_MOM_01_1_DIAGNOSTIC_ATLAS_01_CONTRACT.md)
and [results](docs/HYP_MOM_01_1_DIAGNOSTIC_ATLAS_01_RESULTS.md) test
volatility-scaled gap/body properties, SMA200 location, 20/60/120-session
momentum, pattern maturity, volume, 60-session-high proximity, SPY context,
and within-trade checkpoints without changing the parent strategy. No entry
filter showed stable cross-asset separation. SPY-above-SMA200 is retained only
as the strongest candidate for a distinct frozen replication question.
The [diagnostic evidence deck](presentations/hyp_mom_01_1_diagnostic_atlas_01_evidence.pptx)
records the scaling formulae, complete conditional atlas, representative trend
state tapes, and the boundary between observed discovery behavior and any
future replication hypothesis.

The [Stock Atlas 02 breadth contract](docs/HYP_MOM_01_1_STOCK_ATLAS_02_BREADTH_EXTENSION_CONTRACT.md)
reuses a previously frozen 100-name stock registry and applies the unchanged
strategy plus Diagnostic Atlas 01 to every symbol that passes explicit history
and OHLCV coverage. The completed [breadth results](docs/HYP_MOM_01_1_STOCK_ATLAS_02_BREADTH_EXTENSION_RESULTS.md)
merge 94 eligible additions with the original panel for 116 assets and 4,015
trades. The wider sample preserves the positive median and slight-majority hit
rate but also preserves negative mean expectancy and unfavorable ownership and
random-timing controls. The original normalized-gap and SPY-trend candidates
shrink materially in the added assets; no diagnostic is promoted. The
[breadth evidence deck](presentations/hyp_mom_01_1_stock_atlas_02_breadth_extension_evidence.pptx)
records the design, coverage, panel comparisons, diagnostic persistence,
path audit, and representative tapes.

`HYP-MOM-02.1` asks the deliberately narrow event question: what happens when
an asset starts in cash, enters only after a fresh adjusted-close cross above
its 200-session simple moving average inside the study window, and exits after
a fresh cross below? The completed
[wide discovery contract](docs/HYP_MOM_02_1_SMA200_CROSS_WIDE_DISCOVERY_CONTRACT.md)
freezes causal next-open state changes, long-only full-capital accounting,
5/10 bp per-side costs, buy-and-hold ownership, circular state-shift controls,
and the combined 122-name registered universe before interpreting outcomes.
The [results](docs/HYP_MOM_02_1_SMA200_CROSS_WIDE_DISCOVERY_RESULTS.md) cover
119 eligible assets and 1,624 round trips. The rule reduced maximum drawdown in
88 assets but beat ownership in only 26; its median actual timing ranked at the
27.4th percentile of exposure-matched circular shifts. It is therefore
recorded as a defensible defensive exposure filter, not a demonstrated generic
timing edge. The [evidence deck](presentations/hyp_mom_02_1_sma200_cross_wide_discovery_evidence.pptx)
explains the rule, return/protection tradeoff, right-skewed trade outcomes, matched
controls, and six representative path tapes.

`HYP-MOM-02.2` keeps the fresh SMA200 cross as the entry event but makes three
substantive changes: the signal close must also be above SMA50, the first close
at or below SMA50 triggers a next-open exit, and re-entry requires another
qualified SMA200 cross. The [frozen contract](docs/HYP_MOM_02_2_SMA200_ENTRY_SMA50_EXIT_DISCOVERY_CONTRACT.md)
and [wide discovery results](docs/HYP_MOM_02_2_SMA200_ENTRY_SMA50_EXIT_DISCOVERY_RESULTS.md)
retain the same 119 eligible assets and reused 2021-2023 window so the result is
a direct discovery comparison, not fresh validation. Relative to authoritative
fresh-cross `02.1`, median asset return changed by `+3.57` percentage points and
maximum drawdown improved by `+11.09` points, but median exposure fell to
`16.76%`, only `32 / 119` assets beat ownership, and exposure-matched timing
ranked at the `42.9th` percentile. The [evidence deck](presentations/hyp_mom_02_2_sma200_entry_sma50_exit_wide_discovery_evidence.pptx)
also shows why SMA50 was the earlier exit in only `155 / 637` matched entries.
The lane remains `WIDE_DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY`.

The approved [SMA follow-up series contract](docs/HYP_MOM_SMA_FOLLOWUP_SERIES_CONTRACT.md)
then separated entry confirmation, exit/lockout, and re-entry on the reused
2021-2023 panel before testing two fully predeclared ideas on distinct
2016-2020 history. The [Attribution Atlas 01 results](docs/HYP_MOM_02_ATTRIBUTION_ATLAS_01_RESULTS.md)
show that the faster SMA50 exit/lockout produced most of `02.2`'s defensive
change; the SMA50 entry check added little, and the simple reclaim re-entry
deteriorated at the median. The [attribution deck](presentations/hyp_mom_02_attribution_atlas_01_evidence.pptx)
also records fixed-horizon event behavior and three representative repair
paths.

The companion [development results](docs/HYP_MOM_02_3_03_1_DEVELOPMENT_RESULTS.md)
compare `HYP-MOM-02.3` with strict `02.2` and `HYP-MOM-03.1` with fresh
`02.1` across 114 complete historical names. Both candidates had positive raw
median returns but negative exposure-matched timing excess. `02.3` also missed
parent-improvement breadth and worsened drawdown; `03.1` improved drawdown but
gave up nine median return points versus its parent. The [development deck](presentations/hyp_mom_02_3_03_1_development_evidence.pptx)
records the frozen gate matrix and six tapes. Neither candidate advanced, so
the context atlas and 2024-2025 confirmation were structurally not run and
2026+ remained sealed.

`HYP-MOM-04.1` then opened the lab's first deliberately small supervised
quarterly ranker. The [frozen contract](docs/HYP_MOM_04_1_REGULARIZED_TREND_STATE_QUARTILE_CONTRACT.md)
predeclared six trend-state features, relative next-quarter return, a
time-ordered ridge search, seven TRAIN gates, and a structural OOS lock. The
[TRAIN results](docs/HYP_MOM_04_1_REGULARIZED_TREND_STATE_QUARTILE_RESULTS.md)
cover 114 eligible identities and 1,693 asset-quarters. The pooled fit showed a
`+2.98` point top-quartile excess and ranked at the `98.8th` permutation
percentile, but expanding-validation rank IC was `-0.0176` and positive in only
`5 / 9` quarters. The lane records `STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN`;
2021-2023 remained inaccessible. The
[evidence deck](presentations/hyp_mom_04_1_regularized_trend_state_quartile_evidence.pptx)
shows the frozen formulas, evidence boundary, pooled-fit temptation,
chronological failure, gate conjunction, and the one comparator worth a future
separately frozen discussion.

The proposed S&P 500 sub-lane then stopped at its point-in-time data gate before
any model fit. Its [frozen audit contract](docs/HYP_MOM_04_1_SP500_PIT_DATA_AUDIT_CONTRACT.md)
cross-checked a pinned public membership ledger against 15 contemporaneous
Wikipedia revisions and audited Alpaca coverage through 2020 only. The
[results](docs/HYP_MOM_04_1_SP500_PIT_DATA_AUDIT_RESULTS.md) cover 591 source
identities and 7,580 member-quarter rows. Ordinary bar coverage passed, but
early later-alias mismatches reduced roster agreement to `0.9555`, sector
coverage fell to `97.63%`, and `39` frozen target-quarter exits lacked a
defensible terminal return. The
[audit deck](presentations/hyp_mom_04_1_sp500_pit_data_audit_evidence.pptx)
records `STOP_SP500_PIT_DATA_GATES_FAILED_REPLICATION_NOT_RUN`; no Ridge model
or 2021+ outcome was queried.

The follow-up [source-repair audit](docs/HYP_MOM_04_1_SP500_PIT_SOURCE_REPAIR_RESULTS.md)
queried Alpaca's official corporate-actions endpoint for the 39 unresolved
identities. It returned relevant records for only eight, leaving at least 31
terminal targets unresolved even under the most favorable interpretation. No
S&P DJI, WRDS/CRSP, Norgate, or EODHD entitlement was present locally. The S&P
replication therefore remains stopped.

The approved deployment-universe fallback required a point-in-time correction:
SPY's `2020-12-31` holdings were filed only in February 2021, so the
[frozen contract](docs/HYP_MOM_04_1_DEPLOYMENT_UNIVERSE_DATA_AUDIT_CONTRACT.md)
instead used the September 2020 SPY Form N-PORT cohort filed in November 2020.
The [results](docs/HYP_MOM_04_1_DEPLOYMENT_UNIVERSE_RESULTS.md) reconcile
`502/505` identities without a later roster and retain `481/505` exact
2016-2020 histories; all nine data gates passed. The unchanged Ridge TRAIN then
produced `+1.45` pp pooled top-quartile excess and a 100th-percentile
permutation result, but expanding-validation IC was `-0.0623` and positive in
only `4/9` held-out quarters. The
[evidence deck](presentations/hyp_mom_04_1_deployment_universe_evidence.pptx)
records `STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN`; no 2021-2023 bar was queried.

`HYP-MOM-04.2` then froze a derivative feature-atlas question on the same 481
eligible identities and unchanged TRAIN/OOS boundary. The
[contract](docs/HYP_MOM_04_2_FEATURE_ATLAS_CONTRACT.md) registered 33 causal
OHLCV features across seven economic families, nine predefined candidates,
two nested outer blocks, and a 200-draw full-search permutation control before
outcomes. The [results](docs/HYP_MOM_04_2_FEATURE_ATLAS_RESULTS.md) show why
scatterplots are useful but insufficient: pooled beta and realized-volatility
deciles looked mildly attractive, while classic 12-to-1 momentum was flat;
quarter-aware signs nevertheless reversed repeatedly. Every candidate's best
inner-validation mean IC was negative. Nested outer mean IC was `-0.1071`,
top-quartile excess was `-2.23` pp, and the search-adjusted p-value was `1.000`.
The [evidence deck](presentations/hyp_mom_04_2_feature_atlas_evidence.pptx)
records `STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN`; no 2021+ observation was
queried. Rebuild human-facing visuals from retained CSVs with
`scripts/render_hyp_mom_04_2_feature_atlas_evidence.R`.

`HYP-MOM-04.3A` then audited the prediction target itself rather than adding
features. Its [frozen contract](docs/HYP_MOM_04_3A_TARGET_STRUCTURE_AUDIT_CONTRACT.md)
compared the implemented universe-relative target with sector-relative and
sector-plus-beta-residual targets using only the retained H04.2 TRAIN panel.
The [results](docs/HYP_MOM_04_3A_TARGET_STRUCTURE_AUDIT_RESULTS.md) show that
sector alone explained `16.7%` of next-quarter cross-sectional variation on
average, while sector plus prior beta explained `21.4%` and `46.2%` in the
beta-dominated `2020Q3` quarter. Sector neutralization changed about one-third
of realized top-quartile membership and reduced the average largest-sector
share from `22.7%` to `16.7%`. Several apparent risk relationships shrank or
reversed after neutralization. The dedicated
[evidence deck](presentations/hyp_mom_04_3a_target_structure_audit_evidence.pptx)
records `TARGET_AUDIT_COMPLETE_SELECTION_NOT_FROZEN`; it recommends
sector-relative return for the next target-selection discussion but does not
freeze a target, fit a model, or open OOS.

The operator then froze that recommendation in `HYP-MOM-04.3B`. The
[replication contract](docs/HYP_MOM_04_3B_SECTOR_RELATIVE_REPLICATION_CONTRACT.md)
kept the 2017Q1-2020Q3 TRAIN panel, fixed one four-feature Ridge model and two
comparators, opened only 2021Q1-2023Q3 DEVELOPMENT, and sealed 2024+. A bounded
refresh retained 479 signal-eligible identities and reconciled all 5,124 rows,
including a documented 26-row terminal policy. The
[results](docs/HYP_MOM_04_3B_SECTOR_RELATIVE_REPLICATION_RESULTS.md) are a clean
negative replication: mean IC `-0.0342`, only `3 / 11` positive IC quarters,
and mean top-quartile sector-relative return `-0.582%`. Prior sector-relative
momentum alone was less negative but still insufficient. The
[evidence deck](presentations/hyp_mom_04_3b_sector_relative_replication_evidence.pptx)
records `STOP_DEVELOPMENT_REPLICATION_FAILED_CONFIRMATION_NOT_RUN`; 2024+
confirmation remains sealed.

`HYP-MOM-04.3C` then explained that failure without fitting another model. Its
[diagnostic contract](docs/HYP_MOM_04_3C_FEATURE_TRANSPORT_AUDIT_CONTRACT.md)
reused the same 5,124 DEVELOPMENT rows and audited only the four frozen inputs.
The [results](docs/HYP_MOM_04_3C_FEATURE_TRANSPORT_AUDIT_RESULTS.md) show no
coherent feature: sector momentum's upper quartile averaged `+0.302%` but its
top decile averaged `-0.665%`; positive-month fraction was broad across sectors
but economically tiny and non-monotonic; and trend R2 transported with a
negative sign. Three of four frozen TRAIN coefficient signs disagreed with
DEVELOPMENT marginal IC signs. Terminal-row exclusions did not change the
answer. The
[evidence deck](presentations/hyp_mom_04_3c_feature_transport_audit_evidence.pptx)
records `FEATURE_TRANSPORT_AUDIT_COMPLETE_NO_PROMOTION_AUTHORITY`; no 2024+
observation was accessed.

`HYP-ALT-01.1` opens a separate alternative-data measurement lane: a forward
daily ticker-attention tape from approved `r/wallstreetbets` comment access.
The [collection contract](docs/HYP_ALT_01_1_WSB_FORWARD_COLLECTION_CONTRACT.md)
freezes official OAuth access, two-minute overlap-based polling, a current
Alpaca active-US-equity/ETF registry, cashtag and constrained bare-symbol
recognition, no durable raw text or usernames, deletion reconciliation, and
visible coverage states. The
[readiness report](docs/HYP_ALT_01_1_WSB_FORWARD_COLLECTION_READINESS.md)
records `IMPLEMENTED_STOP_LIVE_REDDIT_ACCESS_NOT_CONFIGURED`: 14,227 active
symbols were registered and the fixture suite passes, but no Reddit approval
attestation or OAuth credentials are present, so no live Reddit request or
attention database has been claimed. This lane contains no sentiment, return,
strategy, portfolio, or live-advice authority.

`HYP-MOM-05.1` returns to a minimal formulaic trend question: fresh
`SMA15 > SMA30 > SMA45` activation enters, close at or below SMA30 exits, and
only a fresh SMA30 reclaim while ordered can re-enter. Its
[contract](docs/HYP_MOM_05_1_TRIPLE_SMA_PULLBACK_CONTRACT.md) freezes causal
next-open execution, a 122-stock registry, 1x and fixed-quantity 1.8x debt,
frictions, four economic baselines, and 500 exposure-matched circular shifts.
The [results](docs/HYP_MOM_05_1_TRIPLE_SMA_PULLBACK_RESULTS.md) retain 120
eligible assets after refresh and show a broad negative result: 1x median
return `-3.44%`, median hit rate `29.29%`, and only `10 / 120` assets above the
80th timing-control percentile. Reclaims supplied `979 / 1,099` trades and had
a three-session median hold. The
[evidence deck](presentations/hyp_mom_05_1_triple_sma_pullback_wide_discovery_evidence.pptx)
records `WIDE_DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY`; keep 2024+ sealed and
do not tune the inspected mechanics or promote leverage.

`HYP-MOM-05.2` asks whether a training-only selector can rescue that family
without expanding its mechanics. Its
[contract](docs/HYP_MOM_05_2_TRIPLE_SMA_GRID_WFA_CONTRACT.md) freezes 27
`fast / medium / slow` triplets, six half-year blocks, four expanding outer
tests, a five-component rank score, a one-standard-error plateau, and a
low-turnover tie-break. The
[results](docs/HYP_MOM_05_2_TRIPLE_SMA_GRID_WFA_RESULTS.md) retain 119 assets
and show a stronger negative result: selected horizons progressed from
`15/30/90` to `20/50/120`, but all four test blocks had non-positive median
return. The 1x median compounded return was `-7.25%`, only `34 / 119` assets
were positive, and the median matched-shift percentile was `15%`. Only the
integrity gate passed. The evidence deck records
`STOP_DEVELOPMENT_WFA_FAILED_CONFIRMATION_NOT_RUN`; keep 2024+ sealed and do
not widen the grid or select favorable cells, assets, sectors, or cohorts.

The completed
[intraday momentum roadmap](../docs/GEN5_INTRADAY_MOMENTUM_RESEARCH_ROADMAP.md)
preserves four
separate estimands: daily SMA8/SMA14 reconstruction (`HYP-MOM-06.1`), its
30-minute counterpart (`HYP-IMOM-01.1`), a session-scaled 30-minute price/SMA
cross (`HYP-IMOM-02.1`), and a literature-derived 30-minute Chan momentum lane
(`LIT-IMOM-01.1`). Every policy is evaluated at 1x and fixed-quantity 1.8x, but
only 1x TRAIN evidence may select parameters. The 1.8x layer must be compared
with same-leverage ownership and timing controls under explicit financing and
margin-risk accounting. The
[series results](docs/GEN5_INTRADAY_MOMENTUM_POC_SERIES_RESULTS.md) retain the
daily rule as the only positive absolute-return baseline, stop all three
intraday lanes before confirmation, and pause before any regime-filter design.
The 2024+ interval remains sealed.

`HYP-REG-01.1` opens the lab's first strategy-independent volatility-regime
diagnostic after that momentum series. The
[frozen contract](../docs/GEN5_HYP_REG_01_1_ATR_PERCENT_VOLATILITY_POC_CONTRACT.md)
defines causal Wilder ATR(14) as a percentage of close, a prior-252-session
percentile, and 30/40 plus 60/70 hysteresis. The
[results](docs/HYP_REG_01_1_ATR_PERCENT_VOLATILITY_RESULTS.md) retain all 26
assets over 2018-2023. Every asset had higher future normalized range in
`HIGH` than `LOW` at 1-, 5-, and 20-session horizons; median non-overlapping
Spearman association increased from `0.409` at H1 to `0.514` at H20. The
[evidence deck](presentations/hyp_reg_01_1_atr_percent_volatility_evidence.pptx)
records the causal timing, formulas, state dynamics, fixed benchmark
comparison, sensitivity, and representative state tapes. The lane records
`DIAGNOSTIC_COMPLETE_STOP_BEFORE_STRATEGY_OVERLAY`: no strategy outcome was
calculated, 2024+ remains sealed, and any momentum gate requires a separately
frozen test.

`HYP-REG-01.2` is that separately frozen first overlay. The
[contract](../docs/GEN5_HYP_REG_01_2_ATR_PERCENT_STRATEGY_OVERLAY_CONTRACT.md)
keeps the accepted ATR14/P252/hysteresis classifier and the accepted daily
SMA8/SMA14 parent strategy unchanged. It skips only fresh entries whose
signal-close state is `LOW`, compares against the unfiltered rule and 40
exposure-nearest circular-state controls, and keeps 2024+ sealed. The
[results](docs/HYP_REG_01_2_ATR_PERCENT_STRATEGY_OVERLAY_RESULTS.md) show a
drawdown improvement but a median return reduction from `8.95%` to `4.44%`,
only `9 / 24` assets improved, `0 / 6` positive-excess years, lower Sharpe,
and a `37.5th`-percentile placebo result. The
[evidence deck](presentations/hyp_reg_01_2_atr_percent_strategy_overlay_evidence.pptx)
records `STOP_DEVELOPMENT_OVERLAY_GATES_FAILED_CONFIRMATION_NOT_RUN`. This does
not reverse the successful diagnostic; it rejects `ATR_LOW_OFF` for this one
momentum policy.

`HYP-REG-02.1` then tests a separate direction axis before allowing any joint
state map. The
[contract](../docs/GEN5_HYP_REG_02_TREND_DIRECTION_DIAGNOSTIC_CONTRACT.md)
freezes `log(SMA20/SMA60)`, next-open H5/H20/H63 direction targets,
horizon-spaced non-overlap, two descriptive comparators, seven gates, 200
within-asset/year circular controls, and a conditional exact join to the
accepted ATR% ledger. The
[results](docs/HYP_REG_02_1_TREND_DIRECTION_DIAGNOSTIC_RESULTS.md) reject the
score cleanly: panel-median Spearman was `-0.048`, `-0.166`, and `-0.155`,
H20/H63 balanced accuracy was `0.452`, every long-horizon calendar-year median
was negative, and both actual alignments ranked at the `0th` control
percentile. The
[evidence deck](presentations/hyp_reg_02_1_trend_direction_diagnostic_evidence.pptx)
records `STOP_TREND_DIRECTION_GATES_FAILED_JOINT_NOT_RUN`. Only integrity
passed; the ATR complementarity audit did not run, no sign was reversed after
inspection, and 2024+ remains sealed.

`HYP-REG-03.1` then asks whether market breadth can supply information that the
rejected single-asset direction score missed. The
[contract](../docs/GEN5_HYP_REG_03_CROSS_SECTIONAL_BREADTH_TREND_CONTRACT.md)
uses ten long-lived sector ETFs as a transparent, survivorship-safe proxy for
point-in-time constituent breadth. Median sector `log(close/SMA20)` is the
continuous score, fraction above SMA20 is the literal diffusion companion,
and its 20-session change measures decay. The
[results](docs/HYP_REG_03_1_CROSS_SECTIONAL_BREADTH_RESULTS.md) retain one
interesting H20 clue: 19/26 targets had positive association, the median Q5-Q1
spread was +1.783%, and weakening breadth inside a positive SPY price trend
preceded a -0.936 pp return gap. But actual H20 timing ranked only at the 56th
control percentile, while H63 reversed to -0.382 with 0/26 positive targets.
Only integrity passed. The
[evidence deck](presentations/hyp_reg_03_1_cross_sectional_breadth_evidence.pptx)
records `STOP_CROSS_SECTIONAL_BREADTH_GATES_FAILED_NO_JOINT_FILTER`; no ATR
join, strategy overlay, 2024+ access, or post-hoc inversion was allowed.

`HYP-REG-03.2` narrows that idea to the motivating divergence mechanism. The
[contract](../docs/GEN5_HYP_REG_03_2_BREADTH_TRANSITION_DIVERGENCE_CONTRACT.md)
defines `NARROWING` on positive-SPY-trend dates as both 20-session sector
breadth change and RSP/SPY leadership change below zero, with one unfitted
prior-relative score, continuous dispersion, a single causal H20 target, all
20 non-overlapping offsets, temporal and semantic audits, and circular timing
controls. A bounded RSP refresh produced complete 12-asset coverage. The
[results](docs/HYP_REG_03_2_BREADTH_TRANSITION_DIVERGENCE_RESULTS.md) show only
a -0.152 pp return gap, +3.802 pp DOWN-rate gap, 0.527 AUC, 7/20 stable offsets,
and ordinary circular-control timing. Narrowing was followed by +2.474 pp more
future breadth improvement, revealing rebound rather than persistent decay.
The
[evidence deck](presentations/hyp_reg_03_2_breadth_transition_divergence_evidence.pptx)
records `STOP_BREADTH_TRANSITION_GATES_FAILED_NO_JOINT_FILTER`; only integrity
passed and no leadership-only selection, threshold tuning, ATR join, strategy,
or 2024+ access was allowed.

`HYP-REG-04.1` opens a new market-context measurement family rather than
rescuing either breadth implementation. The
[candidate map](../docs/GEN5_CROSS_SECTIONAL_MARKET_CONTEXT_CANDIDATE_MAP.md)
explains how a future market field could sit beside per-asset ATR% and an
unchanged TSLA/AMD-style strategy, and records latent-market-mode,
economic-confirmation-network, and point-in-time constituent-breadth
alternatives without opening them. The
[contract](../docs/GEN5_HYP_REG_04_1_CROSS_SECTIONAL_TREND_FIELD_CONTRACT.md)
freezes equal-group direction, participation, 20/60 agreement, and five-session
flow across 24 diverse ETFs, with future field semantics primary and SPY only a
secondary external check. The
[results](docs/HYP_REG_04_1_CROSS_SECTIONAL_TREND_FIELD_RESULTS.md) show a
strong contrarian H20 result: broad-up minus broad-down future field return was
-1.575 pp, participation -17.5 pp, and SPY return -1.083 pp. Only integrity
passed (1/9). The evidence records
`STOP_TREND_FIELD_GATES_FAILED_NO_ATR_JOIN_OR_STRATEGY`; no inversion, ATR join,
asset-strategy overlay, threshold rescue, or 2024+ access is allowed.

`HYP-REG-04.2` is the separately frozen fast derivative of that failed field.
Its [contract](../docs/GEN5_HYP_REG_04_2_FAST_CROSS_SECTIONAL_TREND_IMPULSE_CONTRACT.md)
uses equal-group volatility-normalized five-session direction, five-session
participation and participation change, with 20-session direction only as a
continuation/reversal label. The
[results](docs/HYP_REG_04_2_FAST_CROSS_SECTIONAL_TREND_IMPULSE_RESULTS.md) show
that faster measurement did not restore continuity: H5 direction return and
participation gaps were only +0.058 pp/+0.833 pp, H10 reversed to
-0.247 pp/-8.750 pp, direction-return Spearman was -0.024, and only 2/5 H5
plus 2/10 H10 offsets were jointly positive. Only integrity passed (1/10).
Record
`STOP_FAST_TREND_IMPULSE_GATES_FAILED_NO_CONFIRMATION_ATR_JOIN_OR_STRATEGY`;
do not shorten again, select the favorable local impulse slice, join ATR%, run
a strategy, or access 2024+ under this family.

`HYP-REG-05.1` changes the question from signed direction to path
trendability. Its
[contract](../docs/GEN5_HYP_REG_05_1_PATH_TRENDABILITY_DIAGNOSTIC_CONTRACT.md)
freezes Kaufman ER(20) as the primary candidate and Wilder ADX(14) as the
canonical benchmark, both expressed as causal prior-252-session
asset-relative percentiles. The
[results](docs/HYP_REG_05_1_PATH_TRENDABILITY_RESULTS.md) show that neither
candidate predicted a straighter next-open H10/H20 path: H10 median
per-asset rho was `-0.023` for ER and `-0.049` for ADX, with HIGH/LOW future
efficiency ratios of `0.956x` and `0.966x`. ER did retain a `+5.5 pp`
direction-survival clue across `20 / 26` assets, while ADX alone formed usable
states (about 14 switches/year and an 11.5-session median run), but those
properties did not survive the complete path, offset, time, and circular
gates. The
[evidence deck](presentations/hyp_reg_05_1_path_trendability_evidence.pptx)
records `STOP_PATH_TRENDABILITY_GATES_FAILED_NO_ATR_JOIN_OR_STRATEGY`; do not
tune, invert, join ATR%, run a strategy, or access 2024+ under this lane.

`HYP-REG-05.2` then tests the operator's broader conceptual correction: a
state need not forecast its own future if its causal present value usefully
changes the next strategy decision. Its
[contract](../docs/GEN5_HYP_REG_05_2_ADX_STRATEGY_RELATIVE_OVERLAY_CONTRACT.md)
joins the accepted ADX state to the unchanged daily SMA8/SMA14 parent, with
HIGH-only fresh entry as primary and exit-on-leaving-HIGH as a predeclared
challenger. The
[results](docs/HYP_REG_05_2_ADX_STRATEGY_RELATIVE_OVERLAY_RESULTS.md) show a
real but insufficient entry clue: HIGH parent entries had a 2.01% mean trade,
and actual entry-only timing ranked at the 85th percentile of exposure-near
controls. The hard gate nevertheless reduced 1,394 parent trades to 347, cut
median return from 8.95% to 1.95%, lowered Sharpe, and improved only 8/24
assets. Reactive exit was weaker and ranked at the 15th timing percentile. The
[evidence deck](presentations/hyp_reg_05_2_adx_strategy_relative_overlay_evidence.pptx)
records `STOP_ADX_STRATEGY_RELATIVE_GATES_FAILED_CONFIRMATION_NOT_RUN`; do not
soften, tune, stack another filter, select favorable slices, or access 2024+.

The next trend-measurement sequence is bookmarked in the
[trend-indicator POC roadmap](../docs/GEN5_TREND_INDICATOR_POC_ROADMAP.md).
It preserves five genuinely different questions—return persistence, robust
slope/fit, multi-horizon agreement, causal trend onset, and range-break
persistence—under one common causal and strategy-relative protocol.

`HYP-REG-08.1` completed the first roadmap candidate. Its
[contract](../docs/GEN5_HYP_REG_08_1_VARIANCE_RATIO_CONTRACT.md) freezes robust
overlapping Lo–MacKinlay VR(5), VR(10) durability, two causal 252-session
windows, signed hysteresis, synthetic calibration, and one HIGH-only fresh
entry gate on the unchanged SMA8/SMA14 parent. The
[results](docs/HYP_REG_08_1_VARIANCE_RATIO_RESULTS.md) distinguish a clean
measurement pass from a policy failure: all 7/7 construction gates passed,
but only 3/9 strategy gates passed. Median annual return and exposure were
both zero, only 1/24 stocks and 1/6 years improved, HIGH did not select better
parent trades, and timing ranked at the 50th percentile. The
[evidence deck](presentations/hyp_reg_08_1_variance_ratio_persistence_evidence.pptx)
records
`STOP_VARIANCE_RATIO_STRATEGY_RELATIVE_GATES_FAILED_CONFIRMATION_NOT_RUN`.
Retain the measurement, do not rescue the hard gate, and keep 2024+ sealed.
That STOP opened the separately frozen T2 robust slope/fit discussion; the
completed T2 readout follows.

`HYP-REG-09.1` completed the second roadmap candidate. Its
[contract](../docs/GEN5_HYP_REG_09_1_ROBUST_SLOPE_FIT_CONTRACT.md) freezes a
60-session Theil-Sen log-price slope, volatility-normalized strength,
independent absolute-Spearman path quality, a causal prior-252 quality state,
and a 120-session durability view. The
[results](docs/HYP_REG_09_1_ROBUST_SLOPE_FIT_RESULTS.md) separate another clean
measurement pass from a policy failure: all 7/7 construction gates passed,
but only 3/9 strategy gates passed. The positive-slope HIGH-quality entry gate
cut median annual return from 8.95% to -0.11%, improved only 2/24 stocks and
1/6 years, produced negative Sharpe, and ranked at the 26.2nd percentile of
exposure-nearest controls. The
[evidence deck](presentations/hyp_reg_09_1_robust_slope_fit_evidence.pptx)
records
`STOP_ROBUST_SLOPE_FIT_STRATEGY_GATES_FAILED_CONFIRMATION_NOT_RUN`. Retain the
descriptive measurement, do not rescue the binary gate, and keep 2024+
sealed.

`HYP-REG-10.1` completed the third roadmap candidate. Its
[contract](../docs/GEN5_HYP_REG_10_1_MULTI_HORIZON_AGREEMENT_CONTRACT.md)
freezes volatility-normalized log-price displacement signs over 20, 60, and
120 sessions, a five-state agreement/opposition taxonomy, descriptive
short-joins events, and one `FULL_UP` fresh-entry gate on the unchanged
SMA8/SMA14 parent. The
[results](docs/HYP_REG_10_1_MULTI_HORIZON_AGREEMENT_RESULTS.md) show another
clean measurement pass but a decisive policy failure: all 7/7 construction
gates passed, while only 3/9 strategy gates passed. Median annual return fell
from 8.95% to -0.68%, only 1/24 stocks and 1/6 years improved, Sharpe became
negative, and actual timing ranked at the 12.5th percentile of exposure-near
controls. The
[evidence deck](presentations/hyp_reg_10_1_multi_horizon_agreement_evidence.pptx)
records
`STOP_MULTI_HORIZON_AGREEMENT_STRATEGY_GATES_FAILED_CONFIRMATION_NOT_RUN`.
Retain the state ledger, do not rescue the policy, and keep 2024+ sealed. The
next roadmap gate was T4 causal change-point discussion.

`HYP-REG-11.1` completed that fourth candidate. Its
[contract](../docs/GEN5_HYP_REG_11_1_CAUSAL_CHANGE_POINT_CONTRACT.md) freezes
prior-20 volatility standardization, three-sigma clipping, a Page-style
positive CUSUM allowance of 0.10, a synthetic-only false-alarm calibration,
and one fixed ten-session post-alarm entry-eligibility window. The
[results](docs/HYP_REG_11_1_CAUSAL_CHANGE_POINT_RESULTS.md) document a Stage A
STOP: null specificity, falsification, causality, scale invariance, and event
semantics passed, but only 40.7% of strong positive shifts were detected
within 60 sessions, the median timely delay was 45 sessions, only 2/24 stocks
had three alarms, and no stock had an eligible fresh SMA cross. The
[evidence deck](presentations/hyp_reg_11_1_causal_change_point_evidence.pptx)
records `STOP_CAUSAL_CHANGE_POINT_STAGE_A_FAILED_STRATEGY_NOT_RUN`. Strategy
performance and 2024+ were not accessed. T5 breakout persistence is the next
discussion gate; its `HYP-REG` versus `HYP-MOM` taxonomy must be decided before
freezing. If the full T1–T5 series produces no promotion, a separate
literature-first HMM discussion remains bookmarked but not opened.

`HYP-REG-12.1` completed the fifth and final candidate in that roadmap. Its
[contract](../docs/GEN5_HYP_REG_12_1_RANGE_PERSISTENCE_CONTRACT.md) classifies
the current close in the preceding 63-session range and requires three of five
upper-quartile observations for `UPPER_PERSISTENT`. A separate fixed-boundary
event ledger audits breakout hold and failure without creating entries. The
[results](docs/HYP_REG_12_1_RANGE_PERSISTENCE_RESULTS.md) show a clean 7/7
measurement pass but a 3/9 strategy result: median annual return fell from
8.95% to 0.00%, only 1/24 stocks and 1/6 years improved, Sharpe became
negative, and timing ranked at the 61.3rd percentile. The
[evidence deck](presentations/hyp_reg_12_1_range_persistence_evidence.pptx)
records `STOP_RANGE_PERSISTENCE_STRATEGY_GATES_FAILED_CONFIRMATION_NOT_RUN`.
Retain the measurement, do not rescue the hard gate or reinterpret it as a
direct breakout strategy, and keep 2024+ sealed. With T1-T5 complete and no
promotion, the literature-first HMM discussion is now the next gate; HMM
implementation remains unopened.

Generated packets live under
`runs/research_workbench/operator_hypothesis_lab/` and remain ignored research
artifacts.

`HYP-PORT-01.1` opens a separate portfolio-policy POC rather than an edge
claim. Its [frozen contract](docs/HYP_PORT_01_1_AGGRESSIVE_COMPOUNDING_CONTRACT.md)
compares a 50% SCHG / 20% QUAL / 15% XSD / 5% each AMD-NVDA-TSLA allocation
with the identical mix left untouched, equal-weight AMD/NVDA/TSLA, SCHG,
QQQM, and SPY over QQQM's actual common history. The
[results](docs/HYP_PORT_01_1_AGGRESSIVE_COMPOUNDING_RESULTS.md) show the
intended middle ground: 22.56% CAGR and -39.77% maximum drawdown versus
42.23% and -63.94% for the concentrated trio, and 17.29% and -36.69% for
QQQM. The [evidence deck](presentations/hyp_port_01_1_aggressive_compounding_poc.pptx)
shows growth, drawdown, rolling-window, calendar-return, and sleeve-drift
views. Rebalancing modestly reduced risk but did not add return. Preserve
`PORTFOLIO_POLICY_POC_COMPLETE_DESCRIPTIVE_ONLY`; this is not optimized,
confirmed, or live allocation authority.

The NVDA-specific descriptive lane begins with
`HYP-NVDA-CLOCK-01.1`. Its
[results note](docs/NVDA_INTRADAY_RETURN_CLOCK_2018_2023.md) and ignored run
packet `nvda_intraday_clock_descriptive_20260831` place the prior-close to
first-open gap before all 13 regular-session 30-minute open-to-close returns.
The 2018-2023 plot retains every eligible observation, removes no outliers,
fits no model, and leaves 2024+ untouched. It establishes a raw one-asset clock
anatomy surface only; no bar, threshold, strategy, or edge is selected.
