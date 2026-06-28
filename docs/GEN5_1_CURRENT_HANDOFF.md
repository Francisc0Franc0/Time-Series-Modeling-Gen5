# Gen5.1 Current Handoff

Status date: 2026-06-28

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
- The current PCA feature set includes Gen4-inspired `chop_14` and `ret_skew_20` in addition to trend, stretch, volatility, efficiency-ratio, and z-score descriptors.

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

## Context Discipline For New Threads

To keep Codex context usage manageable:

- Read `AGENTS.md` and this handoff first; only read deeper docs when the task needs them.
- Use generated report paths under ignored `runs/` as evidence surfaces; do not paste large generated tables into prompts unless necessary.
- Prefer Medium reasoning for scoped implementation, known reruns, doc updates, commits, and pushes.
- Prefer High reasoning for research gates, leakage-safety design, result interpretation, and new methodology decisions.
- Keep handoffs compact: state the current branch, exact artifact/report path, active decision, and STOP states rather than copying full experiment output.

## Current PCA Vocabulary

Universes:

- **Regime Context Universe**: symbols used to create the PCA state feature panel, such as `AMD,NVDA,TSLA`.
- **Research Candidate Universe**: symbols whose strategy specs are evaluated. Current PCA-routed POC: the single `-Symbol`.
- **Tradeable Universe**: symbols the replay may trade. Current PCA-routed POC: the single `-Symbol`.
- **Active Allocation Set**: symbols actually held/allocated during replay. Current PCA-routed POC: the single `-Symbol`, all-in/flat.

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
- `docs/GEN5_REGIME_FILTER_POC_PLAN.md`: regime/PCA theory, vocabulary, policies, and next POC ideas.
- `docs/GEN5_TASK_QUEUE.md`: current status and backlog memory.
- `AGENTS.md`: autonomy/collaboration rules and validation expectations.

## Suggested Next Conversation Prompts

Use one of these as the first prompt in a new conversation:

```text
Please start on branch codex/Gen5.1-regime-universe-scaleout. Read AGENTS.md and docs/GEN5_1_CURRENT_HANDOFF.md first. Then propose and implement a careful next expansion of the Regime Context Universe beyond AMD,NVDA,TSLA while keeping Research Candidate Universe, Tradeable Universe, and Active Allocation Set as AMD only. Produce concrete charts/reports and validate.
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
