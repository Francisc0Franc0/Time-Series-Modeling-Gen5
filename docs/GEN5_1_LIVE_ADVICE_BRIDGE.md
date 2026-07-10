# Gen5.1 Temporary Live Advice Bridge

Status date: 2026-07-10

This bridge keeps daily advice-first operation available while the final Gen5.1 production layer is still under construction. It freezes quarter-specific authority from completed prior-quarter data, then replays the frozen model daily to infer current position and next-open advice.

Daily replay now supports quarter continuity: when the immediately previous authority packet is present, the bridge replays the previous quarter first, carries any open prior-quarter trade until its frozen exit rule closes it, and only switches to current-quarter authority once the symbol is flat. A signal generated on the last session of the previous quarter may execute on the first session of the new quarter because the signal decision was made while that authority was still valid.

It is not accepted allocation evidence, not automation, and not an order-entry system.

## Incident Guardrail: Frozen Bridge Semantics

Status date: 2026-07-08

The temporary live bridge is operational continuity infrastructure, not a Gen5.X research surface. Gen5.X research work may add or revise selection policies, replay semantics, strategy families, portfolio accounting, or diagnostics, but it must not silently change live bridge selection, replay, continuity, or advice behavior.

The July 2026 dual-policy bridge incident exposed this boundary: the Gen5.1 direct-spec lane was intended to consume frozen `bridge_selected_states.csv` rows, but later Gen5.2 selection-policy work caused the daily direct lane to rebuild selected states from `bridge_train_state_performance.csv`. That meant the authority folder could stay the same while daily advice changed underneath it.

Freeze-guard behavior:

- The live bridge direct-spec lane must consume frozen `bridge_selected_states.csv` rows.
- The direct-spec lane must not recompute direct selection from `bridge_train_state_performance.csv` during daily advice.
- The pooled-family lane may use frozen `bridge_train_state_performance.csv` only as the explicitly labeled side-by-side Gen4-style inspection lane.
- For previous-quarter continuity in the operator-used Gen4-style pooled-family lane, the bridge should consume actual Gen4 `Phase50_Quarterly_FreezePack` authority and actual Gen4 `Phase60_Daily_LiveRunner` open-position status when those artifacts are available, instead of reconstructing Gen4 authority from Gen5 train-performance tables.
- Daily packets write runtime provenance with branch, git SHA, dirty status, and `live_bridge_code_version`.
- Changing these semantics is a live-bridge behavior change and requires an explicit operator decision.

## Incident Guardrail: Gen4 Open-Position Carry

Status date: 2026-07-10

The AMD continuity audit found a second bridge containment issue. The bridge had been protected against direct-spec recomputation, but the Gen4-style pooled-family prior-quarter continuity lane was still approximating Gen4 authority from Gen5 bridge artifacts and replaying forward from fresh signals. That can miss a real live position that was already open before the bridge replay window.

Observed example:

- Gen4 `Phase60_Daily_LiveRunner` showed `AMD` long on `2026-06-30`, with `HOLD_LONG`, `ALREADY_IN_POSITION`, state `1_1`, and strategy `ema_cross_f10_s20`.
- The bridge prior to this fix showed `AMD` flat because the reconstructed Gen5-side prior-quarter replay did not contain the already-open Gen4 live position.

Patched behavior:

- For the Gen4-style pooled-family previous-continuity lane, the dual bridge reads Gen4 `phase50_asset_variant_map.csv` as the previous-quarter frozen authority when present.
- It also reads Gen4 `phase60_operator_packet.csv` as an open-position seed when present.
- A seeded open position remains locked to its seeded strategy until the frozen native exit closes it, then current-quarter authority may take over.
- This remains advice-only. It does not place orders or approve a methodology.

Known limitation:

- Gen4 Phase60 status artifacts identify the live handoff date and current held strategy, but not necessarily the original historical entry date. In that case the bridge trade tape seeds the open trade at the Phase60 handoff date, so the chart correctly shows the carried live position but may not reconstruct the full original dotted-line entry history.

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
- Resolved model grid: 191 model instances: EMA cross 14, EMA trend 11, Bollinger touch 12, RSI mean reversion 36, return-z mean reversion 27, breakout 9, pullback-in-uptrend 81, no-trade 1
- Gen4 containment note: the preset contains the active, implemented non-SMA parameter values exported by Gen4 artifact `FM-002-024-R3_med_16_bins/active_param_grid_daily_default.csv`, including Bollinger lookback 10, return-z entry 1.5, breakout lookback 10, and nonzero breakout buffers. Gen4 SMA families remain excluded here because they were inactive in the daily-default surface used for this bridge.
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

Current July 8 AMD continuity smoke after importing Gen4 Phase50/Phase60 prior-quarter carry:

- `AMD` under the operator-used Gen4-style pooled-family lane: `LONG`, open trade carried from `2026Q2` Gen4 continuity, locked to `ema_cross_fast10_slow20__native_only`, no next-open action.
- The visible trade trace starts at the Gen4 Phase60 handoff date because the available Gen4 Phase60 status packet records the held position, not the original full trade entry date.

Historical July 1 single-policy packet after the first previous-quarter continuity rebuild, before the July 10 Gen4 Phase50/Phase60 open-position seed guardrail:

- `AMD`: `FLAT`, current `2026Q3` authority from quarter start, no pending action. This older reading is superseded for the operator-used Gen4-style pooled-family lane by the July 10 Gen4 open-position carry fix above.
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
- `dual_bridge_runtime_provenance.csv`: records branch, git SHA, dirty status, and live bridge code/version marker.
- `dual_bridge_contact_sheet.png`: side-by-side chart sheet with Gen4-style pooled-family on the left and Gen5.1 direct-spec on the right.
- `gen4_pooled_family/`: full single-policy packet and per-symbol charts for the Gen4-style lane.
- `gen5_1_direct_spec/`: full single-policy packet and per-symbol charts for the Gen5.1 lane.

Stable latest surface:

`runs/live_advice_bridge/latest/`

This folder is overwritten by each successful dual-policy run and is the fastest daily reading surface. The timestamped packet remains the audit trail.

- `dual_bridge_latest_advice.csv`
- `dual_bridge_latest_advice.md`
- `dual_bridge_latest_contact_sheet.png`
- `dual_bridge_latest_runtime_provenance.csv`
- `dual_bridge_latest_manifest.csv`

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

1. `runs/live_advice_bridge/latest/dual_bridge_latest_advice.md`
2. `runs/live_advice_bridge/latest/dual_bridge_latest_advice.csv`
3. `runs/live_advice_bridge/latest/dual_bridge_latest_contact_sheet.png`
4. `runs/live_advice_bridge/latest/dual_bridge_latest_runtime_provenance.csv`
5. `runs/live_advice_bridge/latest/dual_bridge_latest_manifest.csv` to find the source timestamped packet.
6. The policy-specific folders only if the combined packet needs a closer chart audit.
