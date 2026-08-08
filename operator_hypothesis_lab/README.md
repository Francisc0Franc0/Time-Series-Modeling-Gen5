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

Generated packets live under
`runs/research_workbench/operator_hypothesis_lab/` and remain ignored research
artifacts.
