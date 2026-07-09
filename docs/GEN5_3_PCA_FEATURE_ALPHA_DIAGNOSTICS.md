# Gen5.3 PCA Feature Alpha Diagnostics

## Purpose

This note records the project pivot that followed the Gen5.2 / Gen4 calibration
work.

The operator's concern was practical and important: after substantial effort to
make Gen5.x behave more like Gen4, Gen5.x still did not fully reproduce Gen4's
best historical alpha, and broader stress tests often struggled to beat a simple
equal-weight buy-and-hold benchmark. That raised the possibility that the project
was chasing the wrong layer, overfitting to Gen4 behavior, or should jump to a
different regime engine such as hidden Markov models.

The resulting decision frame is:

- Gen4 parity was useful as a calibration target, not as the final product
  definition.
- PCA 3x3 remains the right near-term research engine because it is already
  auditable, operationally familiar, and mature enough to support controlled
  experiments.
- The next highest-value question is whether the feature layer feeding PCA is
  good enough to create states that help the strategy layer beat benchmark.
- Hidden Markov models should remain a later challenger, not a way to avoid
  understanding what PCA can and cannot do.

## Recommended Designation

Use `Gen5.3` for this next track if the scope is explicitly:

> PCA 3x3 feature-set diagnostics and benchmark-relative alpha improvement.

That keeps `Gen5.2` cleanly defined as the Gen4-mechanics and live-capital
parity investigation, while `Gen5.3` becomes the first research track that is
freed from cloning Gen4 and instead asks what state features make the current
system trade better.

## Central Hypothesis

The current PCA surface may be structurally reasonable, but the input features
may not yet give PCA the right information to separate states that matter for
trading.

In plain terms: if the state map cannot distinguish "participate aggressively,"
"stand aside," and "protect capital" conditions, the downstream strategy
selection layer is forced to make decisions inside noisy bins. Better PCA
features may improve the quality of those bins without changing the whole
architecture.

## Candidate Feature Blocks

The first Gen5.3 screens should add or swap feature blocks while holding the
rest of the research surface steady.

Recommended default control:

- PCA mode: behavioral pool / long-style PCA.
- State map: 3x3 quantile grid.
- Selection policies: direct-spec and pooled-family, both using current Gen5.2
  mechanics where applicable.
- Assessment: existing portfolio accounting surface plus benchmark-relative
  summaries.

Candidate feature blocks:

1. **Trend and participation features**
   - Multi-horizon returns.
   - EMA slope and EMA stack.
   - Distance from recent highs.
   - Recent breakout / continuation markers.

2. **Volatility and drawdown features**
   - Realized volatility.
   - ATR or daily range expansion.
   - Downside volatility.
   - Drawdown from rolling peak.

3. **Benchmark-relative features**
   - Asset return minus SPY or QQQ return.
   - Beta-adjusted relative strength.
   - Rolling excess-return z-score.
   - Relative drawdown versus benchmark.

4. **Breadth and context features**
   - Percent of context universe above moving average.
   - Cross-sectional dispersion.
   - Correlation / co-movement proxy.
   - Sector or risk-bucket relative strength.

5. **Liquidity and participation stress features**
   - Volume z-score.
   - Dollar-volume stability.
   - Gap / overnight move proxy if available from daily OHLC.

## First Test Shape

The first useful Gen5.3 screen should be narrow, not maximal:

- Keep PCA 3x3 fixed.
- Keep the active assessment basket fixed.
- Compare the current feature set against two or three additive feature blocks.
- Use more than one time window so that a single bull or crash regime does not
  dominate the conclusion.
- Treat benchmark-relative performance as the primary inspection surface, not as
  accepted allocation evidence.

Suggested initial feature conditions:

1. `current_features_control`
2. `trend_participation_plus`
3. `trend_volatility_plus`
4. `trend_volatility_relative_plus`

## What To Measure

The point is not just whether a lane made more money. The first readout should
explain how the system made or failed to make alpha.

Recommended diagnostics:

- Excess return versus equal-weight buy-and-hold basket.
- Upside participation during benchmark-positive periods.
- Downside avoidance during benchmark-negative periods.
- Time in market by state, asset, and selection policy.
- Trade count, win rate, average win, average loss, and tail loss.
- State-level contribution to return and drawdown.
- No-trade selection frequency and whether no-trade avoided bad exposure.
- Benchmark-relative return by fold.

## Guardrails

- Do not change the live advice bridge from this track.
- Do not add new data providers.
- Do not treat a winning feature block as deployment-ready allocation evidence.
- Keep test windows predeclared before reading results.
- Compare each feature block to the same benchmark and same control surface.
- Prefer small, interpretable feature additions before expanding the search
  space.

## STOP Decisions

Before implementation, the operator owns these decisions:

- Whether to formally call this track `Gen5.3`.
- Which active basket and context universe should be the first testbed.
- Which two or three feature blocks should be tested first.
- Which historical windows should be included in the first screen.
- Whether direct-spec and pooled-family both remain in the first Gen5.3 screen.

## Suggested Next Prompt

```text
Please continue on branch codex/Gen5.3-pca-feature-alpha-diagnostics.
Read AGENTS.md and docs/GEN5_3_PCA_FEATURE_ALPHA_DIAGNOSTICS.md first.

Implement the smallest useful Gen5.3 PCA feature diagnostics screen.
Keep PCA behavioral_pool + 3x3 quantile_grid fixed. Keep this research-only.

Compare:
- current_features_control
- trend_participation_plus
- trend_volatility_plus
- trend_volatility_relative_plus

Use the existing portfolio accounting surface as downstream assessment, with
equal-weight buy-and-hold basket benchmark comparisons. Produce a top-level
report, run spec, feature taxonomy table, child artifact index, summary CSV,
benchmark-relative summary CSV, and compact charts under ignored runs/.

Do not touch the frozen live advice bridge. Validate, then commit and push.
```
