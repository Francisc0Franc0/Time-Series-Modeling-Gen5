# Gen5.2 Design Brief

Status date: 2026-07-07

Gen5.2 begins where the Gen4-equivalence screens left off. The Gen5.1 stack could match many visible Gen4 settings, but it still did not reproduce the Gen4 artifact behavior closely enough to treat the remaining alpha gap as a research conclusion. The operator decision for Gen5.2 is to absorb the useful Gen4 mechanics into the active Gen5 pipeline instead of keeping them only as a forensic comparison.

This brief is a design and implementation note. It is not an allocation approval, live execution approval, or accepted performance claim.

## Why Gen5.2 Exists

The recent forensic screen showed that matching universe, behavioral-pool PCA, quantile grid, and broad grid breadth was not enough. The remaining differences are mechanical:

- Gen4 Phase40 ranks pooled families with a specific Sharpe-like score, trade-count eligibility rule, and tie-break sequence.
- Gen4 has two abstention concepts: ordinary `no_trade` while flat, and `no_trade_exit_immediate` as a current-state risk-off override for open trades.
- The Gen4 artifact report uses a mean daily return projection by asset/cluster, while the Gen5 research direction should use true live-capital replay for downstream assessment.

Gen5.2 therefore separates **compatibility mechanics** from **assessment mechanics**.

## Canonical Gen5.2 Selection Policy

The public `pooled_family_asset_variant` policy now uses a Gen4 Phase40-style recipe:

1. Use TRAIN evidence only.
2. Keep active candidate rows only when `train_state_trade_count >= 5`; keep no-trade families as valid abstention rows.
3. Score candidates with the Gen4-style winner score: Sharpe-like metric, with missing no-trade score treated as `0` and missing active scores treated as unusable.
4. Choose the state-level family by mean score, then mean return, then number of variants.
5. Within that selected family, choose each asset's parameter variant by score, then return.
6. Force sparse asset/state rows to ordinary `no_trade`.

The direct full-spec policy, `asset_state_direct_spec`, remains available as a research comparator. It is no longer the assumed Gen5 default when the goal is Gen4-faithful lineage.

## State Exit Override

Gen5.2 keeps ordinary `no_trade` clean:

- while flat, it means do not enter;
- while already in a trade, it does not automatically exit.

Gen4's `no_trade_exit_immediate` concept is represented in Gen5.2 as an explicit state-level exit override:

- selected rows named `no_trade_exit_immediate`, or rows carrying `state_exit_override_action = "force_exit_next_open"`, trigger a next-open exit while a trade is open;
- the open trade is otherwise still owned by the entry-state strategy until its own exit condition fires.

This preserves the useful Gen4 risk-off behavior without treating the override as a normal entry strategy.

## Assessment Surfaces

Gen5.2 keeps two surfaces separate:

- **Gen4-compatible projection**: mean daily chosen returns by asset/cluster. Use only for forensic parity with Gen4 artifacts.
- **Canonical live-capital replay**: shared-account, dynamic marked-equity equal-slot sizing. This is the preferred downstream research/accounting surface for Gen5.2 inspection.

The intended live-capital sizing model is:

`entry_notional = current_account_equity * leverage / live_basket_slot_count`

Current implemented portfolio POC support is the no-margin `leverage = 1` form, cash-capped. Adding leverage remains a separate explicit gate.

## Current Implementation Status

Implemented in this slice:

- `pooled_family_asset_variant` now calls the Gen4-faithful scoring recipe.
- Gen4 no-trade exit-immediate compatibility is represented by explicit state exit override helpers.
- PCA-routed replay and live-advice replay can honor a current-state `force_exit_next_open` override while preserving entry-state ownership otherwise.
- Focused tests cover Gen4-style active-candidate trade-count filtering, selection-policy recipe labeling, and no-trade exit-immediate override detection.

Not implemented in this slice:

- SMA family ports.
- Exact Gen4 volatility-expansion breakout semantics.
- A full regenerated Gen5.2 research screen using live-capital replay.
- Leveraged live-capital sizing.

## Next Research Gate

The next useful run should compare:

- Gen4-faithful pooled-family selection;
- direct full-spec selection as a challenger;
- true live-capital portfolio replay;
- a narrow, already-promising context/state setup, likely behavioral-pool PCA plus 3x3 quantile states.

The point of that run is not to crown an allocation. It is to see whether the Gen4-faithful mechanics close the forensic gap and whether live-capital accounting changes the interpretation versus proxy return projections.
