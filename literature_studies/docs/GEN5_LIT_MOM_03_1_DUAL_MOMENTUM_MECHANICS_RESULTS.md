# LIT-MOM-03.1 Dual-Momentum Mechanics Results

## Question

Can the source-described nine-ETF dual-momentum rule be translated into a
deterministic, auditable weekly signal and allocation tape before any outcome
test is opened?

## Frozen rule

- Universe: `SHY, IEF, UUP, GLD, USO, SPY, EFA, QQQ, EEM`.
- Inputs: Alpaca adjusted daily bars; ranking uses adjusted Wednesday close.
- Sleeves: 10-week and 25-week simple rate of change.
- Selection: top three per sleeve, with exact ties broken by symbol ascending.
- Absolute permission: only positive-ROC top-three assets receive their slot;
  each failed slot remains cash.
- Allocation: 50% per sleeve and one-sixth per slot. An ETF selected by both
  sleeves receives one-third.
- Holiday rule: use the last complete common session on or before Wednesday,
  but only inside that week's Monday-Wednesday window.
- Execution translation: designate the resulting target weights for the next
  complete common-session open.

## Data admission and coverage STOP

The first request used the publisher-aligned history beginning 2007-02-21.
The local cache began in 2016, so the packet stopped on `partial_history` and
`refresh_needed` warnings. A live Alpaca refresh was then attempted. It made
all nine symbols current through 2026-03-25, but the account still returned no
pre-2016 history.

The mechanics packet therefore uses the clean common window from 2016-01-04
through the source cutoff of 2026-03-25, with the first eligible 25-week
decision on 2016-06-29. The publisher's 2008-2015 segment is explicitly not
reproduced. This is a provider-coverage STOP, not silently shortened evidence.

## Mechanics readout

- Status:
  `MECHANICS_REPRODUCTION_PASS_LOCAL_WINDOW_PUBLISHED_WINDOW_BLOCKED`.
- Data health: `PASS` on the admitted 2016-2026 window.
- Weekly decisions: 508, from 2016-06-29 through 2026-03-18.
- Mechanics integrity: 11/11 checks passed.
- Fully invested weeks: 463/508.
- Mean cash weight: 2.56%; observed range: 0% to 66.67%.
- Weeks with at least one ETF shared by the two sleeves: 488/508.
- Latest completed decision in the tape, 2026-03-18:
  - 10-week sleeve: `UUP, GLD, USO`;
  - 25-week sleeve: `GLD, USO, EEM`;
  - cash: 0%.

The descriptive shape is useful even without returns: the absolute-momentum
component behaves mainly as an occasional slot-level brake, while the two
horizons usually concentrate on at least one common winner. Neither fact says
whether the construction added economic value.

## Evidence boundary

No outcome return, P&L, equity curve, Sharpe ratio, drawdown, turnover cost,
baseline comparison, parameter search, strategy gate, or edge claim was
computed. The allocation timeline is a target-weight tape, not a wealth curve.

## Artifacts

- Packet:
  `runs/research_workbench/literature_grounded/lit_mom_03_1_dual_momentum_mechanics_20260902/`
- Human-facing review:
  `literature_studies/presentations/gen5_lit_mom_03_1_dual_momentum_study.pptx`
- Mechanics module:
  `literature_studies/R/gen5_lit_mom_03_1_dual_momentum_mechanics.R`
- Runner:
  `literature_studies/scripts/run_gen5_lit_mom_03_1_dual_momentum_mechanics.R`
- Focused tests:
  `literature_studies/tests/testthat/test_gen5_lit_mom_03_1_dual_momentum_mechanics.R`

## Next gate

If the operator opens performance evaluation, the next narrow slice is a
causal 2016-2026 replay with next-open execution, modest costs, and frozen
comparators: cash/no trade, equal-weight all nine, relative-only,
absolute-only, and an attainable long-only ownership baseline. That local
replay cannot cure the missing 2008-2015 source span; it answers a narrower
Gen5 question.
