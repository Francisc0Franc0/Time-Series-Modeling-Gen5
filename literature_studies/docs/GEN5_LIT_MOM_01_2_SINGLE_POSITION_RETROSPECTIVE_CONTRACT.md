# LIT-MOM-01.2 Single-Position Momentum Retrospective Contract

Status: `FROZEN_RETROSPECTIVE_EXPLORATION`

## Place in the literature-study progression

`LIT-MOM-01.2` is a substantive execution variant of Chan's Chapter 6
interday time-series-momentum proposition. It preserves the `01.1` signal,
horizon grid, causal timing, SHY proxy, costs, and long/short direction, but
replaces rolling `1/H` sleeves with one fully invested, non-pyramiding
position at a time.

This lane exists to answer the operator's simpler swing-trading question. It
does not revise, rescue, or supersede the `LIT-MOM-01.1` result.

## Evidence label and window boundary

- TRAIN horizon screen: January 3, 2017 through December 31, 2020.
- Retrospective replay: January 4, 2021 through December 29, 2023.
- Confirmation: January 2, 2024 onward remains unqueried.
- Evidence label: `RETROSPECTIVE_EXPLORATION`.

The 2021-2023 window was already inspected under `01.1` before this variant
was proposed. It is therefore useful for learning and mechanical comparison,
but it is not fresh OOS confirmation.

## Horizon selection remains open

Evaluate all 49 combinations:

`L,H in {1,5,10,25,60,120,250}`.

Holding periods shorter than five sessions remain excluded from selection.
The primary selector is unchanged from `01.1`:

1. build past/future return pairs using `CHAN_MIN_STEP=min(L,H)`;
2. require at least 20 pairs;
3. rank by the largest Pearson-correlation t-statistic;
4. break exact ties toward shorter `H`, then shorter `L`; and
5. report whether the selected row has positive correlation and nominal
   `p <= 0.10`.

The nominal p-value is a source-style screening statistic across related
cells, not independent proof.

## Three inference views

For the selected horizon, report:

1. `CHAN_MIN_STEP=min(L,H)`: source-faithful primary screen.
2. `STEP_L=L`: distinct-formation diagnostic using a deterministic first
   eligible anchor.
3. `STRICT_L_PLUS_H=L+H`: strongest raw-interval separation and sparsest
   sensitivity.

For `STEP_L`, also report all `L` possible partition offsets separately.
Offsets are not pooled as independent observations. Show the median and range
of pair count, correlation, and sign consistency to make phase sensitivity
visible.

## Signal and causal entry

After close (t):

`s_t = sign(C_t / C_(t-L) - 1)`.

The position enters at the next adjusted open. A positive signal enters long;
a negative signal enters short. A zero or unavailable signal remains flat
until the next eligible close.

## Single-position execution

- Entry size: 100% of current equity after reserving entry transaction cost.
- Position quantity: fixed at entry; no intra-trade rebalancing.
- Holding period: exactly `H` open-to-open intervals.
- Exit: adjusted open `H` sessions after entry.
- Pyramiding: prohibited.
- Overlapping positions: prohibited.
- Re-entry: at an exit open, the strategy may immediately enter the next
  position using the signal known from the preceding close.
- Compounding: the next trade uses all equity remaining after the prior
  trade's P&L, entry/exit costs, and applicable borrow cost.
- Gross leverage: one-times entry notional; no additional leverage.

For current equity (E), one-way cost rate (c), and entry open (P_0):

`entry_notional = E / (1 + c)`

`units = entry_notional / P_0`.

Long and short quantities remain fixed until exit. Effective exposure may
drift away from exactly one as price and equity change; that drift is reported
rather than rebalanced away.

## Costs

- Gross: zero transaction and borrow costs.
- Primary: 5 bp per one-way traded notional.
- Stress: 10 bp per one-way traded notional plus 100 bp annualized borrow on
  the daily market value of a short position.

Cash interest, margin interest, taxes, slippage beyond the stated cost, and
historical borrow availability are unavailable and excluded.

## Required artifacts

- frozen contract and source-packet reference;
- complete 49-cell TRAIN horizon screen;
- selected horizon;
- all three inference views;
- `STEP_L` phase-offset table;
- one row per non-overlapping trade;
- one row per open-to-open portfolio interval;
- gross, primary, and stress performance;
- long/short accuracy and trade-return audit;
- calendar returns;
- representative trade tapes;
- direct `01.1` versus `01.2` comparison; and
- an integrity audit covering timing, overlap, fixed units, compounding,
  costs, and confirmation exclusion.

## Interpretation boundary

No result from this replay may authorize live advice, execution, leverage,
capital allocation, removal of shorts, horizon retuning on 2021-2023, or a
claim of fresh OOS alpha. A later confirmation exercise would require a newly
approved untouched evidence window.
