# Gen5.1 Current Handoff

Status date: 2026-07-02

This note is the quick restart surface for a new Codex conversation. It summarizes what is working now, where the relevant docs live, and what should not be assumed yet.

## Current Working State

Gen5.1 has a working R-first research POC stack on top of the completed Alpaca adjusted-daily data layer:

- data/workbench queries can load and cache adjusted daily Alpaca bars;
- charting can render single-symbol, multi-symbol, strategy, WFA, and PCA state charts;
- strategy POCs include the green-day hold toy strategy, EMA cross, Bollinger variants, RSI/z-score mean reversion, breakout/pullback variants, volatility-expansion breakout, Donchian volatility breakout, and `no_trade`;
- close-based exit stacks exist in the multi-signal WFA POC, but the current PCA-routed WFA path uses native-only exit stacks;
- multi-fold stitched OOS WFA works for one traded symbol;
- PCA regime labeling works with quantile grids and k-means;
- PCA-routed WFA Option A works with a multi-asset Regime Context Universe and one traded target symbol.
- PCA router comparison reporting can run or consume the current 2x2 `PanelMode x StateMap` surface and summarize OOS metrics, state coverage, selected families, artifact paths, and 2x2 equity/OOS/PCA visual contact sheets.
- PCA context-universe comparison reporting can run the same 2x2 surface for named context universes, then write a top-level universe index/summary with contact-sheet paths while keeping AMD as the only researched/traded/allocated asset.
- Portfolio strategy accounting POC can run five single-symbol PCA-routed WFA child packets, then combine their stitched OOS trades into a shared-account portfolio replay with dynamic equal-slot, cash-capped entry sizing. The first default Active Allocation Set is `AMD,NVDA,TSLA,COIN,MSTR`; treat this as accounting validation, not accepted allocation research.
- Context-universe factorial portfolio inspection can now compare three declared Regime Context Universes for the same five-symbol Active Allocation Set. The smallest run uses `behavioral_pool + quantile_grid 3x3`; the medium wrapper mode adds the 2x2 PCA surface of `contextual_snapshot`/`behavioral_pool` by `quantile_grid 3x3`/`kmeans k9`. The first smallest-run packet is under `runs/research_workbench/context_universe_factorials/ctxfac_A5_5f_3u_pool_3x3_20260624_20260624173000/`. Treat it as research/inspection only, not accepted allocation evidence.
- The emerging stack is now canonized as a Gen5.1 research/inspection engine in `docs/GEN5_1_RESEARCH_ENGINE_CONTRACT.md`. Future experiment wrappers should declare a run spec and call the engine rather than restating the full universe x PCA panel x state map x strategy grid x WFA x portfolio accounting design.
- The current PCA feature set includes Gen4-inspired `chop_14` and `ret_skew_20` in addition to trend, stretch, volatility, efficiency-ratio, and z-score descriptors.
- The Alpaca adjusted-daily research feed now defaults to SIP, while still honoring `ALPACA_DATA_FEED` overrides. A live SIP refresh on 2026-07-01 confirmed `AMD,NVDA,TSLA,AAPL,MSTR,SPY,QQQ,IWM,SMH,TLT,GLD` can be pulled from `2016-01-04`; `VXX` begins on `2018-01-18`, so pre-2018 context tests need an operator decision to replace, omit, or accept that limitation.
- The current PowerPoint summary is `presentations/gen5_recent_pca_context_screening_batch.pptx`. It summarizes the recent Gen5.1 PCA/context screening batch: context universes, PCA panel modes, state-map variants, temporal windows, and the SIP coverage correction.
- A temporary Gen5.1 live-advice bridge now exists for Q3 2026 manual advice continuity. It uses the Gen4 live basket `AMD,NVDA,PLTR,TSLA,SOFI` as the research/tradeable set, the broader Gen4 `RESEARCH_ASSETS` list as the Regime Context Universe, and the Gen4 `daily_default` implemented strategy subset/grid. It freezes quarter-specific authority, uses long/pooled PCA plus `5x5` quantile states, infers position by one-bar-delayed model replay, and writes advice-only daily packets under ignored `runs/live_advice_bridge/`. Daily replay now supports adjacent-quarter continuity: previous-quarter authority is replayed first, open prior-quarter trades remain locked to their entry authority until exit, and current-quarter authority takes over only once the symbol is flat. A dual-policy daily wrapper now writes side-by-side Gen4-style pooled-family and Gen5.1 direct-spec advice under `runs/live_advice_bridge/daily_dual/`; the temporary operator-declared reading rule is AMD under Gen4-style pooled-family and NVDA/PLTR/TSLA/SOFI under Gen5.1 direct-spec. See `docs/GEN5_1_LIVE_ADVICE_BRIDGE.md`. The current frozen bridge uses Alpaca `iex` because recent SIP daily pulls returned a subscription error for July 1 live advice.
- A Gen4-vs-Gen5.1 selection-policy fork is now documented in `docs/GEN5_1_SELECTION_POLICY_HYPOTHESIS.md`. Gen4 Phase50 appears to use `pooled_family_asset_variant`: choose a state-level family from pooled evidence, then choose asset-specific parameters. Current Gen5.1 uses `asset_state_direct_spec`: choose the best full asset/state strategy spec directly. The first paired screen is under `runs/research_workbench/selection_policy_screens/selection_policy_screen_A5_Q2Q3_20260702/`, with visual summaries under `runs/research_workbench/selection_policy_screens/selection_policy_screen_A5_Q2Q3_20260702/visual_summary/`. The broader two-lane robustness packet is complete under `runs/research_workbench/selection_policy_screens/selpol_robust_20260702/`. `A_live` covers `AMD,NVDA,PLTR,TSLA,SOFI` over `2025Q4`-`2026Q3`: direct and pooled-family maps matched on `537 / 625` asset-state rows (`85.92%`), direct led the compact replay proxy in three of four windows and had higher win-rate / trade-return Sharpe proxy in all four, while pooled-family's Q3 advantage was dominated by AMD. `B_hist` covers substitute basket `AMD,NVDA,TSLA,AAPL,MSTR` over `2019Q1`, `2020Q3`, `2022Q1`, `2022Q4`, and `2025Q1`: direct led mean trace return in three of five windows and captured more upside in `2020Q3`, `2022Q1`, and `2025Q1`; pooled-family looked more defensive in weak windows (`2019Q1`, `2022Q4`). Keep direct full-spec selection as the temporary live-bridge default unless the operator explicitly decides otherwise; keep pooled-family as a first-class research factor candidate. Do not merge A-live and B-hist into one leaderboard.
- The newest selection-policy research packet is the basket-archetype screen under `runs/research_workbench/selpol_basket/selpol_basket_20260703/`, with deck `presentations/gen5_selection_policy_basket_archetype_screen.pptx`. It holds active-plus-risk context, behavioral-pool PCA, 3x3 quantile states, and the broad Gen5.1 research grid fixed while comparing `asset_state_direct_spec` vs `pooled_family_asset_variant` across three baskets: current live-like `AMD,NVDA,PLTR,TSLA,SOFI`; long-history high-beta `AMD,NVDA,TSLA,AAPL,MSTR`; and ETF/sector `QQQ,SMH,XLK,XLE,XLF`. Older-history lanes start at `2019Q3` and omit `VXX` from context to avoid pre-2018 partial-history contamination. Readout: pooled-family led the mean replay proxy in the live-like and ETF/sector lanes, direct led the long-history high-beta lane on mean due especially to the `2026Q2` AMD-sensitive window. Do not crown a winner; keep selection policy as an explicit research factor in the next narrow slice.

The newest live-advice bridge surfaces are:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/live/build_live_advice_bridge_authority.ps1 `
  -AsOf "2026-03-31 17:30:00" `
  -Quarter 2026Q2 `
  -Symbols "AMD,NVDA,PLTR,TSLA,SOFI" `
  -ContextSymbols "SPY,QQQ,IWM,DIA,NVDA,TSLA,AMD,PLTR,SOFI,META,AAPL,KO,PEP,WMT,COST,XLF,JPM,BAC,XLE,CVX,XOM,TLT,IEF,GLD,SLV,VNQ,EFA,EEM,UVXY" `
  -CandidateFamilies "ema_cross,ema_trend,bollinger_touch,rsi_mr,zret_mr,breakout,pullback_in_uptrend,no_trade" `
  -StrategyGridPreset gen4_daily_default `
  -Feed iex `
  -NoRefresh

powershell -ExecutionPolicy Bypass -File scripts/live/build_live_advice_bridge_authority.ps1 `
  -AsOf "2026-06-30 17:30:00" `
  -Quarter 2026Q3 `
  -Symbols "AMD,NVDA,PLTR,TSLA,SOFI" `
  -ContextSymbols "SPY,QQQ,IWM,DIA,NVDA,TSLA,AMD,PLTR,SOFI,META,AAPL,KO,PEP,WMT,COST,XLF,JPM,BAC,XLE,CVX,XOM,TLT,IEF,GLD,SLV,VNQ,EFA,EEM,UVXY" `
  -CandidateFamilies "ema_cross,ema_trend,bollinger_touch,rsi_mr,zret_mr,breakout,pullback_in_uptrend,no_trade" `
  -StrategyGridPreset gen4_daily_default `
  -Feed iex `
  -Refresh

powershell -ExecutionPolicy Bypass -File scripts/live/run_live_advice_bridge.ps1 `
  -AsOf "2026-07-01 17:30:00" `
  -Quarter 2026Q3 `
  -Feed iex

powershell -ExecutionPolicy Bypass -File scripts/live/run_dual_live_advice_bridge.ps1 `
  -AsOf "2026-07-01 17:30:00" `
  -Quarter 2026Q3 `
  -Feed iex
```

Current bridge artifacts:

- Previous authority: `runs/live_advice_bridge/authority/2026Q2/`
- Authority: `runs/live_advice_bridge/authority/2026Q3/`
- Daily packet: `runs/live_advice_bridge/daily/2026Q3/20260701173000/`
- Dual-policy daily packet: `runs/live_advice_bridge/daily_dual/2026Q3/20260701173000/`
- Daily result as of `2026-07-01 17:30:00`: pending next-open actions `0`; `AMD` and `PLTR` are flat under current `2026Q3` authority; `NVDA`, `TSLA`, and `SOFI` are long from `2026Q2` continuity carry and remain locked to their prior-quarter entry models until exit.
- Dual-policy smoke result as of `2026-07-01 17:30:00`: pending next-open actions `0` in both lanes. Operator-declared use rows are `AMD` under Gen4-style pooled-family, and `NVDA`, `PLTR`, `TSLA`, `SOFI` under Gen5.1 direct-spec. `SOFI` diverged by policy: flat under Gen4-style pooled-family and long under Gen5.1 direct-spec.

## Newest Selection-Policy / Context Screen

The newest research-inspection packet is:

`runs/research_workbench/selpol_context/selpol_context_20260703/`

It asks whether the Gen5.1 `asset_state_direct_spec` versus Gen4-style `pooled_family_asset_variant` policy fork depends on context-universe construction and basket archetype. It supersedes the earlier basket-archetype pilot as the cleaner evidence surface, while keeping that prior packet as useful history rather than deleting it.

Design:

- PCA/state surface: `behavioral_pool` plus `3x3` quantile states.
- Selection policies: `asset_state_direct_spec` and `pooled_family_asset_variant`.
- High-beta basket: `AMD,NVDA,TSLA,AAPL,MSTR`.
- ETF/sector basket: `QQQ,SMH,XLK,XLE,XLF`.
- Context recipes: broad risk, archetype matched, large diverse, and size-matched diverse.
- Historical replay windows: `2019Q3`, `2020Q3`, `2022Q1`, `2022Q4`, `2025Q1`, and `2026Q2`.
- Guardrails: no `VXX` in behavioral-pool context; no SOFI/PLTR recent-history lane; partial/discontinued `SQ` context replaced with `LRCX`.

Key artifacts:

- Report: `runs/research_workbench/selpol_context/selpol_context_20260703/selection_policy_context_philosophy_report.md`
- Run spec: `runs/research_workbench/selpol_context/selpol_context_20260703/selection_policy_context_philosophy_run_spec.csv`
- Portfolio proxy summary: `runs/research_workbench/selpol_context/selpol_context_20260703/selection_policy_context_philosophy_portfolio_proxy_summary.csv`
- Agreement summary: `runs/research_workbench/selpol_context/selpol_context_20260703/selection_policy_context_philosophy_agreement_summary.csv`
- Benchmark visuals: `runs/research_workbench/selpol_context/selpol_context_20260703/benchmark_visuals/`
- Performance audit: `runs/research_workbench/selpol_context/selpol_context_20260703/performance_audit/HB_broad_risk_no_vxx/`
- Slide deck: `presentations/gen5_selection_policy_context_philosophy_screen.pptx`
- Deck builder: `scripts/inspect/build_selection_policy_context_philosophy_presentation.mjs`
- Benchmark builder: `scripts/inspect/build_selection_policy_context_benchmark_visuals.R`
- Performance audit builder: `scripts/inspect/build_selection_policy_context_performance_audit.R`

Initial readout, still inspection only:

- High-beta broad-risk favored direct on mean trace return (`6.9%` direct versus `4.9%` pooled).
- High-beta matched, large-diverse, and size-matched-diverse favored pooled-family (`9.0%`, `8.5%`, `5.3%` pooled versus `2.6%`, `-1.8%`, `-2.6%` direct).
- ETF/sector broad-risk modestly favored pooled (`7.7%` versus `6.6%`), while ETF matched, large-diverse, and size-matched-diverse favored direct or were near direct (`6.5%` vs `6.0%`, `5.3%` vs `2.7%`, `4.3%` vs `4.1%`).
- Selection maps are related but not interchangeable. Across all frozen state/asset rows, family-match rates were `57.0%`-`64.6%` for high-beta contexts and `54.3%`-`59.1%` for ETF contexts.
- A local benchmark pass now compares each strategy replay proxy against equal-weight buy-and-hold of the same live basket over the same replay dates. This is a useful alpha lens, not accepted allocation evidence. It showed every lane with negative mean excess return versus basket hold. Best mean excess was still negative for high beta (`HB / matched / pooled`, `-13.7 pp`, `1/6` beat windows) and ETF/sector (`ETF / broad risk / pooled`, `-6.4 pp`, `2/6` beat windows).
- A focused performance audit of `HB_broad_risk_no_vxx` adds trade tapes, exposure/participation heatmaps, trade-duration scatter, and state-accountability visuals. In the 2020Q3 high-upside stress window, direct had `13` wins / `3` losses and pooled had `15` wins / `2` losses, but mean exposure was only `35.5%` direct and `48.3%` pooled. This suggests the main failure mode was under-participation in strong basket upside, not simply catastrophic trade picking.
- Do not crown a final policy or context. The main finding is that selection policy, basket archetype, context philosophy, and benchmark-relative participation interact enough to keep all four explicit in the next research gate. Recommended narrow next slice: add alpha diagnostics before expanding the factorial again. Separate exposure, upside participation, downside avoidance, state accountability, and selection-policy effects.

The newest operator surface is:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/inspect/run_pca_comparison_report.ps1 `
  -Symbol AMD `
  -RegimeContextSymbols "AMD,NVDA,TSLA" `
  -EndDate 2026-06-24 `
  -AsOfTimestamp "2026-06-24 17:30:00" `
  -FoldCount 5 `
  -QuantileStateCount 3 `
  -KmeansStateCount 9 `
  -Refresh
```

The comparison wrapper runs four child packets through `scripts/inspect/run_pca_router_workbench.ps1`, then writes a compact comparison packet under ignored `runs/research_workbench/regime_wfa_comparisons/`. Use `-SkipChildRuns` to rebuild the comparison report and visual contact sheets from already-generated child packets.

The context-universe wrapper runs the comparison wrapper for:

- `baseline_context`: `AMD,NVDA,TSLA`
- `similar_high_beta_tech_semis`: `AMD,NVDA,TSLA,SMH,AVGO,MU,INTC`
- `diverse_market_risk_context`: `AMD,NVDA,TSLA,SPY,QQQ,IWM,SMH,TLT,GLD,VXX`

```powershell
powershell -ExecutionPolicy Bypass -File scripts/inspect/run_pca_context_universe_panels.ps1 `
  -Symbol AMD `
  -EndDate 2026-06-24 `
  -AsOfTimestamp "2026-06-24 17:30:00" `
  -FoldCount 5 `
  -QuantileStateCount 3 `
  -KmeansStateCount 9 `
  -Refresh
```

The top-level packet is written under ignored `runs/research_workbench/regime_wfa_universe_comparisons/`. It includes a metrics overview PNG plus cross-universe equity, stitched OOS/state-band, and PCA scatter overview PNGs split by `contextual_snapshot` and `behavioral_pool` so each image has six panels instead of one overloaded 12-panel contact sheet. Treat it as a comparison scaffold, not final research evidence.

The newest portfolio accounting POC surface is:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/inspect/run_portfolio_strategy_poc.ps1 `
  -EndDate 2026-06-24 `
  -AsOfTimestamp "2026-06-24 17:30:00" `
  -Refresh
```

Default active symbols are `AMD,NVDA,TSLA,COIN,MSTR`; default context symbols are `AMD,NVDA,TSLA,COIN,MSTR,SMH,QQQ,SPY,IWM,TLT,GLD,VXX`; default surface is `behavioral_pool + quantile_grid 3x3`, five folds, the broader Gen5.1 research candidate families using the Gen4 `daily_default` parameter-grid breadth where applicable, `$100,000` initial capital, five slots, and SPY as the passive market baseline. The first completed packet is:

`runs/research_workbench/portfolio_strategy_pocs/portfolio_poc_AMD-NVDA-TSLA-COIN-MSTR_5f_3x3_pooled12ctx_20260624_20260624173000/`

It includes a report, event ledger, portfolio equity curve, passive baseline curves/metrics, standalone per-symbol reference curves, symbol summary, child artifact index, and PNG chart. The portfolio curve is the authoritative accounting POC output; passive baselines include full-capital SPY buy-and-hold and equal active-set buy-and-hold; per-symbol curves are standalone references scaled to one slot.

Use `-SkipChildRuns` to rebuild the portfolio accounting/report packet from already-generated child PCA WFA packets without rerunning all five child WFA simulations.

The newest context-universe factorial portfolio surface is:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/inspect/run_context_universe_factorial_portfolio.ps1 `
  -EndDate 2026-06-24 `
  -AsOfTimestamp "2026-06-24 17:30:00" `
  -SkipChildRuns
```

The top-level packet is:

`runs/research_workbench/context_universe_factorials/ctxfac_A5_5f_3u_pool_3x3_20260624_20260624173000/`

It includes `context_universe_factorial_report.md`, run spec, taxonomy, summary CSV, portfolio packet index, child artifact index, and metrics overview PNG. The report states the plain-language purpose: test whether regime labels for the same active set look more useful and stable when built from active-self context, active-plus-risk context, or external market-risk context only.

Use `-MediumGrid` to run the declared medium experiment across four PCA surfaces:

- `contextual_snapshot_quantile_grid`: `date_aligned_context + quantile_grid 3x3`
- `contextual_snapshot_kmeans`: `date_aligned_context + pca_kmeans k9`
- `behavioral_pool_quantile_grid`: `pooled_asset_day + quantile_grid 3x3`
- `behavioral_pool_kmeans`: `pooled_asset_day + pca_kmeans k9`

The medium-capable top-level packet also writes surface definitions, child OOS metric summary, child state coverage summary, and selected-family summary CSVs.

## Inspection Discipline For New Threads

To keep research handoffs and inspection work clear:

- Read `AGENTS.md` and this handoff first; for engine-wrapper work, also read `docs/GEN5_1_RESEARCH_ENGINE_CONTRACT.md`.
- Use generated report paths under ignored `runs/` as evidence surfaces; do not paste large generated tables into prompts unless necessary.
- For long research runs, inspect run spec/manifest, health, summary CSV, report Markdown, and selected charts before opening raw child tables.
- Prefer `-SkipChildRuns` for report regeneration or follow-up inspection once child artifacts exist.
- Prefer Medium reasoning for scoped implementation, known reruns, doc updates, commits, and pushes.
- Prefer High reasoning for research gates, leakage-safety design, result interpretation, and new methodology decisions.
- Keep handoffs compact: state the current branch, exact artifact/report path, active decision, and STOP states rather than copying full experiment output.

## Current PCA Vocabulary

Universes:

- **Regime Context Universe**: symbols used to create the PCA state feature panel, such as `AMD,NVDA,TSLA`.
- **Research Candidate Universe**: symbols whose strategy specs are evaluated. Current single-symbol PCA-routed POC: the single `-Symbol`; portfolio accounting POC default: `AMD,NVDA,TSLA,COIN,MSTR`.
- **Tradeable Universe**: symbols the replay may trade. Current single-symbol PCA-routed POC: the single `-Symbol`; portfolio accounting POC default: `AMD,NVDA,TSLA,COIN,MSTR`.
- **Active Allocation Set**: symbols actually held/allocated during replay. Current single-symbol PCA-routed POC: the single `-Symbol`, all-in/flat; portfolio accounting POC default: five shared-account slots.

Panel modes:

- `contextual_snapshot`: operator name for the wide/date-aligned PCA panel. Internally this maps to `date_aligned_context`. It asks: what same-day multi-asset context surrounds the traded asset?
- `behavioral_pool`: operator name for the long/pooled asset-day PCA panel. Internally this maps to `pooled_asset_day`. It asks: what recurring asset-day behavior type does the traded asset resemble?

State maps:

- `quantile_grid`: PC1/PC2 quantile binning. `-StateCount 3` means a 3x3 grid.
- `kmeans`: k-means clustering on TRAIN PC1/PC2. `-StateCount 9` means nine clusters.

## Important Current Policy

PCA-routed WFA currently uses Option A: `entry_state_owns_trade_until_exit`.

That means the state active on the entry signal date selects the complete `strategy_spec_id`. Once the trade opens, that same spec owns native exits until the trade closes, even if the PCA state changes. This is conservative and auditable. Option B, state-adaptive exit management, is documented but not implemented.

## What Is Not Implemented Yet

Do not assume any of the following exist as production-ready systems:

- portfolio allocation;
- multi-asset pooled/global parameter selection;
- state-adaptive exits;
- leverage/risk overlay beyond earlier isolated POCs;
- live advice generation;
- dashboards;
- broker execution;
- non-Alpaca providers.

Generated run artifacts live under ignored `runs/` folders and should not be committed.

## Key Docs To Read Next

- `README.md`: operator commands and current POC surfaces.
- `docs/GEN5_1_RESEARCH_ENGINE_CONTRACT.md`: canonized research/inspection engine layers, run-spec vocabulary, artifact contract, wrapper pattern, and STOP boundaries.
- `docs/GEN5_1_SELECTION_POLICY_HYPOTHESIS.md`: current methodology fork between Gen4 pooled-family selection and Gen5.1 direct asset/state spec selection.
- `docs/GEN5_REGIME_FILTER_POC_PLAN.md`: regime/PCA theory, vocabulary, policies, and next POC ideas.
- `docs/GEN5_1_PORTFOLIO_STRATEGY_POC_PLAN.md`: first portfolio accounting POC policy, defaults, STOP guardrails, and output contract.
- `docs/GEN5_TASK_QUEUE.md`: current status and backlog memory.
- `AGENTS.md`: autonomy/collaboration rules and validation expectations.

## Suggested Next Conversation Prompts

Use one of these as the first prompt in a new conversation:

```text
Please continue on branch codex/Gen5.1-context-universe-factorial-plan. Read AGENTS.md, docs/GEN5_1_CURRENT_HANDOFF.md, and docs/GEN5_1_SELECTION_POLICY_HYPOTHESIS.md first. Inspect the completed two-lane selection-policy robustness packet under runs/research_workbench/selection_policy_screens/selpol_robust_20260702/. Do not change live bridge behavior. Recommend the next declared research slice now that A_live favors direct as the bridge default while B_hist keeps pooled-family alive as a first-class research factor candidate.
```

```text
Please start on branch codex/Gen5.1-engine-wrapper-next-experiment. Read AGENTS.md, docs/GEN5_1_CURRENT_HANDOFF.md, and docs/GEN5_1_RESEARCH_ENGINE_CONTRACT.md first. Use the Gen5.1 research engine contract to create a thin wrapper for the next declared experiment. Keep it research/inspection only, produce concrete charts/reports, validate, commit, and push.
```

```text
Please start on branch codex/Gen5.1-state-adaptive-exit-plan. Read AGENTS.md and docs/GEN5_1_CURRENT_HANDOFF.md first. Do not implement yet. Compare Option A entry-state ownership versus Option B state-adaptive exit management, define leakage-safe TRAIN/OOS mechanics for Option B, and propose the smallest POC task list.
```

## Validation Reminder

Before closing implementation branches, run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1
```

For final operator smokes that touch cached market data, prefer `-Refresh` unless there is a specific reason not to refresh.
