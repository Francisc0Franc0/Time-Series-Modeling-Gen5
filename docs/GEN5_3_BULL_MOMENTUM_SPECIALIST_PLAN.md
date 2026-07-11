# Gen5.3 Bullish Momentum Specialist Plan

Status date: 2026-07-10

This note captures a deliberate research pivot after the Gen5.2 mechanics and style-diversified live-capital screens. It is a planning artifact, not allocation evidence, live advice, or execution approval.

## Plain-Language Purpose

The current Gen5.x research engine has been trying to solve a very broad problem: trade dynamic bull markets, quiet bull markets, sideways mean-reversion markets, turbulent ranges, breakout regimes, and rallies inside downtrends. That is elegant in principle, but it may be too broad for the next productive proof of concept.

Gen5.3 proposes a narrower specialist first:

> Select assets that already look structurally bullish and high-beta, then use PCA states and momentum-only downstream hypotheses to decide when to participate, when to hold, and when to stand aside.

The goal is not to build a system that handles every market behavior. The goal is to build a system that can first do one valuable thing well: capture upside participation in strong, volatile assets without remaining blindly exposed when momentum stalls.

## Why This Pivot Makes Sense

Recent Gen5.2 screens showed a recurring weakness: tactical lanes can make positive trades yet still lag equal-weight buy-and-hold when the basket is strongly bullish. That is a participation-quality problem.

The broad universal-router design asks each PCA state to discover which strategy family works best. That lets `ema_cross`, `rsi_mr`, `zret_mr`, `bollinger`, breakout, pullback, and `no_trade` all compete as hypotheses. This is powerful, but it also creates several burdens:

- The state engine must identify many types of tradable environments.
- The strategy selector must choose among fundamentally different market hypotheses.
- The parameter grid becomes large and noisy.
- Outperformance can be masked by underparticipation during the exact bullish windows the operator most wants to capture.
- A state can look bad by point-to-point return while still being good for a mean-reversion strategy, which makes simple forward-return diagnostics insufficient.

The proposed specialist accepts a tighter mission:

- First, use asset/universe curation to put the system in front of assets likely to trend.
- Second, use PCA to identify favorable versus stalled/risky momentum participation states.
- Third, score only momentum-compatible strategies downstream.
- Fourth, benchmark harshly against equal-weight buy-and-hold, because a bullish specialist must earn its keep against simply holding bullish assets.

## How This Aligns With Real Trading Practice

This resembles a real-world discretionary or systematic trader narrowing the playing field before optimizing entries:

- A momentum trader often starts with a screened list of liquid, high-relative-strength names rather than trying to trade every market type.
- A trend follower usually accepts that many regimes are not worth trading and that the edge comes from being present during sustained moves.
- A sector-rotation or relative-strength trader separates universe selection from timing: first find the strongest assets or groups, then decide when to enter, hold, reduce, or exit.
- A volatility-aware momentum trader may use market breadth, relative strength, trend slope, realized volatility, and drawdown behavior as filters around otherwise simple moving-average rules.

The proposed system is therefore not less sophisticated because it is narrower. It is closer to a well-scoped trading desk mandate: "Trade high-beta bullish continuation; avoid pretending to monetize every kind of noise."

## Core Research Thesis

The specialist thesis is:

> A PCA engine trained on bullish/high-beta candidates and risk context may be more useful when it routes a narrow momentum hypothesis set than when it tries to choose among all possible strategy archetypes.

This changes what PCA is being asked to do.

In the broad Gen5.1/Gen5.2 engine, PCA states are treated as general regimes. Downstream strategy competition determines whether a state is trend-following, mean-reverting, breakout-friendly, or untradeable.

In the Gen5.3 specialist, PCA states are more like participation filters:

- "This is a good continuation environment."
- "This is still bullish but extended or unstable."
- "Momentum has stalled; stand aside."
- "The broader risk context is hostile to high-beta exposure."

## Proposed Architecture

### Stage 0: Bullish Candidate Curation

Create a leakage-safe asset-selection layer using only information available before the test window.

Candidate metrics may include:

- trailing total return;
- relative strength versus `SPY` or `QQQ`;
- percent above long moving average;
- drawdown recovery behavior;
- realized volatility or beta proxy;
- liquidity / data sufficiency filters;
- correlation to high-beta growth or sector proxies.

This stage should output a research/live basket and a context universe. It should not inspect OOS performance.

### Stage 1: PCA Participation States

Run behavioral-pool PCA over the curated basket plus relevant risk/momentum context.

Initial default:

- panel mode: `behavioral_pool`;
- state map: `3x3 quantile_grid`;
- context: curated high-beta basket plus market/sector/risk anchors;
- feature family: start with existing enriched features, then add momentum-participation diagnostics only after the first baseline is documented.

### Stage 2: Momentum-Only Strategy Hypotheses

Restrict downstream candidate families to momentum-compatible strategies.

Initial implemented candidates:

- `ema_cross`;
- `ema_trend`;
- `breakout`;
- `pullback_in_uptrend`;
- `vol_expansion_breakout`;
- `donchian_breakout_vol_expand`;
- `no_trade`.

Potential future candidates requiring explicit operator approval:

- SMA cross/trend variants;
- volatility-adjusted trailing stop overlays;
- time-in-trend continuation rules;
- breakout retest entries;
- relative-strength rotation rules.

Mean-reversion families such as `rsi_mr`, `zret_mr`, and Bollinger reversion should be excluded from the first specialist test unless explicitly included as a small challenger/control. They may still be useful later, but including them in the first specialist screen blurs the mission.

### Stage 3: Assessment

Use existing portfolio accounting as the downstream inspection surface, but judge this specialist against a stricter benchmark:

- equal-weight buy-and-hold of the selected live basket;
- time-in-market / participation ratio;
- upside capture in bullish windows;
- downside avoidance during drawdowns;
- trade tape sanity checks;
- state-level exposure and family selection maps;
- concentration by symbol.

Do not treat performance as accepted allocation evidence.

## Feature-Set Assessment For This Specialist

The broad engine should keep strategy-conditioned validation as the main judge. But the specialist can use a more targeted diagnostic stack:

1. State mechanics:
   - Are states populated and persistent enough?
   - Are they stable across folds?
   - Do they separate high-beta uptrend, stalled trend, volatility expansion, and risk-off behavior?

2. Forward behavior diagnostics:
   - future return;
   - future volatility;
   - max favorable excursion;
   - max adverse excursion;
   - drawdown after state entry;
   - trend persistence.

3. Momentum strategy diagnostics:
   - which states select momentum families versus `no_trade`;
   - whether selected momentum specs remain stable across folds;
   - whether favorable states produce higher participation during benchmark rallies;
   - whether unfavorable states reduce exposure during drawdowns.

4. Portfolio replay:
   - live-capital shared-account replay;
   - equal-slot sizing;
   - benchmark-relative alpha;
   - trade tape and chart audit.

Future return remains a diagnostic, not the final judge. A state could still be useful if it identifies a trend-continuation condition with favorable path behavior even when a short point-to-point return window is noisy.

## Initial Experiment Design

### Smallest Useful Run

Question:

Can a momentum-only PCA-routed engine increase high-beta upside participation relative to the broader all-family engine and relative to equal-weight buy-and-hold?

Scope:

- one curated high-beta historical basket with adequate 2016+ history, such as `AMD,NVDA,TSLA,AAPL,MSTR`;
- two windows with contrasting behavior, such as a rebound window and a stress/chop window;
- behavioral-pool PCA;
- 3x3 quantile states;
- active-plus-risk or curated high-beta-plus-risk context;
- strategy families: momentum-only plus `no_trade`;
- selection policies: start with pooled-family and direct-spec if already cheap to include; otherwise use the current leading policy from the last screen as a default and keep the other as a challenger in the medium run;
- replay semantics: include `fresh_signal_only` and `state_switch_continuation` if the current wrapper already supports that as a factor.

Outputs:

- run spec;
- feature/context/basket taxonomy;
- benchmark-relative portfolio summary;
- participation diagnostics;
- state/family heatmaps;
- representative trade tapes;
- compact slide update.

### Medium Run

Add:

- a second high-beta basket selected by the curation layer rather than hand-picked;
- three to five windows across different market environments;
- comparison against the broad all-family grid from prior Gen5.2 screens;
- optional feature-set variants focused on momentum participation.

### Full Later Run

Only after the small and medium runs show evidence of a real specialist edge:

- multiple candidate-selection rules;
- multiple high-beta basket definitions;
- momentum feature-set variants;
- state map sensitivity, still likely 3x3 first;
- direct versus pooled selection policy;
- fresh versus continuation replay semantics;
- true live-capital accounting over many windows.

## What Success Would Look Like

The first success bar should be modest and behavioral, not grand:

- The specialist is long more often during strong basket rallies than the broad engine.
- It avoids some major drawdowns or stalled phases without overtrading.
- Its state maps are interpretable as momentum participation states.
- It beats or comes closer to equal-weight basket hold in at least some bullish windows without catastrophic stress-window behavior.
- Its trade tapes look like sane trend participation rather than random entry/exit noise.

## Weaknesses And Failure Modes

This narrower approach has real risks:

- It may overfit to high-beta bull windows and fail in slower markets.
- It may lag buy-and-hold if exits are too sensitive.
- It may select assets using backward-looking strength just as momentum is exhausting.
- It may become a timing layer that adds complexity without improving returns.
- It may underperform broad mean-reversion-capable engines in range-bound markets.
- It may concentrate risk in a few names or themes.
- It may look good in single-name winners while failing as a basket process.

These are acceptable risks for a specialist POC, but they must be measured explicitly.

## STOP Decisions Before Implementation

The operator should decide before the first implementation run:

- Whether to label this as Gen5.3 for research planning purposes.
- Whether the first specialist test excludes mean-reversion families entirely or includes one small mean-reversion challenger/control.
- Whether to add SMA families now or defer them until the EMA/breakout-only specialist has a baseline.
- Whether the first curated basket is hand-picked for continuity or selected by a simple TRAIN-only curation rule.
- Whether the first run should compare against the prior broad all-family engine immediately or first establish a specialist-only baseline.

## Recommended Default Next Slice

Recommended default:

Run a narrow Gen5.3 specialist baseline over `AMD,NVDA,TSLA,AAPL,MSTR` using behavioral-pool PCA, 3x3 quantile states, active-plus-risk context, momentum-only implemented families plus `no_trade`, and true live-capital replay over two contrasting windows. Include equal-weight basket hold as the primary benchmark and produce participation/trade-tape diagnostics.

Do not add SMA yet. Do not include mean-reversion families in the first specialist baseline. Keep the first run small enough that failures are interpretable.

## First Baseline Result

Packet:

`runs/research_workbench/gen53_bull_momentum_specialist/g53_bullmom_20260710/`

Deck:

`presentations/gen5_3_bull_momentum_specialist_plan.pptx`

Wrapper:

`scripts/inspect/run_gen53_bull_momentum_specialist_screen.R`

Design actually run:

- basket: `AMD,NVDA,TSLA,AAPL,MSTR`;
- context: basket plus `SPY,QQQ,IWM,SMH,TLT,GLD`;
- PCA/state surface: behavioral-pool plus `3x3` quantile states;
- selection policy: `pooled_family_asset_variant`;
- replay semantics: `fresh_signal_only` and `state_switch_continuation`;
- strategy pool: `ema_cross,ema_trend,breakout,pullback_in_uptrend,vol_expansion_breakout,donchian_breakout_vol_expand,no_trade`;
- accounting: true shared-account live-capital replay against equal-weight basket hold and SPY reference;
- windows: `2020Q3` rebound and `2022Q1` drawdown/stress.

Readout:

- In `2020Q3`, equal-weight basket hold returned `48.9%`. The specialist returned `9.3%` fresh and `17.1%` continuation, lagging by `-39.7 pp` and `-31.9 pp`. Continuation improved exposure from `40.9%` to `57.2%`, but still undercaptured the rebound.
- In `2022Q1`, equal-weight basket hold returned `-12.8%`. The specialist returned `-0.1%` fresh and `-0.5%` continuation, beating hold by `+12.7 pp` and `+12.2 pp` by staying lightly exposed.
- Across the two windows, continuation had better mean alpha than fresh (`-9.8 pp` versus `-13.5 pp`) but still did not beat basket hold on average.

Interpretation:

The first baseline does not prove a bullish specialist edge. It does sharpen the failure mode. The system can avoid a high-beta drawdown, and selected states do choose momentum families rather than collapsing entirely into `no_trade`, but bullish participation is still late or too light during a strong rebound. The next useful slice should keep basket, context, PCA, policy, and benchmark fixed while testing whether momentum-participation features help states enter and stay long earlier without surrendering drawdown protection.

Compute note:

The full Gen4 daily-default breadth is expensive enough that feature-engineering probes should start with compact grids, then confirm with full breadth once the mechanism is visible.

## Feature-Set Challenger Result

Packet:

`runs/research_workbench/gen53_bull_momentum_specialist/g53_bullmom_20260710features/`

Deck:

`presentations/gen5_3_bull_momentum_specialist_plan.pptx`

Wrapper:

`scripts/inspect/run_gen53_bull_momentum_specialist_screen.R`

Purpose:

This follow-up keeps the first specialist setup fixed and varies only the PCA feature set. The goal is to test whether the workhorse PCA surface is too blunt for bullish participation timing.

Feature sets:

- `workhorse_enriched`: the existing Gen5 workhorse surface, combining trend, stretch, volatility, chop, efficiency, and return-shape descriptors.
- `momentum_participation`: a sharper bullish-participation surface focused on trend strength, return impulse, persistence, range location, drawdown, and recovery.
- `momentum_plus_stress`: the momentum-participation surface with volatility/range/stress descriptors added back to preserve drawdown context.

Readout:

- In `2020Q3`, `momentum_plus_stress` continuation returned `20.8%` versus `17.1%` for workhorse continuation. Its basket-relative alpha was still negative (`-28.1 pp`), but it improved over the workhorse continuation lane (`-31.9 pp`).
- In `2022Q1`, `momentum_plus_stress` continuation returned `-0.7%` versus `-0.5%` for workhorse continuation. Both preserved the same broad stress-window behavior versus the falling high-beta basket (`+12.1 pp` versus `+12.2 pp` alpha).
- Across the two windows, `momentum_plus_stress` continuation improved mean alpha from `-9.8 pp` to `-8.0 pp` and mean total return from `8.3%` to `10.1%`.

Interpretation:

The feature layer matters. The richer momentum-plus-stress surface moved in the desired direction without surrendering the stress-window protection, but it still did not beat equal-weight basket hold. Treat `momentum_plus_stress` as the leading feature challenger for the next confirmation slice, not as an accepted default.

Recommended next slice:

Keep basket, context, PCA mode, 3x3 state map, pooled-family policy, replay semantics, strategy grid, and benchmark fixed. Expand `momentum_plus_stress` confirmation across additional high-beta windows and use representative trade tapes to verify whether entries actually occur earlier. Defer wider strategy-grid testing until the state-feature signal survives more windows.

## Context-Size Annual Screen Result

Packet:

`runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260710ctxsize/`

Deck:

`presentations/gen5_3_momentum_context_size_screen.pptx`

Wrapper:

`scripts/inspect/run_gen53_momentum_context_size_screen.R`

Purpose:

The one-quarter feature-set slices were too sparse for judging alpha behavior. This screen therefore uses annual stitched OOS windows: four independent quarterly TRAIN-only authority packets are stitched into a one-year portfolio/accounting view. This keeps leakage discipline while giving each condition more time to show trading behavior.

Design actually run:

- live basket: `AMD,NVDA,TSLA,MSTR,AVGO`;
- context recipes: live basket only, live plus high-beta peers, and live plus peers plus risk anchors;
- PCA/state surface: behavioral-pool plus `3x3` quantile states;
- feature sets: `workhorse_enriched`, `momentum_participation`, `momentum_plus_stress`, and `market_relative_momentum`;
- selection policy: `pooled_family_asset_variant`;
- replay semantics: `fresh_signal_only` and `state_switch_continuation`;
- strategy pool: `ema_cross,ema_trend,no_trade,no_trade_exit_immediate`;
- annual windows: `2019`, `2020`, `2022`, and `2024`;
- benchmark: equal-weight buy-and-hold of the same live basket over the same annual stitched OOS window.

Readout:

The best aggregate lane was `hb_risk_aware_18 + workhorse_enriched + state_switch_continuation`. It averaged `81.7%` total return across the four annual windows, but still averaged `-9.8 pp` alpha versus equal-weight high-beta basket hold. It beat basket hold in `2 / 4` annual windows, with mean exposure of `64.6%`.

Interpretation:

Annual windows are now the better default for alpha-oriented screens. The result keeps the broader risk-aware context thesis alive, but it does not promote the new momentum feature sets as defaults. The best current control lane is risk-aware context, the older workhorse PCA surface, and continuation replay. The next useful slice is not a wider grid yet; it is trade-tape and continuity inspection around why the best lane beats in `2022` and `2024` while still missing too much `2019` and `2020` upside.
