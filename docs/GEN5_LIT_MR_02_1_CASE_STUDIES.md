# LIT-MR-02.1 Positive-Control Case Studies

Status: `POSITIVE_CONTROL_DOCUMENTED_WITHOUT_REVERSING_STOP`

## Purpose

The canonical 2016-2020 TRAIN result and the two fixed pair panels remain
structural STOPs. This addendum answers a narrower educational question:

> Can the unchanged `LIT-MR-02.1` mechanism be shown working clearly in real
> daily data without retuning it or presenting a selected example as untouched
> validation?

Two positive controls are reported:

1. `LIT-MR-02.1 / CASESTUDY_2018`, an explicitly retrospective calendar-year
   view inside the already-open canonical TRAIN replay; and
2. `LIT-MR-02.1 / SOURCE_REPRO_2006_2012`, a reproduction of Chan's published
   Example 3.2 interval using quarantined Yahoo adjusted daily reference bars.

Neither instance changes the strategy mechanics, receives a decimal version
increment, reopens DEVELOPMENT or CONFIRMATION, or reverses
`STOP_LIT_MR_02_1_TRAIN_MECHANISM`.

## CASESTUDY_2018

### Selection disclosure

Calendar 2018 was selected after the complete 2016-2020 TRAIN result was known.
It is therefore a pedagogical working-regime case study, not an independent
test, parameter-selection sample, or estimate of expected performance.

Every other opened TRAIN calendar year remains visible beside it:

| Calendar year | Primary-cost return |
|---:|---:|
| 2016 | +3.77% |
| 2017 | -1.51% |
| **2018** | **+4.82%** |
| 2019 | -4.70% |
| 2020 | -16.15% |

### Exact mechanics retained

- adjusted daily Alpaca bars;
- rolling 20-session OLS of `USO ~ intercept + beta * GLD`;
- adaptive raw-price spread `USO - beta * GLD`;
- rolling 20-session spread z-score;
- entry below `-1` or above `+1`;
- zero-crossing exit without same-close reversal;
- signal after close and execution at the next adjusted open;
- daily adaptive rehedging;
- one gross-normalized long or short spread unit; and
- 5 bp per one-way weight change.

### Readout

| Metric | 2018 value |
|---|---:|
| Primary-cost return | +4.82% |
| Naive annualized Sharpe | 0.736 |
| Maximum drawdown | -7.64% |
| Completed trades | 13 |
| Winning trades | 9 |
| Hit rate | 69.2% |
| Long-spread trades | 9 |
| Short-spread trades | 4 |
| Mean net additive return per trade | +37.96 bp |
| Median net additive return per trade | +80.43 bp |

Both long- and short-spread trades contributed. The year was not a monotonic
success: the last completed trade lost about 4.55%, and the equity curve
finished well below its August peak. Those features make the case study useful
for explaining both convergence and residual path risk.

## SOURCE_REPRO_2006_2012

### Literature target

Chan's *Algorithmic Trading*, Example 3.2, reports 17.8% APR and 0.96 Sharpe for
GLD-USO from May 24, 2006 through April 9, 2012:

- printed pp. 71-72;
- PDF pp. 89-90; and
- Figure 3.3 on printed p. 72 / PDF p. 90.

The source code carries a position forward and applies lagged positions to
close-to-close price changes. It does not charge transaction or borrow costs.
The 20-session hedge lookback was selected near-optimally with hindsight in the
preceding example (printed p. 67 / PDF p. 85).

### Reference-data boundary

The operator explicitly authorized Yahoo Finance or another daily source for
this historical reproduction because the canonical Alpaca path did not cover
the published interval.

The runner uses Yahoo's chart endpoint for GLD and USO. It:

- requests the explicit source dates;
- computes `adjustment_factor = adjusted_close / raw_close`;
- applies the factor consistently to open, high, low, and close;
- preserves the retrieval URL and explicit as-of timestamp;
- requires unique, finite, positive daily OHLCV; and
- joins only common GLD-USO sessions.

Coverage passed for both symbols:

| Symbol | Rows | First session | Last session | Duplicates | Status |
|---|---:|---:|---:|---:|---|
| GLD | 1,480 | 2006-05-24 | 2012-04-09 | 0 | PASS |
| USO | 1,480 | 2006-05-24 | 2012-04-09 | 0 | PASS |

Yahoo is a quarantined literature-reproduction source only. It does not enter
the Gen5 provider interface, canonical cache, live runner, frozen decision
packs, or Alpaca-only operating contract.

### Two accounting views

| Accounting view | Cumulative return | APR | Naive Sharpe | Maximum drawdown |
|---|---:|---:|---:|---:|
| Chan-style close-to-close, no cost | +127.87% | +15.07% | 0.845 | -24.12% |
| Gen5 next-open, 5 bp primary cost | +104.05% | +12.93% | 0.933 | -20.76% |
| Chan published headline | not separately reported | +17.80% | 0.960 | not reported |

The current-data reproduction does not exactly equal the published headline.
The difference is retained as evidence rather than tuned away. Plausible
contributors include current versus original adjusted-data vintage, close
construction and rounding, and implementation details in the author's helper
functions.

The more decision-relevant result is that the Gen5 timing-and-cost translation
also remains clearly positive. It completed 78 trades: 44 long-spread and 34
short-spread, with a 56.4% hit rate and a +99.55 bp mean net additive return per
completed trade.

Positive-beta indicator coverage was 76.3%, below the canonical modern TRAIN
gate. The Gen5 replay therefore stayed flat during invalid negative-beta
signals. This positive control demonstrates profitable behavior in the source
interval; it is not a retrospective override of the eight-gate admission rule.

## Artifacts

- Runner:
  `scripts/inspect/run_gen5_lit_mr_02_1_case_studies.R`
- Reusable helpers:
  `R/gen5_lit_mr_02_1_case_studies.R`
- Evidence packet:
  `runs/research_workbench/literature_grounded/lit_mr_02_1_case_studies_20260729`
- Updated deck:
  `presentations/gen5_lit_mr_02_1_bollinger_evidence.pptx`

## Decision

The case studies establish the intended narrow conclusion:

> `LIT-MR-02.1` can produce coherent, cost-surviving long/short mean-reversion
> behavior in real historical regimes, including Chan's published interval.
> Its failure in later broad tests is therefore evidence of non-persistence,
> not evidence that the formula or implementation can never work.

The strategy remains a completed literature-grounded demonstration, not an
accepted Gen5 strategy candidate.
