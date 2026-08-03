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

## Current lane

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

Generated packets live under
`runs/research_workbench/operator_hypothesis_lab/` and remain ignored research
artifacts.
