# Gen5.3 Momentum Context-Size Annual Screen

Status date: 2026-07-11

This is a research/inspection note, not allocation evidence, live advice, or execution approval.

## Why This Screen Exists

The first Gen5.3 bullish momentum specialist slices used one-quarter OOS windows. That was useful for plumbing and quick falsification, but too sparse for judging alpha behavior when the live basket has only a few assets. A one-quarter window can easily be dominated by one late entry, one missed move, or one asset-specific burst.

This screen moves to annual OOS assessment windows. The first packet stitched four independent quarterly TRAIN-only authority/replay packets into a one-year downstream portfolio/accounting view. A follow-up packet then reran the same authority packets with cross-quarter continuity: open trades remain locked to their entry-quarter authority until exit, and new entries use the authority active when the symbol is flat.

That distinction matters. The continuity packet is the more live-faithful annual assessment surface. It asks: what if the system ran for a full year as designed, with quarterly authority refreshes but no artificial forced reset at quarter boundaries?

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
- Benchmark: equal-weight buy-and-hold of the same live basket over the same annual OOS window.
- Annual windows: `2019`, `2020`, `2022`, and `2024`.
- Annual replay modes:
  - `quarter_independent_stitch`: original inspection packet; each quarter is replayed independently, then stitched for annual accounting.
  - `quarter_continuity_replay`: live-faithful packet; independent quarterly authority fitting is preserved, but open trades can carry through quarter boundaries until flat.

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

- Independent-stitch packet: `runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260710ctxsize/`
- Continuity packet: `runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260711continuity/`
- Continuity report: `runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260711continuity/momentum_context_size_report.md`
- Continuity summary: `runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260711continuity/momentum_context_size_summary.csv`
- Continuity aggregate: `runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260711continuity/momentum_context_size_aggregate.csv`
- Continuity audit: `runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260711continuity/momentum_context_size_continuity.csv`
- Deck: `presentations/gen5_3_momentum_context_size_screen.pptx`

## Readout

The original independent-stitch packet's best aggregate lane was:

`hb_risk_aware_18 + workhorse_enriched + state_switch_continuation`

It returned `81.7%` on average across the four annual windows, but still averaged `-9.8 pp` alpha versus equal-weight basket hold. It beat the basket in `2 / 4` annual windows, with mean exposure of `64.6%`.

The continuity replay rerun kept the same top-ranked lane:

`hb_risk_aware_18 + workhorse_enriched + state_switch_continuation`

But the more live-faithful replay lowered the result materially: `55.9%` mean return, `-35.6 pp` mean alpha versus equal-weight basket hold, `2 / 4` windows beating basket, and `40.3%` mean exposure.

The continuity audit confirms that the new packet exercised the intended mechanics: `448` symbol/boundary cases carried prior authority until flat, `4` remained carried through the annual as-of date, and `981` handed off to next-quarter authority from the quarter start.

Interpretation:

- Annual windows are a better default for alpha-oriented screens than one-quarter OOS slices.
- Annual windows should use `quarter_continuity_replay`, not independent quarter stitching, when the question is live-like yearlong behavior.
- The broader risk-aware context finding is still alive and remains the top aggregate lane under continuity replay.
- The new momentum feature sets did not become the aggregate default.
- Continuation replay remains useful, but continuity lowered exposure and alpha relative to the optimistic independent-stitch packet.
- The benchmark is harsh and appropriate: a bullish high-beta specialist must compete with simply holding the high-beta basket.

## Guardrails

- Do not treat this as accepted allocation evidence.
- Do not change live advice behavior from this result.
- Do not promote the new momentum feature sets as defaults from this screen.
- Treat the annual window shape as research-inspection only. Use continuity replay for annual alpha-oriented interpretation unless an explicit future test changes the authority-duration knob.

## Recommended Next Slice

Use `hb_risk_aware_18 + workhorse_enriched + state_switch_continuation` as the near-term control lane, but use the continuity packet as the valid annual baseline. Audit full trade tapes for why `2022` and `2024` still work better than `2019` and `2020`, then test participation improvements inside this narrower control lane rather than widening the grid immediately.
