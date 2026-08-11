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

Generated packets live under
`runs/research_workbench/operator_hypothesis_lab/` and remain ignored research
artifacts.
