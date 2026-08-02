# LIT-MOM-01.2 Single-Position Retrospective Results

Status: `RETROSPECTIVE_EXPLORATION_COMPLETE_LIT_MOM_01_2`;
`RETROSPECTIVE_EXPLORATION_COMPLETE_LIT_MOM_01_2_STOCK_ATLAS_01`

## Question

What happens if the `LIT-MOM-01.1` signal and TRAIN-only horizon selector are
preserved, but Chan's daily rolling `1/H` sleeves are replaced by one fully
invested, fixed-quantity position held for exactly `H` open-to-open intervals?

## Evidence boundary

The replay uses the already inspected 2021-2023 SHY window. It is therefore a
retrospective execution experiment, not fresh OOS confirmation. It does not
revise the `LIT-MOM-01.1` recommendation to stop before sealed 2024+
CONFIRMATION.

## Frozen mechanics

- The 49-cell `L/H` grid remained open on TRAIN.
- `CHAN_MIN_STEP=min(L,H)` remained the primary selection view.
- `STEP_L=L` was reported as a distinct-formation diagnostic across every
  phase offset.
- `STRICT_L_PLUS_H=L+H` remained the strongest, sparsest sensitivity.
- The selected signal entered at the next open, used all current equity after
  reserving entry cost, froze quantity, held exactly `H` open-to-open
  intervals, and then exited.
- A new signal could enter at the same open as the prior exit.
- Each next trade compounded from current equity.
- Gross, 5 bp-per-side primary, and 10 bp-per-side plus short-borrow stress
  regimes were preserved.

## Selected horizon

TRAIN again selected `L=60`, `H=5`.

| TRAIN inference view | Pairs | Correlation | Sign consistency |
|---|---:|---:|---:|
| `CHAN_MIN_STEP` | 201 | 0.2084 | 60.2% |
| `STEP_L` | 17 | 0.2449 | 58.8% |
| `STRICT_L_PLUS_H` | 16 | 0.1995 | 68.8% |

The two sparse diagnostics remained positive in TRAIN, but their small sample
sizes are support context, not independent confirmation.

## Retrospective 2021-2023 result

The replay completed 149 non-overlapping block trades across 745 open-to-open
intervals.

| Cost regime | Cumulative return | Naive Sharpe | Maximum drawdown |
|---|---:|---:|---:|
| Gross | +2.60% | 0.42 | -3.99% |
| Primary | -11.61% | -1.95 | -12.94% |
| Stress | -25.15% | -4.39 | -25.70% |

Primary-cost calendar returns were negative in 2021, 2022, and 2023. The
literal primary round trips accumulated approximately 13.98% of starting
equity in transaction costs over the replay.

## Direction audit

The sequential trade replay separated sign prediction from implementable
returns:

| Direction | Trades | Direction accuracy | Mean primary trade return |
|---|---:|---:|---:|
| Long | 62 | 56.5% | -0.084% |
| Short | 87 | 50.6% | -0.081% |

The long side predicted direction more often than chance, but neither side
earned a positive mean return after ordinary costs. This is a concrete example
of why hit rate is not a substitute for P&L.

## Comparison nuance

`LIT-MOM-01.2` is not a pure leverage comparison with `01.1`:

- `01.2` holds one full position and applies the frozen one-way cost to every
  literal entry and exit, including same-direction exit/re-entry boundaries.
- `01.1` forms rolling sleeves but charges changes in aggregate net exposure;
  unchanged same-direction replacement exposure can therefore roll without a
  fresh round trip.

The comparison demonstrates the joint effect of concentrated block execution
and the literal turnover convention. It should not be described as proof that
full allocation alone caused the net-return gap.

## Decision

Record `RETROSPECTIVE_EXPLORATION_COMPLETE_LIT_MOM_01_2`.

The lane is a successful textbook-style implementation exercise and a useful
negative result about execution economics. It is not cost-robust strategy
evidence. Do not query sealed 2024+ data, net same-direction re-entry, change
the horizon grid, or revise the parent STOP without a separate operator gate.

## Stock Atlas 01: the substantive breadth experiment

The SHY `60/5` replay above is the minimal worked example, not the endpoint of
`01.2`. The substantive experiment reused the already frozen, outcome-blind
`LIT-MOM-01.1 / STOCK_ATLAS_01` panel: 22 large, liquid stocks, exactly two
from each of eleven broad sectors. Every stock independently evaluated all 49
TRAIN `L/H` cells, selected its own maximum TRAIN correlation t-statistic
subject to the frozen support and tie-break rules, and then replayed only that
frozen rule in the already inspected 2021-2023 window.

This produced 1,078 TRAIN horizon evaluations and ten distinct selected
`L/H` combinations. The most common selections were `25/25` for five stocks,
`10/10` for four, and `5/5` for four. Thus the atlas did not impose or inherit
SHY's `60/5` rule.

| Atlas breadth readout | Result |
|---|---:|
| Assets replayed | 22 |
| Positive gross / primary / stress paths | 5 / 5 / 3 |
| Median primary return | -29.31% |
| Mean primary return | -26.09% |
| Worst primary maximum drawdown | -80.77% |
| Positive selected-row TRAIN correlation | 16 / 22 |
| Positive retrospective correlation | 4 / 22 |
| Above-50% TRAIN sign consistency | 18 / 22 |
| Above-50% retrospective sign consistency | 8 / 22 |

Five individual paths were positive after primary costs, but they are
descriptive outcomes, not nominees: `SHW`, `HD`, `CMCSA`, `JPM`, and `MCD`.
Selecting any of them after seeing this window would convert the exercise into
outcome mining. The broad result is instead that per-asset TRAIN horizon
selection plus full-capital block execution transferred poorly as a general
process in this known window.

Record
`RETROSPECTIVE_EXPLORATION_COMPLETE_LIT_MOM_01_2_STOCK_ATLAS_01`. Do not form
a portfolio, rank or promote retrospective winners, remove weak assets or
short trades, or query sealed 2024+ data.

## Artifacts

- Contract:
  `literature_studies/docs/GEN5_LIT_MOM_01_2_SINGLE_POSITION_RETROSPECTIVE_CONTRACT.md`
- Evidence packet:
  `runs/research_workbench/literature_grounded/lit_mom_01_2_single_position_retrospective_20260802`
- Stock-atlas contract:
  `literature_studies/docs/GEN5_LIT_MOM_01_2_STOCK_ATLAS_01_RETROSPECTIVE_CONTRACT.md`
- Stock-atlas packet:
  `runs/research_workbench/literature_grounded/lit_mom_01_2_stock_atlas_01_retrospective_20260802`
- Deck:
  `literature_studies/presentations/gen5_lit_mom_01_2_single_position_retrospective_evidence.pptx`
