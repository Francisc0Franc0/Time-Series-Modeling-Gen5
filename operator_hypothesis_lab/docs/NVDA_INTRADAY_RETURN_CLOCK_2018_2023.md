# NVDA Intraday Return Clock, 2018-2023

## Question

What does each point on NVDA's regular-session clock look like before we add a
signal, filter, model, or trading rule?

This is deliberately a one-asset descriptive study. Its purpose is to make the
raw intraday anatomy visible and help the operator form the next narrow
question. It does not claim that the observed distributions predict anything.

## Is one-asset strategy design legitimate?

Yes. A strategy may be intentionally designed for one asset when the intended
claim is also one-asset-specific. That can be rational when the asset has a
repeatable microstructure, recurring participant base, unusually deep retail
liquidity, persistent options activity, or a business/news cadence that makes
its behavior structurally distinct.

The burden of proof changes rather than disappears:

- validate across later untouched time, not merely more observations from the
  same regime;
- include realistic execution, spread, slippage, and opportunity-cost
  comparisons;
- require enough independent market regimes and events that one episode does
  not dominate;
- compare against simple NVDA ownership, cash, and matched-exposure baselines;
- monitor structural breaks, because a one-asset system has no cross-sectional
  diversification when the asset's behavior changes;
- state the scope honestly: an NVDA strategy need not generalize to AMD, other
  semiconductors, or equities as a whole.

Specialization is therefore not the methodological problem. Repeatedly changing
the rule until it fits NVDA's known history would be the problem.

## Frozen descriptive slice

- Study identifier: `HYP-NVDA-CLOCK-01.1`
- Symbol: `NVDA`
- Provider: Alpaca SIP
- Bars: adjusted 30-minute regular-session OHLCV
- Research period: `2018-01-02` through `2023-12-29`
- Confirmation boundary: `2024-01-02`; no 2024+ bars are read
- Intraday return: `log(adjusted bar close / adjusted bar open)`
- Overnight gap: `log(first adjusted regular-session open / prior adjusted
  regular-session close)`
- Display: every eligible observation with deterministic horizontal jitter
- Outlier handling: none
- Inferential statistics: none
- Strategy or performance calculation: none

The overnight gap appears to the left of the first 30-minute bar. Ten known
Alpaca SIP archive-gap sessions are omitted under the existing intraday data
contract. When one of those missing sessions lies between two observed
sessions, the following overnight point is also omitted so that a multi-session
move is not mislabeled as a one-night gap. The available regular-session bars
remain in the plot.

## Construction readout

All 12 checks passed.

- `1,499` sessions are represented.
- `19,415 / 19,415` eligible regular-session bars appear in the point ledger.
- `1,490` overnight-gap observations have a complete prior close.
- All 14 clock bins are present: one gap plus 13 regular-session bars.
- Later clock bins contain 12 fewer observations because the admitted calendar
  contains 12 early-close sessions; they are not missing ordinary-session bars.
- The complete visible range is preserved without winsorization.

## What the first plot makes visible

The strongest first-order feature is not a directional edge. It is the shape of
the clock:

- the overnight gap has by far the widest dispersion and the most extreme
  tails;
- the `09:30-10:00` bar is the widest regular-session distribution;
- the middle of the session visibly compresses;
- dispersion widens again near the close, especially in the final bar;
- the median ticks remain close to zero relative to the distributions, even
  where a small positive or negative tilt is visible.

These are descriptive observations, not hypotheses that have survived a test.
The chart is now a clean launch point for operator-generated questions such as
whether gap sign or magnitude changes the first-bar distribution, whether the
opening bar predicts later same-session returns, or whether this clock shape is
stable across calendar regimes. Each would need its own causal definition and
fresh validation boundary.

## Artifacts

- [Run report](../../runs/research_workbench/operator_hypothesis_lab/nvda_intraday_clock_descriptive_20260831/report.md)
- [Scatterplot](../../runs/research_workbench/operator_hypothesis_lab/nvda_intraday_clock_descriptive_20260831/visuals/nvda_overnight_and_30min_return_clock.png)
- [Point ledger](../../runs/research_workbench/operator_hypothesis_lab/nvda_intraday_clock_descriptive_20260831/nvda_intraday_clock_points.csv)
- [Clock summary](../../runs/research_workbench/operator_hypothesis_lab/nvda_intraday_clock_descriptive_20260831/nvda_intraday_clock_summary.csv)
- [Run specification](../../runs/research_workbench/operator_hypothesis_lab/nvda_intraday_clock_descriptive_20260831/run_spec.csv)
- [Source checks](../../runs/research_workbench/operator_hypothesis_lab/nvda_intraday_clock_descriptive_20260831/source_checks.csv)
- [Runner](../../scripts/inspect/run_nvda_intraday_clock_descriptive.R)

## Status

`DESCRIPTIVE_NVDA_INTRADAY_CLOCK_COMPLETE_NO_EDGE_CLAIM`

Do not select a bar, threshold, signal, strategy, or performance claim from this
plot. Keep 2024+ untouched until a specific next hypothesis and its validation
role are defined.
