# HYP-REG-01.1 Asset-Relative ATR% Volatility States

Status: `DIAGNOSTIC_COMPLETE_STOP_BEFORE_STRATEGY_OVERLAY`

## Question

Can a causal, asset-relative ATR% percentile classify and predict the magnitude
of future market movement without using strategy returns, PnL, or price
direction?

## Frozen Design

- 26 assets: 24 sector-diverse stocks plus SPY and QQQ.
- Adjusted Alpaca daily OHLCV.
- Development period: 2018-01-02 through 2023-12-29.
- Wilder ATR(14), divided by close, ranked against the preceding 252 completed
  observations excluding the current session.
- Low below the 30th percentile, high above the 70th percentile, and medium
  between them, with 30/40 and 60/70 hysteresis.
- State known after today's close; target begins on the next session.
- Directionless target: mean normalized True Range over the next 1, 5, or 20
  sessions.
- Inferential readout uses deterministic non-overlapping observations at each
  horizon.
- Fixed benchmarks: today's normalized-range percentile and EWMA-volatility
  percentile with lambda 0.94.
- No strategy outcome was calculated. The 2024+ period remained sealed.

The frozen contract is
`docs/GEN5_HYP_REG_01_1_ATR_PERCENT_VOLATILITY_POC_CONTRACT.md`.

## Data Admission

All 26 assets retained complete 1,509-session analysis coverage and 503
pre-analysis sessions. A bounded attempt to refresh 2015 history returned no
bars before 2016-01-04 for any panel member. That boundary fully warms the
primary ATR14/252 specification. The ATR14/504 sensitivity begins after its
remaining natural warm-up inside 2018 and is compared only where both labels
exist.

The generic data-health layer labels the files `stale` relative to the explicit
2026 as-of timestamp because this query deliberately ends in 2023. Every symbol
nevertheless reports `covers_requested_range`; clearing the generic warning
would require querying the sealed 2024+ interval, which this lane prohibits.

All ten diagnostic integrity checks passed, including the explicit as-of,
confirmation exclusion, percentile bounds, three-state vocabulary,
non-overlapping alignment, and absence of strategy-outcome columns.

## Primary Predictive Result

The ATR% percentile had positive non-overlapping Spearman association with
future normalized range for all 26 assets at all three horizons.

| Horizon | Median per-asset Spearman | Positive assets | Median high/low future-range ratio | High above low | Fully monotonic high > medium > low |
|---:|---:|---:|---:|---:|---:|
| 1 session | 0.409 | 26 / 26 | 1.480x | 26 / 26 | 26 / 26 |
| 5 sessions | 0.477 | 26 / 26 | 1.425x | 26 / 26 | 25 / 26 |
| 20 sessions | 0.514 | 26 / 26 | 1.372x | 26 / 26 | 21 / 26 |

The panel-median directionless ranges were:

| Horizon | Low state | Medium state | High state |
|---:|---:|---:|---:|
| 1 session | 1.598% | 1.846% | 2.428% |
| 5 sessions | 1.741% | 1.959% | 2.509% |
| 20 sessions | 1.816% | 2.010% | 2.487% |

This is a meaningful forecasting result: the classifier separates future
movement magnitude consistently across assets, and the separation persists
for approximately one trading month. The declining high/low ratio at longer
horizons is also sensible because volatility states gradually mean-revert.

## Benchmark Comparison

| Horizon | ATR% percentile | EWMA percentile | Current-range percentile |
|---:|---:|---:|---:|
| 1 session | 0.409 | 0.339 | 0.370 |
| 5 sessions | 0.477 | 0.403 | 0.385 |
| 20 sessions | 0.514 | 0.428 | 0.383 |

ATR% produced the strongest median per-asset Spearman result at every frozen
horizon. This is not a post-hoc model selection claim: all three measurements
were fixed before execution, and the comparators remain diagnostic only.

The result also clarifies what ATR contributes. One recent range observation
contains useful persistence, but smoothing ranges through ATR retained more
information over the 5- and 20-session horizons than the one-bar persistence
baseline.

## State Behavior

- Median occupancy: 37.6% low, 27.0% medium, and 35.2% high.
- Median switches per asset-year: 10.4.
- Median state-run duration: 11 sessions.
- Median one-session reversal share: 2.5% of switches.
- One-session persistence: 96.8% for low, 92.4% for medium, and 97.4% for high.

The hysteresis mechanism therefore did what it was intended to do. It created
persistent, populated states without trapping the system permanently or
producing boundary chatter.

## Portability and Sensitivity

Every asset showed higher future range in the high state than in the low state
at every horizon. The effect was not confined to AMD, TSLA, SPY, or another
high-volatility subgroup.

Nearby ATR lengths were highly concordant with the primary labels:

- ATR10 / P252 median state agreement: 92.1%.
- ATR20 / P252 median state agreement: 91.7%.

Changing the historical comparison window was more consequential:

- ATR14 / P126 median agreement: 67.2%.
- ATR14 / P504 median agreement: 67.4%.

This is useful pushback. The evidence supports ATR% as a portable volatility
measurement, but `low`, `medium`, and `high` remain relative to the selected
historical memory. A later strategy-overlay POC must keep the 252-session
definition frozen rather than searching memory lengths for the best PnL.

## Interpretation

`HYP-REG-01.1` passes its diagnostic discussion gates:

- causal deterministic labels;
- ordered future range at all pooled horizons;
- high above low for every asset;
- coherent persistence and occupancy;
- stronger median predictive association than both fixed benchmarks;
- robust labels to nearby ATR lengths, with transparent window-length
  sensitivity.

This establishes predictive capacity for volatility magnitude. It does not
establish that low volatility is bad, high volatility is good, or any trading
strategy should be enabled or disabled.

## STOP and Next Decision

Stop before strategy gating. The next operator-owned question is whether to
freeze a separate overlay such as:

> Suppress new momentum entries in `LOW`; allow them in `MEDIUM` and `HIGH`;
> leave existing exit mechanics unchanged.

That test would require unchanged-strategy and exposure-matched placebo
baselines. It must not tune ATR length, percentile memory, state thresholds,
assets, or allowed-state combinations on this diagnostic result.

## Artifacts

- Contract: `docs/GEN5_HYP_REG_01_1_ATR_PERCENT_VOLATILITY_POC_CONTRACT.md`
- Registry: `operator_hypothesis_lab/registries/hyp_reg_01_1_atr_percent_registry.csv`
- Engine: `operator_hypothesis_lab/R/hyp_reg_01_1_atr_percent.R`
- Runner: `operator_hypothesis_lab/scripts/run_hyp_reg_01_1_atr_percent.R`
- Evidence packet: `runs/research_workbench/operator_hypothesis_lab/hyp_reg_01_1_atr_percent_20260814`
- Evidence deck: `operator_hypothesis_lab/presentations/hyp_reg_01_1_atr_percent_volatility_evidence.pptx`
