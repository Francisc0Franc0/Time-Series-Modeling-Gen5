# LIT-MOM-01.2 Stock Atlas 01 Retrospective Contract

Status: `FROZEN_RETROSPECTIVE_EXPLORATION`

## Purpose

The SHY `60/5` replay is the minimal mechanics demonstration for
`LIT-MOM-01.2`. The substantive breadth question is whether the same
single-position execution process behaves similarly when each asset receives
its own full 49-cell TRAIN horizon search and only its frozen selected rule is
replayed afterward.

This atlas is retrospective learning on an already inspected 2021-2023
window. It is not fresh OOS confirmation and cannot revise any prior STOP.

## Frozen universe

Reuse the existing outcome-blind `LIT-MOM-01.1 / STOCK_ATLAS_01` registry:

`literature_studies/registries/gen5_lit_mom_01_1_stock_atlas_01_registry.csv`

It contains 22 large, liquid U.S. stocks: exactly two from each of eleven
broad sectors. The panel was selected for sector breadth, economic diversity,
liquidity, history, and practical symbol continuity before `01.2` outcomes
were observed.

This remains a static July 2026 survivor panel and is not an investable
point-in-time historical universe.

## Per-asset selection

Every stock is processed independently:

1. Use adjusted daily bars from January 4, 2016 through December 29, 2023.
2. Use TRAIN from January 3, 2017 through December 31, 2020.
3. Evaluate every `L,H in {1,5,10,25,60,120,250}` combination.
4. Require selected `H >= 5` and at least 20 `CHAN_MIN_STEP=min(L,H)` pairs.
5. Select the maximum TRAIN Pearson correlation t-statistic, with the frozen
   shorter-holding then shorter-lookback tie breaks.
6. Freeze that stock's selected `L/H` before reading its 2021-2023 replay.
7. Report `CHAN_MIN_STEP`, all-phase `STEP_L`, and strict `L+H` diagnostics for
   the selected row.

Unlike the gate-admission `01.1` atlas, every stock receives its retrospective
replay. The purpose is to describe the requested selection-and-execution
process across breadth, not to nominate a winner or claim a fresh test.

## Per-asset execution

Reuse the frozen `LIT-MOM-01.2` mechanics:

- signal after close `t`: sign of the selected `L`-session close return;
- enter long at the next open only after a positive signal; otherwise hold cash;
- invest all current equity after reserving entry cost;
- freeze long quantity within the trade;
- hold exactly selected `H` open-to-open intervals;
- no pyramiding and no intra-trade rebalance;
- allow a new trade at the same open as the prior exit using the preceding
  close signal;
- compound the next trade from current equity;
- report gross, 5 bp-per-side primary, and 10 bp-per-side stress regimes.

Cash interest, taxes, and instrument-specific slippage remain unavailable.

## Required evidence

- all 49 TRAIN rows for every stock;
- one selected row per stock;
- selected-row inference diagnostics;
- train and retrospective metrics, trades, direction audit, and yearly paths;
- selected-horizon, return-breadth, continuity, directional, and equity-path
  visuals;
- aggregate counts only as breadth description, never as a portfolio; and
- a deck section that follows the SHY tutorial and preserves the retrospective
  boundary.

## Interpretation boundary

- Do not select the best retrospective stock.
- Do not pool the 22 assets into a portfolio.
- Do not replace per-asset horizons with a post-hoc common horizon.
- Do not remove weak assets or add short trades after inspection.
- Do not query 2024+ CONFIRMATION.
- Do not treat repeated use of the known 2021-2023 window as independent OOS
  evidence.
