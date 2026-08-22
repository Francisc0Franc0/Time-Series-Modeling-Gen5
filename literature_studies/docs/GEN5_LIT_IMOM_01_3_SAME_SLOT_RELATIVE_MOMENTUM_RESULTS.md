# LIT-IMOM-01.3 Same-Slot Relative Momentum Results

Status: `STOP_LIT_IMOM_01_3_NO_CLOCK_SPECIFIC_RELATIVE_MOMENTUM`

## Decision

Stop this same-time-of-day relative-momentum hypothesis at DEVELOPMENT. The
matching prior-session slot did not improve next-session SPY-relative return
forecasts beyond clock seasonality or prior full-session relative momentum.
It also underperformed the best of all twelve deliberately displaced source
slots after the placebo maximum was recomputed inside every bootstrap draw.

Do not select the two superficially favorable target slots, the strongest
wrong-clock offset, or any isolated asset row. Preserve 2024+ confirmation.

## Frozen narrative and estimand

The narrative was that multi-session institutional orders may recur against
similar liquidity or benchmark schedules. If stock-specific pressure appeared
in one regular-session 30-minute slot, it might recur in the same slot on the
next trading session.

For stock `i`, session `d`, and slot `s`, the frozen return was the stock's
open-to-close log return minus SPY's simultaneous open-to-close log return.
The completed preceding session supplied both:

- its full-session SPY-relative return; and
- its slot-specific SPY-relative return.

All targets and predictors were normalized with TRAIN-only moments. One common
same-slot coefficient pooled all thirteen target slots; no slot or lag was
searched.

## Data and analytical validity

- Frozen registry checksum:
  `ED6A9C87E00E53970528F9638BFB972323D47AF86B273C19A13DC89DE9D7B4AF`.
- All 26 instruments passed mechanical common-calendar checks.
- SPY was benchmark-only; 25 non-SPY instruments were fitted.
- The candidate family contained 22 nonremembered stocks. AMD, TSLA, and QQQ
  were diagnostic-only.
- The panel admitted 731 TRAIN and 735 DEVELOPMENT target sessions.
- Every fitted asset supplied 9,503 TRAIN and 9,555 DEVELOPMENT slot
  observations.
- Every authority used identical complete 13-slot predictor/target sessions.
- Early closes and the ten frozen archive exclusions were neither imputed nor
  bridged.
- Maximum included session was `2023-12-29`; 2024+ was not loaded.

## Forecast authorities

| ID | Information available before the target session |
|---|---|
| `M0_CLOCK` | TRAIN-fitted target-slot effects |
| `M1_DAY` | clock effects plus the preceding full-session relative return |
| `M2_SAME` | `M1_DAY` plus the preceding session's matching-slot relative return |

Twelve additional models replaced the matching slot with circular offsets
`1,...,12`. Those wrong-clock models were negative controls, not alternative
candidates.

Across all 25 fitted assets, the lowest-loss primary authority was `M0_CLOCK`
for 16, `M1_DAY` for four, and `M2_SAME` for five. Within the 22-stock
candidate family, the counts were 14, three, and five.

Median standardized losses across all 25 fitted assets were:

| Authority | Median DEVELOPMENT loss |
|---|---:|
| `M0_CLOCK` | 0.808003 |
| `M1_DAY` | 0.807154 |
| `M2_SAME` | 0.807361 |

The small ordering of cross-asset medians is not the authority comparison.
The predeclared equal-weight session-level loss contrasts determine the panel
result.

## Equal-weight 22-stock panel

Positive values favor the more elaborate model.

| Contrast | Interpretation | Mean | 90% interval | One-sided p |
|---|---|---:|---:|---:|
| `G10` | prior day over clock | -0.000214 | [-0.000321, -0.000103] | 0.999600 |
| `S21` | same slot over prior day | -0.000360 | [-0.000505, -0.000206] | 0.999900 |
| `S20` | same slot over clock | -0.000574 | [-0.000782, -0.000358] | 1.000000 |
| `U` | same slot over best wrong clock | -0.000163 | [-0.000309, -0.000037] | 0.969503 |

All four intervals were strictly negative. Prior full-session relative
momentum worsened the clock baseline, the matching slot worsened it again,
and the matching slot was worse than the strongest displaced-slot control.

The best panel wrong-clock alignment was circular offset 7. It still worsened
`M1_DAY` by `-0.000197`, but the same-slot model worsened it more, by
`-0.000360`. The difference is the negative `U` result above. Offset 7 is a
falsification diagnostic and cannot become a new hypothesis.

## Breadth and multiplicity

Among 22 candidate stocks:

- `G10` was positive for 5;
- `S21` was positive for 8;
- `S20` was positive for 6;
- `U` was positive for 4; and
- no asset survived the complete gate.

Thirteen of 22 TRAIN same-slot coefficients were positive, with median
`0.004876`. That weak coefficient tilt did not transport into lower
DEVELOPMENT loss. Descriptively, only target slots 1 and 9 had positive
cross-asset median `S21`; the other eleven slot medians were negative. The
contract prohibits selecting either favorable slot.

## Isolated diagnostics

`PG` was the only candidate with positive 90% lower bounds for both same-slot
loss contrasts:

- `S21=0.000203`, interval `[0.000033, 0.000381]`, raw p `0.032697`, BH q
  `0.719328`; and
- `S20=0.000205`, interval `[0.000034, 0.000385]`, raw p `0.030097`, BH q
  `0.662134`.

It failed both required protections. Its clock-specificity result was only
`U=0.000084`, interval `[-0.000785, 0.000233]`, with BH q `0.999800`, and its
best wrong-clock model used offset 5. PG is therefore not evidence for the
recurring-clock narrative.

`SHW` alone had a positive 90% lower bound for the general-day control:
`G10=0.000243`, interval `[0.000035, 0.000460]`, raw p `0.033897`, and BH q
`0.745725`. Its same-slot and clock-specificity contrasts were negative.

AMD, TSLA, and QQQ all had negative `U` and negative TRAIN same-slot
coefficients. They remain diagnostic-only.

## Interpretation

The higher-resolution clock did not reveal a hidden recurring execution
signature in these bar returns. The result is not merely a failure to clear a
multiplicity threshold: at the panel level, every predeclared incremental
contrast was negative with a strictly negative 90% interval.

This does not show that institutions never split orders or that intraday
order-flow persistence cannot exist. It shows that prior-session 30-minute
stock-minus-SPY open-to-close returns are not a useful proxy for that mechanism
at the next session's corresponding slot on this liquid panel. Aggregated bars
may be too coarse, the schedule may not persist exactly one session, or the
relevant state may live in signed volume, imbalance, auction, or order-book
data rather than return alone. Those are new hypotheses, not permitted rescues
of this stopped test.

## Evidence packet

- Packet:
  `runs/research_workbench/literature_grounded/lit_imom_01_3_same_slot_relative_momentum_20260821`
- Report: `imom013_report.md`
- Health and calendar: `imom013_data_health.csv`,
  `imom013_coverage_and_eligibility.csv`, and
  `imom013_session_calendar.csv`
- Forecast evidence: `imom013_model_metrics.csv`,
  `imom013_asset_contrasts.csv`, and `imom013_panel_contrasts.csv`
- Wrong-clock evidence: `imom013_wrong_clock_surface.csv`
- Decisions: `imom013_asset_decisions.csv`
- Visual evidence: `visuals/`

No thresholds, positions, hedges, trades, costs, turnover, P&L, Sharpe,
drawdown, allocation, leverage, advice, execution, or live behavior were
computed. The 2024+ period remains unread.
