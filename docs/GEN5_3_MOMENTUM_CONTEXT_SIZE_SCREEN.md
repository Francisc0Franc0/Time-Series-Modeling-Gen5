# Gen5.3 Momentum Context-Size Annual Screen

Status date: 2026-07-10

This is a research/inspection note, not allocation evidence, live advice, or execution approval.

## Why This Screen Exists

The first Gen5.3 bullish momentum specialist slices used one-quarter OOS windows. That was useful for plumbing and quick falsification, but too sparse for judging alpha behavior when the live basket has only a few assets. A one-quarter window can easily be dominated by one late entry, one missed move, or one asset-specific burst.

This screen moves to annual OOS assessment windows. Each annual window stitches four independent quarterly TRAIN-only authority packets into a one-year downstream portfolio/accounting view. That gives the system more opportunity to trade while preserving the rule that authority is fit from TRAIN information only.

## Question

Can a narrowed EMA-only momentum specialist become more useful when we vary:

- Regime Context Universe size and composition;
- PCA feature set;
- fresh-signal versus state-switch-continuation replay;
- annual OOS windows instead of one-quarter OOS windows?

## Design

- Live basket: `AMD,NVDA,TSLA,MSTR,AVGO`.
- PCA panel/state surface: behavioral-pool PCA plus `3x3` quantile states.
- Selection policy: `pooled_family_asset_variant`.
- Strategy pool: `ema_cross`, `ema_trend`, `no_trade`, `no_trade_exit_immediate`.
- Accounting: true shared-account live-capital replay with dynamic equal-slot, cash-capped entries.
- Benchmark: equal-weight buy-and-hold of the same live basket over the same annual stitched OOS window.
- Annual windows: `2019`, `2020`, `2022`, and `2024`.

Context recipes:

- `hb_self_5`: live basket only.
- `hb_peer_12`: live basket plus high-beta peers and sector proxies.
- `hb_risk_aware_18`: live basket plus high-beta peers, sector proxies, and broad risk anchors.

Feature sets:

- `workhorse_enriched`;
- `momentum_participation`;
- `momentum_plus_stress`;
- `market_relative_momentum`.

## Primary Artifacts

- Packet: `runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260710ctxsize/`
- Report: `runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260710ctxsize/momentum_context_size_report.md`
- Summary: `runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260710ctxsize/momentum_context_size_summary.csv`
- Aggregate: `runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260710ctxsize/momentum_context_size_aggregate.csv`
- Deck: `presentations/gen5_3_momentum_context_size_screen.pptx`

## Readout

The best aggregate lane was:

`hb_risk_aware_18 + workhorse_enriched + state_switch_continuation`

It returned `81.7%` on average across the four annual windows, but still averaged `-9.8 pp` alpha versus equal-weight basket hold. It beat the basket in `2 / 4` annual windows, with mean exposure of `64.6%`.

Interpretation:

- Annual windows are a better default for alpha-oriented screens than one-quarter OOS slices.
- The broader risk-aware context finding is still alive and looks stronger than active-only context in this screen.
- The new momentum feature sets did not become the aggregate default.
- Continuation replay remains useful, but simply increasing exposure is not enough.
- The benchmark is harsh and appropriate: a bullish high-beta specialist must compete with simply holding the high-beta basket.

## Guardrails

- Do not treat this as accepted allocation evidence.
- Do not change live advice behavior from this result.
- Do not promote the new momentum feature sets as defaults from this screen.
- Treat the annual window shape as research-inspection only: it stitches quarterly authority packets for assessment and does not yet establish a final live continuity policy.

## Recommended Next Slice

Use `hb_risk_aware_18 + workhorse_enriched + state_switch_continuation` as the near-term control lane. Audit the full trade tapes for `2024` and the missed-upside behavior in `2020`, then test whether annual windows should use a stricter cross-quarter live-continuity replay rather than stitched independent quarterly authorities.
