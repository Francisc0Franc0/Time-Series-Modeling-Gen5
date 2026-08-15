# HYP-REG-01.2 ATR% Strategy Overlay Results

Status: `STOP_DEVELOPMENT_OVERLAY_GATES_FAILED_CONFIRMATION_NOT_RUN`

## Question

Does the accepted `HYP-REG-01.1` ATR% state improve the unchanged
`HYP-MOM-06.1` daily SMA8/SMA14 strategy if fresh entries are suppressed only
when the signal-close state is `LOW`?

This is the first strategy-level use of the volatility sensor. It is a reused-
window DEVELOPMENT experiment, not confirmation evidence.

## Frozen Design

- Parent strategy: daily SMA8/SMA14 fresh cross, next-open entry, SMA cross-down
  exit, long/cash, 5 bp per side.
- Overlay: `ATR_LOW_OFF`; skip a fresh entry only when the causal state at the
  signal close is `LOW`. Do not defer the entry and do not alter exits.
- Primary panel: 24 predeclared stocks, six annual cells from 2018 through
  2023, for 144 stock asset-years. SPY and QQQ remain reference-only.
- State authority: accepted adjusted-daily `HYP-REG-01.1` ledger.
- Strategy authority: daily execution surface reconstructed from the accepted
  30-minute SIP archive used by `HYP-MOM-06.1`.
- Controls: unchanged strategy, buy-and-hold, 200 deterministic circular state
  shifts, and the 40 shifted controls nearest the overlay's exposure.
- Secondary only: 10 bp stress cost and 1.8x fixed-quantity leverage with the
  existing financing and maintenance-risk accounting.
- Boundary: no 2024+ observation was accessed and no alternate state
  combination, ATR setting, SMA setting, asset, or year was tried.

## Integrity and Parent Reproduction

All 26 assets retained the required state and strategy calendars. Each asset
had 1,499 strategy sessions and 1,509 state sessions; the ten additional state
dates are the globally excluded SIP archive-gap sessions. Every strategy date
matched exactly one causal state.

The unfiltered replay matched all 156 retained parent rows with maximum
absolute return difference `4.44e-15`, comfortably inside the frozen `1e-10`
tolerance. The overlay's retained entry set also matched the expected
non-`LOW` parent entries exactly.

## Primary Readout

| Policy | Median annual return | Median maximum drawdown | Median Sharpe | Median exposure | Trades |
|---|---:|---:|---:|---:|---:|
| Unfiltered SMA8/SMA14 | 8.95% | -14.59% | 0.642 | 53.88% | 1,394 |
| ATR LOW off | 4.44% | -11.85% | 0.485 | 40.95% | 931 |
| Buy and hold | 14.60% | -20.94% | 0.704 | 100.00% | 144 |

The overlay reduced median drawdown by 2.74 percentage points, but it also
reduced median annual return by 4.51 points and median Sharpe by 0.157. Only
9 of 24 stocks improved six-year compounded return, and panel-median excess
was positive in 0 of 6 calendar years.

The overlay remained profitable in absolute median terms, but that is not
enough: the question was whether the state gate improved the existing policy.

## What the Gate Removed

The 491 removed `LOW`-state parent trades were not obviously inferior. Their
mean return was 1.08%, median return was -0.12%, and hit rate was 48.1%.
The 1,003 retained `MEDIUM`/`HIGH` opportunities had similar negative median
trades and only slightly lower hit rates. The important distinction was the
right tail: some low-volatility entries developed into large trends, and the
entry gate permanently surrendered those opportunities.

This explains the observed bargain: fewer trades and smaller drawdowns, but
too much lost upside.

## Regime-Specificity Control

The actual overlay's median exposure was 40.95%. Among the 40 circular-state
controls nearest that exposure, its median annual return ranked at only the
37.5th percentile and was 0.15 percentage points below their median. Thus the
observed protection was consistent with generic exposure removal; the actual
`LOW` dates were not unusually favorable dates to suppress.

## Secondary Leverage View

At 1.8x, the unfiltered strategy retained an 11.94% median annual return and
-25.30% median drawdown. The overlay produced 5.53% and -20.77%. No strategy
maintenance-proxy breach occurred, but leverage did not repair the selection
problem. It amplified both policies while preserving the overlay's relative
weakness.

## Frozen Gates

| Gate | Result |
|---|---:|
| Integrity | PASS |
| Parent reproduction | PASS |
| Panel return | FAIL |
| Asset breadth | FAIL |
| Calendar breadth | FAIL |
| Protection and risk adjustment | FAIL |
| Absolute viability | PASS |
| Regime specificity | FAIL |

## Interpretation and Pushback

`HYP-REG-01.1` is not invalidated. It still predicts future directionless
movement magnitude. What fails is a stronger and different proposition:
that `LOW` volatility is a bad time to begin this fast/medium daily trend
trade.

For SMA8/SMA14, a quiet state can be the launch pad for a later expansion. A
contemporaneous volatility label measures how much the asset has been moving;
it does not by itself identify whether a new trend is about to begin. This is
why a valid classifier can be a poor permission rule.

Do not rescue this lane by trying `HIGH`-only, `MEDIUM`-only, alternative ATR
lengths, thresholds, years, or hand-selected assets on the same evidence. A
future regime concept should begin with a new causal hypothesis—for example,
transition or expansion dynamics—then receive its own frozen controls and
fresh validation boundary.

## Decision

Record `STOP_DEVELOPMENT_OVERLAY_GATES_FAILED_CONFIRMATION_NOT_RUN`.

- Preserve `HYP-REG-01.1` as a successful volatility diagnostic.
- Reject `ATR_LOW_OFF` as a strategy gate for `HYP-MOM-06.1`.
- Do not inspect the sealed 2024+ confirmation interval.
- Do not change portfolio, advice, leverage, or live behavior.

## Evidence Packet

`runs/research_workbench/operator_hypothesis_lab/hyp_reg_01_2_strategy_overlay_20260814`

Key files are `hyp_reg_01_2_report.md`, `hyp_reg_01_2_policy_panel.csv`,
`hyp_reg_01_2_gates.csv`, `hyp_reg_01_2_parent_reproduction.csv`,
`hyp_reg_01_2_trade_audit.csv`, `hyp_reg_01_2_placebo_panel.csv`, and the
purpose-built charts under `visuals/`.
