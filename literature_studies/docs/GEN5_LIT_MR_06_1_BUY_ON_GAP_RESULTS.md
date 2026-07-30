# LIT-MR-06.1 Causal Buy-on-Gap Results

Status: `STOP_LIT_MR_06_1_ATLAS_NO_FULL_PASS`

## Question answered

Can Chan's Example 4.1 buy-on-gap rule be translated into a causal, retail-
executable research POC and earn a later out-of-sample replay in one of ten
predeclared broad or sector panels?

## Causal implementation

The source-style official-open fill is retained only as
`NONCAUSAL_REFERENCE`. The primary strategy waits until the 09:30-09:31
minute is complete, ranks candidates at 09:31, enters at the adjusted 09:32
minute-bar open, and uses the adjusted daily close as a closing-print proxy.
It preserves the source's lagged 90-session volatility threshold, lagged
20-session moving-average filter, top-ten rank, fixed ten cash sleeves, and
same-day exit.

The causal lane charges 10 bp round trip, with a 20 bp stress view. The ten
static-survivor panels and all eight TRAIN gates were frozen before outcomes.

## TRAIN readout

The authoritative packet is:

`runs/research_workbench/literature_grounded/lit_mr_06_1_buy_on_gap_20260730_v2`

The preliminary packet is not authoritative because the current ticker
`META` returned no 2019-2020 history. The corrected packet maps the same
issuer to provider ticker `FB` through June 8, 2022 and `META` afterward.
This changed data identity plumbing only; no panel, rule, threshold, cost,
gate, or outcome-based choice changed.

All 145 frozen research identities passed the daily-coverage requirement.
Nine panels passed selected-entry coverage; industrials reached 91.7% versus
the frozen 95% minimum.

No panel passed all eight TRAIN gates:

| Panel | Gates | Stock-events / days | Primary cumulative | Stress cumulative | Main reason for STOP |
|---|---:|---:|---:|---:|---|
| Broad large-cap control | 2 / 8 | 19 / 12 | -1.21% | -1.39% | Sparse support and negative economics |
| Consumer staples | 6 / 8 | 13 / 12 | +1.13% | +1.00% | Support and uncertainty |
| Consumer discretionary | 6 / 8 | 17 / 14 | +0.45% | +0.27% | Support and uncertainty |
| Full atlas | 0 / 10 passes | 5-19 / 5-14 | mixed | mixed | Every panel missed support |

The canonical broad panel had a 42.1% stock-event hit rate and up/down
accuracy, -1.64% maximum drawdown, and negative same-open, primary, and stress
curves. Consumer staples and discretionary were economically better
observations, but their one-sided 90% lower bounds remained below zero
(-0.07 and -2.34 bp per portfolio day). They are not nominees.

## Interpretation

The useful result is the executable translation, not an alpha claim. The
exercise makes four ideas concrete:

1. A signal that uses the official open cannot also assume a fill at that
   already-observed price.
2. Sparse signals must leave unused sleeves in cash; rescaling the few
   qualifying stocks to full investment would change the strategy.
3. Positive point estimates are insufficient when event support is tiny and
   uncertainty still crosses zero.
4. Up/down accuracy is directly informative here because the hypothesis says
   a deep negative gap should rebound after entry. The canonical 42.1% result
   shows that the gap often continued downward instead.

Static current survivors, adjusted minute-bar opens, and a daily closing
print remain pedagogical approximations. This packet is not a historical
S&P 500 reconstruction or a live execution study.

## Decision

Record `STOP_LIT_MR_06_1_ATLAS_NO_FULL_PASS`.

- Do not query 2021-2023 DEVELOPMENT outcomes.
- Keep 2024+ confirmation sealed.
- Do not select the two 6/8 panels, loosen support or uncertainty gates, change
  the entry minute, or alter the gap/MA mechanics after seeing TRAIN.
- Do not open the short mirror, a swing variant, point-in-time index rebuild,
  another provider, or live behavior from this result.

## Main artifacts

- [Frozen contract](GEN5_LIT_MR_06_1_CAUSAL_BUY_ON_GAP_POC_CONTRACT.md)
- [Evidence deck](../presentations/gen5_lit_mr_06_1_buy_on_gap_evidence.pptx)
- `lit_mr_06_1_train_report.md`
- `atlas_summary.csv`
- `atlas_gates.csv`
- `selected_event_tape.csv`
- `portfolio_day_tape.csv`
- `visuals/`
