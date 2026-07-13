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
- `reversion_breakout_context` was added later as a targeted diagnostic feature set for reopened non-EMA strategy families. It emphasizes range location, stretch, volatility compression/expansion, choppiness, return impulse, drawdown, recovery, and distance from moving-average anchors.

## Primary Artifacts

- Independent-stitch packet: `runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260710ctxsize/`
- Continuity packet: `runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260711continuity/`
- Continuity report: `runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260711continuity/momentum_context_size_report.md`
- Continuity summary: `runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260711continuity/momentum_context_size_summary.csv`
- Continuity aggregate: `runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260711continuity/momentum_context_size_aggregate.csv`
- Continuity audit: `runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260711continuity/momentum_context_size_continuity.csv`
- EMA feature diagnostic packet: `runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260711stratema/`
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

## Next Narrow Strategy-Reopening Screen

After the continuity rerun, the cleanest next question is not whether annual windows work. They do. The cleaner question is whether the EMA-only momentum-specialist pool was too narrow once the annual continuity surface gives us enough OOS behavior to judge.

Hold fixed:

- Context: `hb_risk_aware_18`.
- Feature control: `workhorse_enriched`.
- Replay: `quarter_continuity_replay` plus `state_switch_continuation`.
- Live basket: `AMD,NVDA,TSLA,MSTR,AVGO`.
- Benchmark: equal-weight buy-and-hold of the exact live basket.
- Annual windows: the same continuity windows unless the operator explicitly expands them.

Vary first:

- `ema_only_momentum`: current control pool, `ema_cross`, `ema_trend`, `no_trade`, and `no_trade_exit_immediate`.
- `trend_breakout`: adds upside participation families such as `breakout`, `vol_expansion_breakout`, `donchian_breakout_vol_expand`, and `pullback_in_uptrend`.
- `mean_reversion_only`: diagnostic pool for `bollinger_touch`, `bollinger_mid_reversion`, `rsi_mr`, and `zret_mr` plus no-trade variants.
- `classical_full`: broad reopened pool with trend, breakout, mean reversion, and no-trade variants.

Feature sets should support that question without exploding the grid:

- Keep `workhorse_enriched` as the control because it won the continuity screen.
- Keep `momentum_plus_stress` as the strongest existing challenger conceptually.
- Add a small `reversion_breakout_context` feature set only if the reopened strategy pools need it; this should emphasize range location, volatility compression/expansion, distance from moving averages, choppiness, drawdown/recovery, and return impulse.

Do not retest every basket yet. If a broader strategy pool improves the fixed `hb_risk_aware_18` control lane, then the follow-up screen can hold the winning strategy pool and feature set fixed while varying context size/composition again.

## EMA Feature Diagnostic Result

Completed packet:

`runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260711stratema/`

Purpose:

Before paying the compute cost for broad reopened strategy pools, this diagnostic kept the already-identified control surface fixed:

- context: `hb_risk_aware_18`;
- annual replay: `quarter_continuity_replay`;
- replay semantics: `state_switch_continuation`;
- strategy pool: `ema_cross`, `ema_trend`, `no_trade`, and `no_trade_exit_immediate`;
- selection policy: `pooled_family_asset_variant`;
- live basket: `AMD,NVDA,TSLA,MSTR,AVGO`;
- benchmark: equal-weight live-basket buy-and-hold.

It then compared:

- `workhorse_enriched`;
- `momentum_plus_stress`;
- `reversion_breakout_context`.

Readout:

- `reversion_breakout_context` averaged `68.1%` total return, `-23.4 pp` alpha versus basket hold, `48.0%` exposure, and beat the basket in `1 / 4` annual windows.
- `workhorse_enriched` averaged `55.9%` total return, `-35.6 pp` alpha, `40.3%` exposure, and beat the basket in `2 / 4` windows.
- `momentum_plus_stress` averaged `33.1%` total return, `-58.5 pp` alpha, `35.0%` exposure, and beat the basket in `1 / 4` windows.

Interpretation:

The new `reversion_breakout_context` surface moved in the desired direction for EMA-only participation: higher mean return, higher exposure, and less negative mean alpha than the workhorse control. It did not become accepted evidence because it still lagged equal-weight basket hold in `3 / 4` annual windows. The most useful read is that feature design matters, but the next question is still state timing and participation quality rather than a default feature promotion.

## Broad Strategy-Pool Compute Gate

The planned `trend_breakout`, `mean_reversion_only`, and `classical_full` reopened-pool screens were started as the next direct test of whether EMA-only was too narrow. The `trend_breakout` run was intentionally stopped after measuring the fitting cost:

- full four-window run began under `g53_momctx_20260711stratbreakout`;
- bounded two-window run began under `g53_momctx_20260711stratbreakout2win`;
- the bounded run took roughly twenty minutes to fit one quarter across the five-symbol live basket before replay/accounting, implying a multi-hour job for even the reduced strategy-pool diagnostic.

Those partial folders are compute-timing evidence only. They are not performance evidence and should not be interpreted as completed research packets.

Recommended compute-safe next run:

1. Run one reopened strategy pool at a time.
2. Start with `trend_breakout` on two annual windows: `2020Y_asof_20201231` and `2022Y_asof_20221231`.
3. Only run `mean_reversion_only` or `classical_full` after the trend/breakout diagnostic either improves participation or fails cleanly.
4. Consider adding resume/checkpoint behavior before launching broad all-window reopened-pool sweeps.

## Trend/Breakout Two-Window Result

Completed packet:

`runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260712stratbreakout2win/`

Purpose:

This was the deliberately scheduled compute slice after the broad-pool timing gate. It kept the annual continuity control lane fixed and reopened only the trend/breakout strategy families:

- context: `hb_risk_aware_18`;
- feature set: `workhorse_enriched`;
- annual replay: `quarter_continuity_replay`;
- replay semantics: `state_switch_continuation`;
- strategy pool: `trend_breakout`;
- candidate families: `ema_cross`, `ema_trend`, `breakout`, `pullback_in_uptrend`, `vol_expansion_breakout`, `donchian_breakout_vol_expand`, `no_trade`, and `no_trade_exit_immediate`;
- windows: `2020Y_asof_20201231` and `2022Y_asof_20221231`.

Apples-to-apples readout versus the EMA-only control:

- `2020`: EMA-only returned `106.0%` with `-121.3 pp` basket alpha and `58.5%` exposure. Trend/breakout returned `53.3%` with `-173.9 pp` basket alpha and `36.8%` exposure.
- `2022`: EMA-only returned `-22.6%` with `+30.4 pp` basket alpha and `16.8%` exposure. Trend/breakout returned `-10.8%` with `+42.2 pp` basket alpha and `19.3%` exposure.

Interpretation:

The trend/breakout pool did not solve the upside participation problem. It made the system more defensive/selective: much worse in the 2020 high-beta rebound, but cleaner in the 2022 drawdown. The selection family heatmap shows a cash-dominant authority map with only selective pullback, Donchian breakout, and EMA-cross cells.

Decision implication:

Do not run the full four-window trend/breakout sweep yet. The next narrower question should be about entry/participation design or state timing, not simply adding more breakout families. If strategy diversity is reopened again, it should be because we have a specific participation hypothesis, not because a broader pool is assumed to be better.

## Mean-Reversion Two-Feature Diagnostic Result

Completed packet:

`runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260712meanrev2feat/`

Purpose:

After the trend/breakout pool became more defensive rather than more participatory, this diagnostic asked whether classic mean-reversion families could add useful range-trading behavior without widening all strategy families at once.

Fixed design:

- context: `hb_risk_aware_18`;
- annual replay: `quarter_continuity_replay`;
- replay semantics: `state_switch_continuation`;
- selection policy: `pooled_family_asset_variant`;
- live basket: `AMD,NVDA,TSLA,MSTR,AVGO`;
- windows: `2020Y_asof_20201231` and `2022Y_asof_20221231`;
- candidate families: `bollinger_touch`, `bollinger_mid_reversion`, `rsi_mr`, `zret_mr`, `no_trade`, and `no_trade_exit_immediate`.

Feature sets compared:

- `workhorse_enriched`;
- `reversion_breakout_context`.

Readout:

- `2020`: workhorse mean reversion returned `20.3%` with `-207.0 pp` basket alpha, `21.3%` exposure, and `26` entries. Reversion-breakout mean reversion returned `13.6%` with `-213.7 pp` basket alpha, `19.8%` exposure, and `30` entries. The basket returned `227.3%`.
- `2022`: workhorse mean reversion returned `-12.9%` with `+40.1 pp` basket alpha, `25.9%` exposure, and `41` entries. Reversion-breakout mean reversion returned `-17.6%` with `+35.4 pp` basket alpha, `27.3%` exposure, and `44` entries. The basket returned `-53.0%`.

Trade-tape interpretation:

The 2020 failure mode is underparticipation and late/episodic participation, not an absence of trades. In the completed trend/breakout tape, TSLA first entered on `2020-09-18`, after much of the early/mid-2020 rally had already occurred. AMD and NVDA caught some legs, but exited or remained underexposed relative to buy-and-hold. The mean-reversion tapes show small countertrend/range attempts and defensive cash selection, not early sticky participation in a broad high-beta rally.

Selection-map interpretation:

The mean-reversion authority map remains cash-dominant. Bollinger-style pockets appear selectively, especially for AVGO, while RSI and z-return variants do not dominate the selected state map.

Decision implication:

Mean reversion is worth keeping as a future broad-system ingredient, especially for range or falling-market behavior, but it is not the missing mechanism for the current bullish high-beta specialist. The next high-impact question is state timing and entry/hold participation directly: when a favorable state appears, does the system enter early enough and stay long enough to matter?
