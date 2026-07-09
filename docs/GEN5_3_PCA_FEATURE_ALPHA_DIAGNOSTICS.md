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

## First Screen Conditions

The first implemented screen holds the following constant:

- PCA mode: behavioral pool / pooled asset-day.
- State map: `3x3` quantile grid.
- Selection policies: `asset_state_direct_spec` and
  `pooled_family_asset_variant`.
- Replay/accounting: true shared-account live-capital replay with equal-slot,
  cash-capped entries.
- Benchmark: equal-weight buy-and-hold of the same active basket over the same
  quarter.
- Live bridge: untouched.

The first diverse dataset uses the same style-diversified stress surface opened
in Gen5.2:

- High-beta growth: `AMD,NVDA,TSLA,AAPL,MSTR`.
- Defensive staples: `KO,PEP,WMT,COST,XLP`.
- Energy/commodity: `XLE,CVX,XOM,GLD,SLV`.
- Context anchors: each basket plus `SPY,QQQ,IWM,TLT,GLD`.
- Windows: `2020Q3` risk-on rebound and `2022Q1` rate-shock drawdown.

For the first Gen5.3 run, `state_switch_continuation` replay is the default
lean slice. It is closer to the continuity question raised by the recent audits
and halves compute relative to running both continuation and fresh-signal-only.

### Staged Smoke Scope

The first completed implementation run used an explicitly labeled
`diverse_smoke` scope before attempting the full-width screen.

Reason:

- The full design is scientifically cleaner, but broad Gen4-like strategy grids
  make feature-set sweeps compute-heavy because each feature set changes state
  assignment and therefore requires separate authority fitting.
- A staged smoke packet should catch implementation gaps and reveal directional
  behavior without pretending to be the final factorial evidence.

Smoke scope:

- Window: `2022Q1_asof_20220331` rate-shock drawdown.
- High-beta growth: `AMD,NVDA`.
- Defensive staples: `KO,WMT`.
- Energy/commodity: `XLE,GLD`.
- Context anchors: each smoke basket plus `SPY,QQQ,IWM,TLT,GLD`.
- Feature sets: all four first-screen feature conditions.
- Selection policies: `asset_state_direct_spec` and
  `pooled_family_asset_variant`.
- Replay: `state_switch_continuation`.

Artifact packet:

- `runs/research_workbench/g53/feat_smoke_20260708a/`
- Report: `style_diversified_live_capital_report.md`
- Summary: `style_diversified_live_capital_summary.csv`
- Aggregate: `style_diversified_live_capital_aggregate.csv`
- Charts:
  `style_diversified_live_capital_alpha_heatmap.png`,
  `style_diversified_live_capital_equity_overlay.png`, and
  `style_diversified_live_capital_exposure_alpha_scatter.png`

Implementation lesson:

- The training path already accepted Gen5.3 feature sets, but replay initially
  rebuilt PCA scoring features with default Gen5.2 columns. This was fixed by
  reading `pca_feature_cols` from the frozen authority contract when present.
- Long Windows/OneDrive paths can break R CSV writes around classic path-length
  boundaries. Gen5.3 screen packets therefore use compact folder slugs while
  preserving full condition names inside run specs and summaries.

First smoke readout:

- High-beta smoke basket: all feature sets beat the falling equal-weight basket
  on alpha. `trend_volatility_plus` had the strongest alpha (`+19.3 pp`) with
  very low exposure (`6.5%`) and one entry, meaning it behaved more like a
  defensive avoidance filter than a participation engine in this window.
- Defensive smoke basket: `trend_participation_plus` direct-spec was the best
  lane (`+2.4 pp` alpha), while volatility and relative additions lagged the
  simple basket benchmark.
- Energy/commodity smoke basket: all lanes produced positive absolute returns,
  but none beat the strong equal-weight basket hold. `trend_participation_plus`
  was least bad (`-7.6 pp` alpha), while relative/volatility additions reduced
  participation too much.
- Direct versus pooled-family was not the dominant factor in this smoke packet;
  feature set and basket archetype mattered more.

Interpretation:

- The first smoke packet supports the idea that PCA feature design matters.
- It does not yet support promoting any feature set as generally better.
- The strongest near-term hypothesis is narrower: trend-participation features
  may improve upside capture in some non-crash baskets, while volatility and
  relative features may help avoidance but can underparticipate in strong
  commodity or rebound moves.
- The next full-width or medium-width screen should test whether this pattern
  survives more symbols and at least one additional window before changing
  defaults.

### `current_features_control`

Mechanism:

- Uses the existing Gen5.2 PCA features:
  `ema_gap,trend_slope_5,rsi_14,vol_20,atr_pct,dist_anchor_200,chop_14,bb_width,efficiency_ratio_20,z_close_sma20,ret_skew_20`.

Why:

- Provides the control condition. If a new feature set does not improve or
  clarify benchmark-relative behavior against this surface, it should not be
  promoted.

### `trend_participation_plus`

Mechanism:

- Adds multi-horizon log returns: `ret_log_21`, `ret_log_63`,
  `ret_log_126`.
- Adds short/intermediate trend shape: `ema_gap_10_30`,
  `ema_slope_20_20`.
- Adds proximity to recent highs: `dist_high_63`.

Why:

- Tests whether PCA states under-participate in bull phases because the state
  engine does not see enough direct information about durable upside and
  breakout/continuation structure.

### `trend_volatility_plus`

Mechanism:

- Adds the trend-participation features above.
- Adds downside volatility: `downside_vol_20`.
- Adds range expansion: `range_pct_20`.
- Adds recent drawdown: `drawdown_63`.
- Adds short/intermediate volatility ratio: `vol_ratio_20_63`.

Why:

- Tests whether trend only becomes useful when PCA can distinguish healthy
  participation from unstable, damaged, or high-volatility trend.

### `trend_volatility_relative_plus`

Mechanism:

- Adds trend and volatility features above.
- Adds context-relative features computed inside the pooled asset-day panel:
  `rel_ret_log_21_ctx`, `rel_ret_log_63_ctx`, `rel_vol_20_ctx`,
  `rel_drawdown_63_ctx`.
- These subtract the same-date context-universe mean from the asset's own
  feature value.

Why:

- Tests whether PCA can distinguish true asset leadership from broad beta
  exposure. A high-beta asset rising with the whole market is not the same as an
  asset leading its context universe with superior relative strength or less
  relative drawdown.

Leakage note:

- Context-relative features use only same-date and trailing OHLCV information
  available after that session's close. PCA center/scale/loadings and state
  breaks are still fit from TRAIN rows only.

## Medium-Term Feature Families

Gen5.3 should not become "trend forever." The first trend-heavy screen is
motivated by the current observed failure mode: under-participation in upside.
After the first screen, the same framework can test other feature families:

1. **Mean-reversion / dislocation features**
   - Short-horizon return extremes.
   - Distance from moving averages.
   - Bollinger position.
   - RSI level and RSI slope.
   - Volume/range capitulation.

2. **Volatility / fragility features**
   - Volatility compression and expansion.
   - Downside-volatility acceleration.
   - Gap frequency.
   - Drawdown speed.
   - Volatility-of-volatility proxies.

3. **Cross-sectional leadership features**
   - Relative strength versus market, sector, and context basket.
   - Relative drawdown versus context.
   - Cross-sectional rank or z-score within the active context universe.

4. **Event/sentiment features**
   - Keep as a later extension. Alpaca news can support sentiment experiments,
     but true earnings-calendar, consensus-estimate, beat/miss, and
     announcement-time modeling likely requires a fundamentals/event provider
     and stricter timestamp guardrails.

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
