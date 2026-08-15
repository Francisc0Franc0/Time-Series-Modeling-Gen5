# HYP-REG-03.1 Cross-Sectional Sector-Breadth Diagnostic Results

Status: `STOP_CROSS_SECTIONAL_BREADTH_GATES_FAILED_NO_JOINT_FILTER`

## Question

Can breadth across economically distinct sectors reveal trend participation or
deterioration that a single index-price trend measure misses?

This is the standard family of ideas usually called **market breadth**,
**participation**, or a **diffusion index**. Public S&P commentary supplies the
economic motivation: the percentage of constituents above a moving average is
used as a breadth measure, and cap-weighted index recovery can coexist with
deteriorating participation. The operator-provided Reddit comment sharpened
the hypothesis to a causal, after-close sensor and emphasized that it should
not be treated as a single bullish/bearish master switch.

## Frozen Translation

Exact point-in-time S&P 500 constituent history was not available. Using the
current index membership would introduce survivorship leakage, so the POC used
ten long-lived sector ETFs as an explicit proxy:

`XLB, XLE, XLF, XLI, XLK, XLP, XLRE, XLU, XLV, XLY`.

`XLC` was excluded because its 2018 launch and communications-sector
reclassification would introduce a structural break. For sector `i` on date
`t`:

```text
sector depth(i,t) = log(close(i,t) / SMA20(i,t))
breadth strength B(t) = median across the ten sector depths
participation P(t) = fraction of the ten sectors at or above SMA20
breadth impulse D(t) = B(t) - B(t-20)
```

`B(t)` is the primary continuous score. `P(t)` is the literal diffusion
companion. `D(t)` asks whether breadth is strengthening or decaying. Every
value is known after the close; H5, H20, and H63 open-to-open targets begin at
the next open. Inference uses horizon-spaced observations and 200 common
within-calendar-year circular timing controls. The analysis window is
2018-2023; 2024+ remained sealed.

The same common signal was evaluated against the unchanged 26-target panel
from HYP-REG-02.1. No strategy return, P&L, costs, allocation, leverage, or
live behavior was computed.

## Result

All data and timing-integrity checks passed. The requested range was fully
covered. Query-health `stale_symbol` warnings only reflect that the deliberately
bounded 2023 endpoint precedes the repository's latest completed session; they
do not indicate a gap inside the requested window.

| Horizon | Median Spearman | Positive targets | Balanced accuracy | Up recall | Down recall | Median Q5-Q1 |
|---:|---:|---:|---:|---:|---:|---:|
| H5 | -0.018 | 9 / 26 | 0.472 | 0.623 | 0.326 | -0.230% |
| H20 | 0.039 | 19 / 26 | 0.502 | 0.655 | 0.348 | +1.783% |
| H63 | -0.382 | 0 / 26 | 0.387 | 0.485 | 0.286 | -10.962% |

The H20 result is the useful clue. It is positive across 19/26 targets and the
top breadth quintile exceeds the bottom by 1.78% at the median target. But the
association is only 0.039, down-move recall is poor, only two of six calendar
years are positive, and the actual timing ranks at the 56th percentile of the
circular controls. It therefore does not distinguish itself from plausible
mistimed versions of the same broad market cycle.

The H63 result is a decisive contradiction rather than a weak near miss: every
target has negative association, the median is -0.382, and the actual timing
ranks at the 0th control percentile. The score cannot be described as a
monotone multi-horizon direction sensor.

## Hidden-Deterioration Audit

The comment's most specific intuition was tested inside dates when SPY's own
`SMA20/SMA60` trend remained positive:

| Horizon | Breadth decaying | Stable/improving | Difference | Negative calendar years |
|---:|---:|---:|---:|---:|
| H20 | +1.188% | +2.124% | -0.936 pp | 4 / 6 |
| H63 | +6.765% | -1.533% | +8.298 pp | 1 / 6 |

This supports the intuition at roughly one month: while headline trend was
still positive, weakening sector depth preceded lower median SPY return than
stable or improving breadth. It does not support the same interpretation at a
quarter. H63 also has only 15 non-overlapping observations overall and sparse
year cells, so the large reversal should be read as unstable evidence, not as
an inverse signal to trade.

## Gate Decision

Only integrity passed: `1 / 8` gates.

- Preserve the H20 clue as an educational result, not a regime classifier.
- Do not combine this score with ATR%, run a strategy overlay, reverse the
  H63 sign, tune the 20-session anchor, or inspect 2024+ under HYP-REG-03.1.
- The result does not reject market breadth as a field. It rejects this exact
  ten-sector, SMA20-depth implementation as a general directional sensor.
- VIX term structure and intraday persistence remain distinct, unopened axes.

## Artifacts

- Frozen contract: `docs/GEN5_HYP_REG_03_CROSS_SECTIONAL_BREADTH_TREND_CONTRACT.md`
- Registry: `operator_hypothesis_lab/registries/hyp_reg_03_1_cross_sectional_breadth_registry.csv`
- Run packet: `runs/research_workbench/operator_hypothesis_lab/hyp_reg_03_1_cross_sectional_breadth_20260814`
- Evidence deck: `operator_hypothesis_lab/presentations/hyp_reg_03_1_cross_sectional_breadth_evidence.pptx`

## Public Conceptual Sources

- S&P Dow Jones Indices, *S&P Kensho New Economies Commentary: Q1 2024*.
- S&P Global Market Intelligence, *Bad breadth concerns rise as S&P 500 set to recover tariff-triggered losses* (June 11, 2025).
