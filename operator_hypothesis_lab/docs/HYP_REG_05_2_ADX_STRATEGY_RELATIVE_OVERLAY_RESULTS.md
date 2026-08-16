# HYP-REG-05.2 ADX Strategy-Relative Overlay — Results

## Decision

Record
`STOP_ADX_STRATEGY_RELATIVE_GATES_FAILED_CONFIRMATION_NOT_RUN`.

The operator's conceptual correction was valid: a regime label does not need
to predict its own future state in order to be useful. It may instead describe
the causally observed present well enough to change the preferred action until
the next decision. This experiment therefore evaluated ADX by the strategy
payoffs it routed, not by the forward-path target that stopped `HYP-REG-05.1`.

The result does not support either frozen hard-gating policy. HIGH ADX selected
a more favorable subset of parent entries and its actual timing beat most
exposure-near circular controls, but the gate discarded too many profitable
parent trades to improve the complete policy. Exiting when ADX left HIGH was
still weaker.

## What was tested

The frozen development panel reused 24 stocks, with SPY and QQQ reference-only,
from 2018-01-02 through 2023-12-29. The 2024+ confirmation interval remained
sealed. The runner causally joined the accepted `HYP-REG-05.1` ADX(14) state
to the unchanged `HYP-MOM-06.1` daily SMA8/SMA14 long/cash strategy:

- ADX was expressed as a prior-252-session asset-relative percentile with the
  already accepted 30/40/60/70 hysteresis state machine;
- the state observed after close `t` could affect execution only at open
  `t+1`;
- `ENTRY_HIGH_ONLY` admitted a fresh SMA cross-up only in `HIGH`, then retained
  the parent cross-down exit;
- `REACTIVE_HIGH_ONLY` used the same admission rule and also exited next open
  when ADX left `HIGH`, with no re-entry until a fresh parent cross-up;
- every asset-year began in cash, used 1x leverage and 5 bp per side, and
  compounded profits and losses within the year.

The unfiltered parent was reproduced in all 156 registered asset-year cells
with maximum absolute return difference `4.44e-15`. The primary decision
panel contains 144 stock-year cells. Two hundred deterministic within-asset,
within-year circular ADX-state rotations were run for each overlay; the
decision comparison used the 40 controls nearest the actual median exposure.

## Policy readout

| Policy | Median annual return | Median maximum drawdown | Median Sharpe | Median exposure | Trades |
|---|---:|---:|---:|---:|---:|
| Unfiltered SMA8/SMA14 | 8.95% | -14.59% | 0.642 | 53.88% | 1,394 |
| Entry HIGH only | 1.95% | -6.56% | 0.378 | 12.40% | 347 |
| Reactive HIGH only | 0.06% | -4.62% | 0.166 | 6.40% | 347 |
| Buy and hold | 14.60% | -20.94% | 0.704 | 100.00% | 144 |

The overlays did what a restrictive gate mechanically tends to do: they cut
exposure and drawdown. That is not enough. `ENTRY_HIGH_ONLY` surrendered about
seven median annual return points and `0.263` Sharpe; only 8 of 24 stocks
improved over six years and median excess was positive only in 2018.
`REACTIVE_HIGH_ONLY` surrendered about 8.89 return points and `0.475` Sharpe;
only 7 of 24 stocks improved and only 2018 was favorable.

The risk result is therefore a tradeoff, not a free improvement. Both overlays
had smaller drawdowns, but neither satisfied the frozen joint requirement that
drawdown be no worse **and** Sharpe be no lower.

## What the state did know

The parent-entry audit supports the narrower descriptive intuition:

| Signal-close ADX state | Parent trades | Hit rate | Mean trade | Median trade | Median hold |
|---|---:|---:|---:|---:|---:|
| LOW | 672 | 44.05% | 0.64% | -0.57% | 10 sessions |
| MEDIUM | 375 | 47.47% | 1.66% | -0.27% | 11 sessions |
| HIGH | 347 | 48.70% | 2.01% | -0.08% | 10 sessions |

HIGH ADX entries were better on these descriptive trade-level measures. The
actual `ENTRY_HIGH_ONLY` panel return also ranked at the 85th percentile of
the 40 exposure-nearest rotated controls and exceeded their median by 1.20
percentage points. This passed the predeclared state-specificity gate.

That distinction matters: ADX carried some timing information relative to
equally restrictive mistimed gates. It simply did not carry enough information
to compensate for excluding 1,047 parent trades. A useful conditional feature
need not be a useful binary permission rule.

## Why the reactive version was weaker

ADX leaving HIGH caused 154 of the 347 reactive exits. Their median change
versus the corresponding parent trades was approximately `+0.03 pp`, but the
mean change was `-0.96 pp`. A few protective exits existed, yet the left tail
of false exits dominated on average. The reactive policy's actual timing ranked
at only the 15th percentile of exposure-near circular controls and trailed
their median by 0.80 percentage points.

This is consistent with a slow, smoothed state label: ADX can describe recent
trend strength while being too blunt as a mandatory next-open exit. State
persistence is not the same as permission to liquidate whenever the label
changes.

## Gates and boundary

`ENTRY_HIGH_ONLY` passed 4 of 8 gates: integrity, parent reproduction,
positive absolute return, and state specificity. `REACTIVE_HIGH_ONLY` passed
3 of 8: integrity, parent reproduction, and positive absolute return. Both
failed panel improvement, asset breadth, calendar breadth, and the joint
protection/risk-adjustment gate. Reactive also failed timing specificity.

Do not tune ADX or SMA lengths, relax the HIGH-only rule, select favorable
assets or 2018, defer skipped entries, add re-entry on state recovery, stack
ATR%/ER/breadth, or inspect 2024+ under this identifier. The valid learning is
conceptual and diagnostic: present-state utility should be assessed against a
specific action and update cadence, but an informative state may be better
treated as a graded input or conditional audit than as an all-or-nothing gate.
Any such formulation requires a separately justified and frozen question.

## Evidence

- Frozen contract:
  `docs/GEN5_HYP_REG_05_2_ADX_STRATEGY_RELATIVE_OVERLAY_CONTRACT.md`
- Run packet:
  `runs/research_workbench/operator_hypothesis_lab/hyp_reg_05_2_adx_strategy_overlay_20260815`
- Evidence deck:
  `operator_hypothesis_lab/presentations/hyp_reg_05_2_adx_strategy_relative_overlay_evidence.pptx`
