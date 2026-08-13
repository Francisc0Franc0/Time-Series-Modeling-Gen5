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

The approved, documentation-only
[intraday momentum roadmap](../docs/GEN5_INTRADAY_MOMENTUM_RESEARCH_ROADMAP.md)
records the next planned series without opening execution. It preserves four
separate estimands: daily SMA8/SMA14 reconstruction (`HYP-MOM-06.1`), its
30-minute counterpart (`HYP-IMOM-01.1`), a session-scaled 30-minute price/SMA
cross (`HYP-IMOM-02.1`), and a literature-derived 30-minute Chan momentum lane
(`LIT-IMOM-01.1`). Every policy is planned at 1x and fixed-quantity 1.8x, but
only 1x TRAIN evidence may select parameters. The 1.8x layer must be compared
with same-leverage ownership and timing controls under explicit financing and
margin-risk accounting. Intraday data collection, implementation, outcomes,
and regime-filter construction remain closed until a later explicit command.

Generated packets live under
`runs/research_workbench/operator_hypothesis_lab/` and remain ignored research
artifacts.
