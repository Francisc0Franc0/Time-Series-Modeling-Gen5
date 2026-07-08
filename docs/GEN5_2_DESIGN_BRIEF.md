# Gen5.2 Design Brief

Status date: 2026-07-08

Gen5.2 begins where the Gen4-equivalence screens left off. The Gen5.1 stack could match many visible Gen4 settings, but it still did not reproduce the Gen4 artifact behavior closely enough to treat the remaining alpha gap as a research conclusion. The operator decision for Gen5.2 is to absorb the useful Gen4 mechanics into the active Gen5 pipeline instead of keeping them only as a forensic comparison.

This brief is a design and implementation note. It is not an allocation approval, live execution approval, or accepted performance claim.

## Why Gen5.2 Exists

The recent forensic screen showed that matching universe, behavioral-pool PCA, quantile grid, and broad grid breadth was not enough. The remaining differences are mechanical:

- Gen4 Phase40 ranks pooled families with a specific Sharpe-like score, trade-count eligibility rule, and tie-break sequence.
- Gen4 has two abstention concepts: ordinary `no_trade` while flat, and `no_trade_exit_immediate` as a current-state risk-off override for open trades.
- The Gen4 artifact report uses a mean daily return projection by asset/cluster, while the Gen5 research direction should use true live-capital replay for downstream assessment.

Gen5.2 therefore separates **compatibility mechanics** from **assessment mechanics**.

## Canonical Gen5.2 Candidate Eligibility

Both Gen5.2 selection modes now share the same candidate eligibility and winner-score substrate:

1. Use TRAIN evidence only.
2. Keep active candidate rows only when `train_state_trade_count >= 5`; keep no-trade families as valid abstention rows.
3. Score candidates with the Gen4-style winner score: Sharpe-like metric, with missing no-trade score treated as `0` and missing active scores treated as unusable.
4. In the strict pooled-family lane, force sparse or missing asset/state winners to ordinary `no_trade`.

That shared substrate keeps the research comparison clean:

- `asset_state_direct_spec` still chooses the best full asset/state spec directly by score, then return.
- `pooled_family_asset_variant` chooses the state-level family by mean score, then mean return, then number of variants; within that family it chooses each asset's parameter variant by score, then return.
- `pooled_family_asset_variant_state_fallback` is a calibration lane that mimics Gen4's hidden hierarchical fallback: choose the pooled state family, use the asset/state winner when present, and otherwise borrow the pooled state leader's strategy spec rather than forcing no-trade.

The selection-policy factor is therefore about architecture, not a hidden difference in row filters or score handling.

## State Exit Override

Gen5.2 keeps ordinary `no_trade` clean:

- while flat, it means do not enter;
- while already in a trade, it does not automatically exit.

Gen4's `no_trade_exit_immediate` concept is represented in Gen5.2 as an explicit state-level exit override:

- selected rows named `no_trade_exit_immediate`, or rows carrying `state_exit_override_action = "force_exit_next_open"`, trigger a next-open exit while a trade is open;
- the open trade is otherwise still owned by the entry-state strategy until its own exit condition fires.

This preserves the useful Gen4 risk-off behavior without treating the override as a normal entry strategy.

## Entry Replay Semantics

Gen5.2 now names the entry-timing assumption explicitly:

- `fresh_signal_only`: default/current behavior. A flat replay enters only when the selected strategy emits a fresh entry signal while that strategy is routed by the current state.
- `state_switch_continuation`: research-only challenger. For trend-following families with persistent active states (`ema_cross` as `fast_above`, `ema_trend` as `trend_on`), a flat replay may enter when the PCA route switches into an already-active long condition.

The second mode exists because the SOFI audit showed a specific timing gap: Gen4 entered after a `2024-10-03` cross-above signal, while Gen5.2 fallback did not route SOFI to the same `ema_cross_f1_s10` spec until `2024-10-09`. The new mode should remain an explicit A/B research factor until it generalizes; it is not a silent replacement for the default replay rule.

## Assessment Surfaces

Gen5.2 keeps two surfaces separate:

- **Gen4-compatible projection**: mean daily chosen returns by asset/cluster. Use only for forensic parity with Gen4 artifacts.
- **Canonical live-capital replay**: shared-account, dynamic marked-equity equal-slot sizing. This is the preferred downstream research/accounting surface for Gen5.2 inspection.

The intended live-capital sizing model is:

`entry_notional = current_account_equity * leverage / live_basket_slot_count`

Current implemented portfolio POC support is the no-margin `leverage = 1` form, cash-capped. Adding leverage remains a separate explicit gate.

## Current Implementation Status

Implemented in this slice:

- `asset_state_direct_spec` and `pooled_family_asset_variant` now share Gen5.2 candidate eligibility and winner-score handling.
- `pooled_family_asset_variant` calls the Gen4-faithful family-first recipe after that shared candidate filter.
- `pooled_family_asset_variant_state_fallback` has been added as an explicit Gen4-calibration lane, leaving the strict pooled-family lane unchanged for A/B testing.
- Gen4 no-trade exit-immediate compatibility is represented by explicit state exit override helpers.
- PCA-routed replay and live-advice replay can honor a current-state `force_exit_next_open` override while preserving entry-state ownership otherwise.
- Focused tests cover direct-lane and pooled-family active-candidate trade-count filtering, selection-policy recipe labeling, and no-trade exit-immediate override detection.
- A 2024Q4 SOFI/PLTR authority-level probe found that the fallback lane changes `24 / 32` focus asset/state rows and fires on `3` OOS-visited rows where strict pooled-family had abstained.
- A full 2024Q4 16-symbol replay using cached authority then showed that fallback does not close the Gen4 gap: cluster-3 alpha versus local hold was Gen4 `+1.7 pp`, direct `-19.0 pp`, strict pooled `-32.6 pp`, and fallback pooled `-35.5 pp`. Fallback activated SOFI partially, but the trades lost money instead of reproducing Gen4's long SOFI winner.
- A replay-semantics mechanics lab passed all synthetic truth-table checks and a fixed-authority 2024Q4 A/B showed that `state_switch_continuation` improves fallback cluster-3 proxy return from `6.1%` to `20.8%`. It still lags the local hold benchmark (`45.2%`) and does not reproduce the full Gen4 artifact, so it is promising but not sufficient.

Not implemented in this slice:

- SMA family ports.
- Exact Gen4 volatility-expansion breakout semantics.
- A live-capital replay screen using the fallback and continuation lanes; the current fallback/continuation replays are still Phase40-style equivalence surfaces, not canonical portfolio-accounting packets.
- Leveraged live-capital sizing.

## Next Research Gate

The next useful run should compare:

- strict Gen5.2 pooled-family selection;
- Gen4-style pooled-family state-leader fallback selection as a calibration lane;
- direct full-spec selection as a challenger;
- true live-capital portfolio replay;
- a narrow, already-promising context/state setup, likely behavioral-pool PCA plus 3x3 quantile states.

The point of that run is not to crown an allocation. The current Phase40-style replay shows that hierarchical fallback and state-switch continuation both explain part of the Gen4/Gen5.2 gap, but neither is sufficient by itself. The next useful probe should broaden replay-semantics checks across cached non-SOFI baskets/windows and inspect exact remaining Gen4 signal semantics where continuation still diverges.
