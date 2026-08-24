# HYP-MR-01.2 Cross-Asset Intraday-Shock Reversal Atlas Results

Status: `STOP_HYP_MR_01_2_ATLAS_TRAIN_BREADTH_GATES_FAILED_DEVELOPMENT_NOT_RUN`

## Question

Does the unchanged HYP-MR-01.1 predictor generalize beyond QQQ across a fixed,
outcome-independent atlas of diverse assets?

## Frozen design

The atlas contains 36 assets—four from each of nine pre-existing categories:
broad US equity, US sectors, US industries, international equity, fixed income,
commodities, currencies, leveraged/inverse ETFs, and individual-stock
challengers. No result from this hypothesis selected or ordered an asset.

Every asset used the same prior-normalized open-to-close predictor, exact
next-session open-to-close target, univariate OLS, intercept-only drift
benchmark, three expanding TRAIN folds, and 1% influence audit as HYP-MR-01.1.
All comparisons used the same 1,006 common TRAIN anchor/target pairs. The
atlas-wide null applied each admissible circular target shift to all assets at
once, preserving their contemporaneous dependence.

The formal as-of timestamp was `2026-08-23 17:30:00 America/New_York`.

## Source boundary

All `252 / 252` source and construction checks passed. Each asset had 1,259
queried rows and fully covered the requested historical range. The generic
cache-health WARN only says the deliberately TRAIN-bounded query ends before
the 2026 as-of session; it has no requested-window impact.

## TRAIN result

The directional relationship generalized much more strongly than the forecast
improvement:

| Measure | Observed |
|---|---:|
| Negative full-TRAIN slopes | `31 / 36` (`86.1%`) |
| Negative Spearman correlations | `33 / 36` (`91.7%`) |
| Median beta | `-0.00057687` |
| Median Spearman | `-0.038173` |
| Median relative OOF MSE improvement vs drift | `-0.000255` (`-0.0255%`) |
| Assets improving on drift | `12 / 36` (`33.3%`) |
| Assets improving in at least two folds | `16 / 36` (`44.4%`) |
| Influence-excluded negative slopes | `32 / 36` (`88.9%`) |

TRAIN passed `4 / 7` gates. It failed forecast-loss breadth, multi-fold
breadth, and the joint common-shift timing-specificity gate.

The common-shift result is subtle. Observed median relative improvement was
better than the shift-null p90 (`-0.0255%` versus `-0.0721%`) and had upper-tail
probability `0.0158`, but it was still negative in absolute terms. The observed
positive-asset fraction was `33.3%`, exactly equal to—not strictly above—the
shift p90, so the predeclared joint timing gate failed. Timing specificity
cannot convert worse-than-drift forecasts into useful breadth.

## QQQ in context

QQQ was not the sole positive asset, but it was unusual. Its relative OOF MSE
improvement was `+0.7890%`, ranking fourth of 36 and at the `91.7`th percentile.
Only MSFT (`+2.0780%`), SMH (`+1.9312%`), and TXN (`+1.6168%`) ranked above it.
QQQ, SMH, TXN, and TQQQ improved in all three folds.

This does not nominate those assets. The contract explicitly tests atlas
breadth and forbids selecting winners after the outcome read. It instead shows
that the original QQQ TRAIN pass sat in a thin upper tail of the cross-asset
distribution.

## Category structure

Only four of nine category medians were positive:

| Category | Median relative OOF improvement |
|---|---:|
| Individual-stock challengers | `+0.8879%` |
| US industries | `+0.1679%` |
| Leveraged/inverse ETFs | `+0.0327%` |
| Broad US equity | `+0.0018%` |
| International equity | `-0.0284%` |
| US sectors | `-0.1400%` |
| Fixed income | `-0.1815%` |
| Currencies | `-0.7538%` |
| Commodities | `-0.9499%` |

The strongest positive category was also the four-name individual-stock
challenger sleeve, while commodities and currencies were consistently harmful
relative to drift. This is useful structure for forming a future hypothesis,
but it is not authority to prune the atlas or open DEVELOPMENT.

## Interpretation

The atlas separates two ideas that can look identical on a chart:

1. A weak next-session reversal tendency is widespread in sign.
2. A predictor that lowers out-of-fold loss versus an intercept-only forecast
   is not widespread.

Most assets satisfy the first statement; only one-third satisfy the second.
QQQ's original TRAIN pass was therefore neither pure accident nor broad market
law. It was a comparatively strong member of a weak, heterogeneous reversal
tendency whose average forecasting value did not survive the breadth test.

This result also sharpens the HYP-MR-01.1 temporal failure: the QQQ coefficient
was exceptional within TRAIN, yet it still did not transport into 2021-2023.
Breadth does not rescue that parent STOP.

## Evidence boundary

DEVELOPMENT was not queried because the seven TRAIN gates did not all pass.
The 2024-2025 confirmation partition remains sealed. No strategy, threshold,
trade rule, P&L, Sharpe, drawdown, allocation, leverage, or live behavior was
calculated.

## Evidence packet

- Run packet:
  `runs/research_workbench/operator_hypothesis_lab/hyp_mr_01_2_cross_asset_intraday_shock_reversal_atlas_20260823`
- Asset breadth: `visuals/hmr012_train_asset_breadth.png`
- Category breadth: `visuals/hmr012_train_category_breadth.png`
- Common timing control: `visuals/hmr012_train_common_timing_control.png`
- Registry:
  `operator_hypothesis_lab/registries/hyp_mr_01_2_cross_asset_atlas_registry.csv`
