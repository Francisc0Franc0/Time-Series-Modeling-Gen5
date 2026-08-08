# HYP-MOM-02.1 SMA200 Cross Wide Discovery Results

Status: `WIDE_DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY`

Evidence stage: `DISCOVERY_REUSED_WINDOW`

Authoritative mechanics: `CROSS_TRIGGERED_ONLY_NO_WARM_START`

Run packet: `runs/research_workbench/operator_hypothesis_lab/hyp_mom_02_1_sma200_cross_wide_discovery_20260808/`

## Bottom line

The corrected 2021-2023 study answers the narrow question that motivated this
lane: begin in cash, enter only after a newly completed in-window cross above
SMA200, and return to cash after a completed cross below.

Across 119 eligible stocks, fresh crosses were weak generic return signals.
The median cross-triggered path lost `2.73%` after primary costs while median
buy-and-hold gained `20.79%`. Only `26 / 119` asset paths beat ownership, and
the median observed timing ranked at the `27.4th` percentile of matched
circular shifts. The rule did, however, reduce maximum drawdown in `88 / 119`
assets, with a median improvement of `5.98` percentage points.

The clean interpretation is therefore sharper than the original warm-start
readout: this implementation supplied downside protection by spending more
time in cash, but the fresh cross itself did not demonstrate a broad timing
edge in the inspected window.

## Why the correction mattered

The first implementation entered at the first evaluation open when an asset
was already above SMA200. That was causal--the pre-window state was known--but
it answered the broader state-ownership question, "What happens if we own
whenever above SMA200?" It did not precisely answer, "What happens after a new
cross above?"

The authoritative correction begins every asset in cash. A cross must complete
on or after January 4, 2021, and entry occurs at the following open. Merely
being above SMA200 at the boundary is ignored.

| Measure | Warm-start readout | Corrected cross-only readout |
|---|---:|---:|
| Completed round trips | 1,729 | 1,624 |
| Median invested fraction | 60.82% | 43.48% |
| Median strategy return | +6.24% | -2.73% |
| Positive asset paths | 70 / 119 | 52 / 119 |
| Assets beating buy-and-hold | 30 / 119 | 26 / 119 |
| Median drawdown improvement | +4.31 pp | +5.98 pp |
| Assets with improved drawdown | 79 / 119 | 88 / 119 |
| Median matched-shift percentile | 33.8% | 27.4% |

Removing 105 boundary entries materially reduced exposure and return. This is
why the original result is superseded rather than presented as an equivalent
filtering of the trade table: the whole account path, compounding, drawdown,
Sharpe, and matched control had to be recomputed from cash.

## Authoritative implementation

- SMA: simple mean of the latest 200 completed adjusted closes;
- signal: completed close crosses from at-or-below SMA200 to strictly above;
- initialization: cash until the first in-window cross above;
- execution: enter at the open after the completed cross;
- exit: next open after a completed close crosses from above to at-or-below;
- exposure: fully invested long in each separately evaluated asset or cash;
- final boundary: administrative liquidation at the final open;
- primary costs: 5 bp per side; stress costs: 10 bp per side;
- discovery: January 4, 2021 through December 29, 2023;
- 2024 and later: excluded.

All 1,624 entries are labeled `CROSS_ABOVE`. The earliest entry was January 5,
2021, after a January 4 signal. No warm-start entry remains.

## Coverage

The frozen registry combines the prior 22-name Operator Hypothesis Lab panel
with the previously registered 100-name breadth-attention atlas: 122 unique
stocks across 11 sectors.

- 119 were eligible;
- `APHA` and `SNE` lacked the complete discovery window;
- `LI` had only 108 pre-discovery sessions versus the frozen 220-session
  minimum;
- no identity was replaced;
- all 119 eligible assets generated at least one in-window cross above.

The prior bounded refresh remains authoritative for coverage. Remaining query
warnings are structural because the explicit as-of timestamp is in 2026 while
the discovery query intentionally ends in 2023.

## Asset-level consequence

| Measure | Corrected wide result |
|---|---:|
| Eligible assets | 119 |
| Completed round trips | 1,624 |
| Median strategy return | -2.73% |
| Mean strategy return | +2.44% |
| Median buy-and-hold return | +20.79% |
| Median excess versus buy-and-hold | -21.76 pp |
| Positive strategy paths | 52 / 119 |
| Stress-positive paths | 50 / 119 |
| Assets beating buy-and-hold | 26 / 119 |
| Median invested fraction | 43.48% |
| Median annualized daily Sharpe | 0.03 |
| Median strategy maximum drawdown | -28.11% |
| Median buy-and-hold maximum drawdown | -36.73% |
| Median drawdown improvement | +5.98 pp |
| Assets with improved drawdown | 88 / 119 |
| Median percentile versus matched circular shifts | 27.4% |
| Assets above the 80th matched-shift percentile | 3 / 119 |

All 26 assets that beat buy-and-hold also improved drawdown. Another 62
improved drawdown while still lagging ownership. This makes the economic
distinction unusually clear: risk reduction was broad, but return improvement
was not.

## What the trade distribution says

The 1,624 pooled cross-triggered trades had:

- mean primary return: `+0.15%`;
- median primary return: `-1.35%`;
- hit rate: `23.15%`;
- mean duration: `23.6` sessions;
- median duration: `4` sessions;
- trades lasting 20 sessions or fewer: `74.69%`.

The distribution is strongly right-skewed: most trades were short false starts,
while a smaller number of longer winners lifted the mean above the median.
That is what the earlier deck called "convexity." More precisely, empirical
right skew is what this run directly demonstrates. Mathematical convexity is
a stronger statement: a payoff function is convex when its slope increases as
the underlying move increases, or equivalently when its second derivative is
positive where defined. A dynamic trend rule can resemble a positively convex
payoff because losses are repeatedly cut and large trends remain open, but this
study did not estimate a formal payoff curvature. The careful label here is
therefore **right-skewed, asymmetric trade outcomes**, not proven convexity.

The low hit rate is not automatically disqualifying for a trend strategy, but
the pooled mean of only `+0.15%` before account-level opportunity costs is thin,
and the asset paths and matched controls were unfavorable.

## Return versus protection

The fixed source cohorts retain the same qualitative split:

| Cohort | Assets | Median strategy | Median buy-and-hold | Median excess | Median drawdown improvement |
|---|---:|---:|---:|---:|---:|
| Original 22 | 22 | +4.63% | +35.41% | -20.09 pp | +3.56 pp |
| Diversified core | 75 | -1.05% | +25.06% | -27.56 pp | +4.57 pp |
| Retail attention 2020 | 22 | -18.67% | -31.26% | +12.83 pp | +27.95 pp |

The attention cohort remains a protection example rather than a success case:
its median strategy still lost 18.67%. Energy remains the clearest opportunity
cost example because the rule joined a powerful uptrend late and captured only
a fraction of continuous ownership. Cohort and sector views are descriptive;
they do not authorize selection rules.

## Matched timing control

For each asset, 500 circular shifts move the complete cross-triggered binary
exposure schedule against realized open-to-open returns. The shifts preserve
the fraction of time invested and the persistent block structure of the
long/cash schedule while breaking its actual calendar alignment.

The median observed percentile fell to `27.4%`; only 34 of 119 assets exceeded
the 50th percentile. `ADBE`, `CHTR`, and `GE` exceeded the 80th percentile.
Thus, even after correcting the boundary, the actual cross alignment was
usually less favorable than other placements of the same exposure shape.

This is a diagnostic control, not a formal p-value and not an executable
alternative strategy.

## Representative path audit

The frozen selection rules now identify four unique assets across six roles;
duplicate roles are retained transparently rather than replaced after seeing
the outcomes:

- `AEP`, median excess: strategy `-13.4%` versus ownership `+8.3%`;
- `CGC`, highest excess and best drawdown improvement: strategy `-16.4%`
  versus buy-and-hold `-97.9%`;
- `MPC`, lowest excess and longest median hold: strategy `+23.1%` versus
  buy-and-hold `+286.8%`;
- `VZ`, highest trade count: strategy `-22.7%` versus ownership `-25.1%`.

`CGC` is still a rescue that loses money. `MPC` is still a profitable strategy
path that misses most of an exceptional trend. Relative return, absolute
return, and drawdown protection remain distinct questions.

## Decision

Record `WIDE_DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY` with
`CROSS_TRIGGERED_ONLY_NO_WARM_START` as the authoritative implementation.

Fresh SMA200 crosses did not demonstrate a broad return-timing edge in this
reused window. The rule more consistently reduced drawdown by waiting in cash,
but that protection came with lower exposure, large foregone upside, frequent
false starts, and unfavorable matched timing.

Do not tune the SMA length, add a buffer, select sectors, choose favorable
assets, add stops, or promote the attention-cohort protection after inspecting
this packet. A future variant must declare whether its objective is growth,
drawdown defense, or a pre-specified combination, then freeze a substantive
mechanics change on distinct evidence.

No portfolio, allocation, live advice, or execution behavior is authorized.
