# HYP-MOM-05.2 Triple-SMA Grid Walk-Forward Contract

Status: `FROZEN_DEVELOPMENT_WFA`

Evidence stage: `REUSED_WINDOW_WALK_FORWARD_DEVELOPMENT`

## Question

Within a compact, economically justified family of ordered triple-SMA
pullback/reclaim strategies, can a training-only selection policy identify one
global parameter triplet whose behavior transports to the next unseen
half-year and improves on simple trend baselines?

This is not a search for the best full-sample backtest. The object being tested
is the complete selection procedure: grid, score, tolerance rule, tie-break,
refit frequency, and causal execution policy.

## Frozen strategy family

The HYP-MOM-05.1 mechanics remain unchanged for any candidate `(F, M, S)`:

`ORDERED(t) = SMA_F(t) > SMA_M(t) > SMA_S(t)`

- Begin each evaluation block in cash.
- Enter next open after a fresh in-block transition into `ORDERED`, provided
  the completed close is above `SMA_M`.
- Exit next open after the completed close is at or below `SMA_M`.
- After a completed exit, re-enter next open only after a fresh reclaim of
  `SMA_M` while `ORDERED` remains true.
- Losing ordered status alone does not exit.
- Liquidate at the final open of every half-year block.

Signals use adjusted completed daily closes; fills use the next adjusted open.
No warm start, same-close fill, short exposure, or carry across a refit boundary
is allowed.

## Frozen grid

- Fast SMA: `10, 15, 20` sessions.
- Medium SMA: `30, 40, 50` sessions.
- Slow SMA: `60, 90, 120` sessions.
- Require `fast < medium < slow`.

All 27 resulting triplets are admissible. No candidate may be added, removed,
or refined after outcomes. Longer slow averages deliberately test whether the
original 15/30/45 triplet measured three overly similar views of price.

## Evidence boundary and folds

- Development window: `2021-01-04` through `2023-12-29`.
- Confirmation lock: `2024-01-02+`; it remains unqueried.
- Explicit as-of timestamp: `2026-08-07 17:30:00 America/New_York`.
- Frozen 122-stock registry; failed histories remain failed without replacement.
- At least 130 prior sessions are required for the slowest average.

Six non-overlapping half-year blocks are authoritative:

| Block | Sessions |
|---|---|
| `2021H1` | 2021-01-04 through 2021-06-30 |
| `2021H2` | 2021-07-01 through 2021-12-31 |
| `2022H1` | 2022-01-03 through 2022-06-30 |
| `2022H2` | 2022-07-01 through 2022-12-30 |
| `2023H1` | 2023-01-03 through 2023-06-30 |
| `2023H2` | 2023-07-03 through 2023-12-29 |

The four expanding outer folds train on all prior blocks and test only the next
block: train through `2021H2` / test `2022H1`, then test `2022H2`, `2023H1`,
and `2023H2` in turn. The selected triplet is global: it cannot vary by asset,
sector, cohort, leverage, or outcome.

The window was already inspected in earlier operator-lab work. “Out of sample”
below means causally held out from each fold's selector, not pristine external
confirmation.

## Frozen training score

For every candidate and training block, aggregate the 1x primary-cost asset
panel into five quantities:

1. median net total return;
2. fraction of assets with positive return;
3. median daily Sharpe;
4. median maximum drawdown, where less negative is better; and
5. median excess return versus the stronger, asset-by-asset result from the
   candidate's `SMA_M_ONLY` and `ORDERED_STACK_ONLY` baselines.

Within each block, convert each quantity to a fractional rank across the 27
candidates and average the five ranks. A candidate's training score is its mean
block composite. Estimate its standard error across training-block composites.

Let `B` be the highest mean score. The tolerance set contains every candidate
with mean score at least `B - SE(B)`. Select the candidate with the lowest
median round-trip count inside that set. Remaining ties prefer, in order, the
larger slow, medium, and fast horizons, then lexical candidate ID. This is the
frozen simplicity/turnover rule; it is not revised after seeing test outcomes.

## Accounting and controls

Selection uses 1x with 5 bp one-way costs. The selected test schedules are also
replayed at fixed-quantity 1.8x, but leverage cannot affect selection.

| View | One-way cost | Annual borrowing rate |
|---|---:|---:|
| Gross diagnostic | 0 bp | 0% |
| Primary | 5 bp | 6% |
| Stress | 10 bp | 10% |

At 1.8x, each entry borrows 0.8 times then-current equity and holds fixed
shares until exit. Debt compounds once per open interval. Report the 30%
maintenance-equity proxy without inventing a broker liquidation policy.

For each selected fold, compare cash, buy-and-hold, candidate-specific
`SMA_M_ONLY`, and candidate-specific `ORDERED_STACK_ONLY` under identical
costs, leverage, and boundaries. Also run 500 deterministic exposure-matched
circular shifts within each fold and compound like-numbered simulations across
the four test blocks.

## Frozen development gates

The lane may only nominate a later confirmation discussion if all gates pass:

1. all integrity and leakage checks pass;
2. median compounded 1x test return is positive;
3. more than half of eligible assets have positive compounded test return;
4. at least three of four test blocks have positive median asset return;
5. median compounded excess return is positive versus buy-and-hold,
   `SMA_M_ONLY`, and `ORDERED_STACK_ONLY`;
6. median circular-shift percentile exceeds 0.50 and at least 20% of assets
   exceed the 0.80 percentile; and
7. every fold's one-standard-error tolerance set contains at least three
   candidates, avoiding an isolated single-cell optimum.

Passing does not open confirmation automatically. Failure preserves the 2024+
lock and records which part of the selection policy failed.

## Required readout

Report the full parameter surface, one-standard-error sets, selected triplets,
fold transport, selection turnover, adjacent-cell support, asset/sector/cohort
breadth, trade and bar metrics, baseline differences, costs, leverage risks,
matched timing controls, and representative selected-policy tapes.

No grid expansion, reclaim delay, slope or volatility filter, alternative
average, asset selection, portfolio construction, confirmation access, or live
behavior is authorized under this identifier.
