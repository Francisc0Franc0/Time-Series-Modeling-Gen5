# Gen5.1 Temporary Live Advice Bridge

Status date: 2026-07-01

This bridge keeps daily advice-first operation available while the final Gen5.1 production layer is still under construction. It freezes quarter-specific authority from completed prior-quarter data, then replays the frozen model daily to infer current position and next-open advice.

Daily replay now supports quarter continuity: when the immediately previous authority packet is present, the bridge replays the previous quarter first, carries any open prior-quarter trade until its frozen exit rule closes it, and only switches to current-quarter authority once the symbol is flat. A signal generated on the last session of the previous quarter may execute on the first session of the new quarter because the signal decision was made while that authority was still valid.

It is not accepted allocation evidence, not automation, and not an order-entry system.

## Current Q3 2026 Bridge

- Basket: `AMD,NVDA,PLTR,TSLA,SOFI`
- Regime Context Universe: Gen4 `RESEARCH_ASSETS` equivalent: `SPY,QQQ,IWM,DIA,NVDA,TSLA,AMD,PLTR,SOFI,META,AAPL,KO,PEP,WMT,COST,XLF,JPM,BAC,XLE,CVX,XOM,TLT,IEF,GLD,SLV,VNQ,EFA,EEM,UVXY`
- Authority quarter: `2026Q3`
- Previous continuity authority: `2026Q2`
- TRAIN window: `2024-07-01` through `2026-06-30`
- Live authority window: `2026-07-01` through `2026-09-30`
- PCA mode: long/pooled asset-day PCA (`pooled_asset_day`)
- State map: `5x5` quantile grid
- Candidate families: Gen4 `daily_default` implemented subset: `ema_cross`, `ema_trend`, `bollinger_touch`, `rsi_mr`, `zret_mr`, `breakout`, `pullback_in_uptrend`, `no_trade`
- Strategy grid preset: `gen4_daily_default`
- Resolved model grid: 172 model instances: EMA cross 14, EMA trend 11, Bollinger touch 9, RSI mean reversion 36, return-z mean reversion 18, breakout 2, pullback-in-uptrend 81, no-trade 1
- Position source: model replay with one-bar delayed next-open execution
- Continuity source: adjacent previous-quarter replay before current-quarter replay
- Alpaca feed used for the bridge: `iex`

The bridge uses `iex` because the July 1, 2026 daily live pull returned an Alpaca subscription error for recent `sip` data. The feed is recorded in the authority and daily query manifests.

## Build Frozen Authority

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
```

Current authority folder:

`runs/live_advice_bridge/authority/2026Q3/`

Previous continuity authority folder:

`runs/live_advice_bridge/authority/2026Q2/`

Key artifacts:

- `bridge_authority_contract.csv`
- `bridge_selected_states.csv`
- `bridge_pca_model_contract.csv`
- `bridge_authority_report.md`

## Run Daily Advice Packet

```powershell
powershell -ExecutionPolicy Bypass -File scripts/live/run_live_advice_bridge.ps1 `
  -AsOf "2026-07-01 17:30:00" `
  -Quarter 2026Q3 `
  -Feed iex
```

Current daily packet:

`runs/live_advice_bridge/daily/2026Q3/20260701173000/`

Key artifacts:

- `bridge_operator_packet.csv`
- `bridge_pending_actions.csv`
- `bridge_book_summary.csv`
- `bridge_replay.csv`
- `bridge_executions.csv`
- `bridge_trades.csv`
- `bridge_continuity.csv`
- `bridge_contact_sheet.png`
- `bridge_daily_report.md`

Current July 1 readout after rebuilding with previous-quarter continuity:

- `AMD`: `FLAT`, current `2026Q3` authority from quarter start, no pending action.
- `NVDA`: `LONG`, open trade carried from `2026Q2` authority, locked to `rsi_mr_n7_lo30_hi75__native_only`.
- `PLTR`: `FLAT`, current `2026Q3` authority from quarter start, no pending action.
- `TSLA`: `LONG`, open trade carried from `2026Q2` authority, locked to `rsi_mr_n7_lo25_hi65__native_only`.
- `SOFI`: `LONG`, open trade carried from `2026Q2` authority, locked to `ema_trend_fast15_slow50__native_only`.
- Pending next-open actions: `0`.

## Dual-Policy Daily Advice Packet

The live bridge can now write a side-by-side daily packet for both selection-policy lanes:

- **Gen4-style pooled-family**: `pooled_family_asset_variant`
- **Gen5.1 direct-spec**: `asset_state_direct_spec`

This does not change the underlying frozen authority, place orders, or approve a final methodology. It lets the operator inspect both policy interpretations during the temporary bridge period.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/live/run_dual_live_advice_bridge.ps1 `
  -AsOf "2026-07-01 17:30:00" `
  -Quarter 2026Q3 `
  -Feed iex
```

Current dual-policy smoke packet:

`runs/live_advice_bridge/daily_dual/2026Q3/20260701173000/`

Key artifacts:

- `dual_bridge_advice_summary.csv`: text-based advice rows for every symbol under both policy lanes.
- `dual_bridge_operator_policy_preference.csv`: records the temporary operator-declared reading rule.
- `dual_bridge_contact_sheet.png`: side-by-side chart sheet with Gen4-style pooled-family on the left and Gen5.1 direct-spec on the right.
- `gen4_pooled_family/`: full single-policy packet and per-symbol charts for the Gen4-style lane.
- `gen5_1_direct_spec/`: full single-policy packet and per-symbol charts for the Gen5.1 lane.

Temporary operator-declared reading rule:

- Read `AMD` primarily under the Gen4-style pooled-family lane.
- Read `NVDA`, `PLTR`, `TSLA`, and `SOFI` primarily under the Gen5.1 direct-spec lane.
- Keep both lanes visible because this is an interim continuity choice, not a final research conclusion.

The July 1 cached smoke showed no pending next-open actions in either lane. It did show policy divergence in model position for `SOFI`: flat under the Gen4-style lane and long under the Gen5.1 lane.

## Daily Automation

A Codex app automation is configured to run the dual-policy bridge on weekdays at 1:15 PM Pacific, after the regular market close. The automation should refresh the cache, write a new dual-policy packet under `runs/live_advice_bridge/daily_dual/`, and summarize symbol-level text advice for the operator.

If a refresh produces `refresh_needed`, `partial_history`, stale-cache, subscription, or provider WARN/ERROR rows, treat the packet as a transparency surface and inspect the health CSV before relying on the advice rows.

## Operator Reading Order

1. Read `bridge_book_summary.csv`.
2. Read `bridge_pending_actions.csv`.
3. Inspect `bridge_contact_sheet.png`.
4. If needed, inspect the per-asset candlestick `bridge_chart_*.png` files.
5. Treat any manual trading decision as an operator decision, not as automatic execution.

For the dual-policy packet, read:

1. `dual_bridge_advice_summary.csv`
2. `dual_bridge_operator_policy_preference.csv`
3. `dual_bridge_contact_sheet.png`
4. The policy-specific folders only if the combined packet needs a closer chart audit.
