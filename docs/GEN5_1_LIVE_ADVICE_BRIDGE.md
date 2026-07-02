# Gen5.1 Temporary Live Advice Bridge

Status date: 2026-07-01

This bridge keeps daily advice-first operation available while the final Gen5.1 production layer is still under construction. It freezes one quarter of authority from completed prior-quarter data, then replays the frozen model daily to infer current position and next-open advice.

It is not accepted allocation evidence, not automation, and not an order-entry system.

## Current Q3 2026 Bridge

- Basket: `AMD,NVDA,PLTR,TSLA,SOFI`
- Regime Context Universe: Gen4 `RESEARCH_ASSETS` equivalent: `SPY,QQQ,IWM,DIA,NVDA,TSLA,AMD,PLTR,SOFI,META,AAPL,KO,PEP,WMT,COST,XLF,JPM,BAC,XLE,CVX,XOM,TLT,IEF,GLD,SLV,VNQ,EFA,EEM,UVXY`
- Authority quarter: `2026Q3`
- TRAIN window: `2024-07-01` through `2026-06-30`
- Live authority window: `2026-07-01` through `2026-09-30`
- PCA mode: long/pooled asset-day PCA (`pooled_asset_day`)
- State map: `5x5` quantile grid
- Candidate families: `ema_cross`, `bollinger_touch`, `no_trade`
- Position source: model replay with one-bar delayed next-open execution
- Alpaca feed used for the bridge: `iex`

The bridge uses `iex` because the July 1, 2026 daily live pull returned an Alpaca subscription error for recent `sip` data. The feed is recorded in the authority and daily query manifests.

## Build Frozen Authority

```powershell
powershell -ExecutionPolicy Bypass -File scripts/live/build_live_advice_bridge_authority.ps1 `
  -AsOf "2026-06-30 17:30:00" `
  -Quarter 2026Q3 `
  -Symbols "AMD,NVDA,PLTR,TSLA,SOFI" `
  -ContextSymbols "SPY,QQQ,IWM,DIA,NVDA,TSLA,AMD,PLTR,SOFI,META,AAPL,KO,PEP,WMT,COST,XLF,JPM,BAC,XLE,CVX,XOM,TLT,IEF,GLD,SLV,VNQ,EFA,EEM,UVXY" `
  -Feed iex `
  -Refresh
```

Current authority folder:

`runs/live_advice_bridge/authority/2026Q3/`

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
- `bridge_contact_sheet.png`
- `bridge_daily_report.md`

## Operator Reading Order

1. Read `bridge_book_summary.csv`.
2. Read `bridge_pending_actions.csv`.
3. Inspect `bridge_contact_sheet.png`.
4. If needed, inspect the per-asset candlestick `bridge_chart_*.png` files.
5. Treat any manual trading decision as an operator decision, not as automatic execution.
