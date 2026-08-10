# HYP-MOM-02 / Attribution Atlas 01 Results

Status: `REUSED_WINDOW_ATTRIBUTION_COMPLETE_NO_PROMOTION_AUTHORITY`

## Question and evidence boundary

This atlas separates the entry-confirmation, exit/lockout, and re-entry pieces
that were bundled inside `HYP-MOM-02.2`. It reuses the inspected 2021-2023
discovery window deliberately, so it can explain mechanics but cannot nominate
a strategy. The frozen 122-name registry yielded 119 eligible assets; APHA and
SNE had incomplete windows and LI lacked the required prehistory. All 12 market
and sector context series were complete. Every path starts in cash, uses a
completed-close signal, fills next open, compounds one full-capital long-only
asset path, and pays 5 bp per side with a 10 bp stress view.

## What the one-change-at-a-time comparison showed

| Policy | Median return | Stress | Median exposure | Median maximum drawdown | Median matched-control excess |
|---|---:|---:|---:|---:|---:|
| Fresh SMA200 cross / SMA200 exit (`FRESH_021`) | -2.73% | -4.25% | 43.48% | -28.11% | -12.60 pp |
| Add SMA50 entry confirmation only | -4.03% | -4.72% | 22.61% | -22.28% | -8.63 pp |
| Change to SMA50 exit plus lockout only | +1.54% | +0.41% | 18.62% | -17.93% | -0.92 pp |
| Full `02.2` composite | +0.38% | 0.00% | 16.76% | -16.14% | -3.12 pp |
| Add SMA50-reclaim re-entry (`02.3` diagnostic) | -2.76% | -3.34% | 18.48% | -18.24% | -6.79 pp |

The faster exit/lockout was the useful component. Relative to fresh-cross
`02.1`, it changed the median asset return by +3.85 percentage points and
maximum drawdown by +9.94 points while improving return in 69 assets. Adding
the SMA50 entry check to that fast-exit policy changed median return only
+0.24 points. Conversely, changing the confirmed-entry policy from the slow
exit to the fast exit changed median return by +4.01 points and drawdown by
+3.42 points. This is attribution, not proof of an optimal SMA50 threshold.

The first re-entry repair did not solve the opportunity-cost problem. Against
the strict `02.2` parent it changed median return by -2.07 points, improved only
53 of 119 assets, added four median trades, and slightly worsened median
drawdown. GE was a spectacular favorable path and TSLA a large adverse path;
the cross-asset median remained unfavorable.

## What happens after a fresh SMA200 cross

Across all 1,610 eligible five-session events, mean next-open return was
+0.17%, median return +0.33%, and direction accuracy 54.22%, but mean
SPY-relative return was -0.08%. At 20 sessions, mean return was +0.70% and
accuracy 53.62%, while mean SPY-relative return was -0.32%. At 60 sessions,
mean return remained +0.70%, accuracy fell to 51.67%, and SPY-relative return
fell to -0.91%. Non-overlapping event sensitivity did not reverse that basic
conclusion.

The entry close being above SMA50 was not a helpful standalone discriminator.
At 20 sessions, all events averaged +0.70%, above-SMA50 events +0.40%, and
rising-SMA200 events +1.29%. The conjunction of above SMA50 and rising SMA200
averaged +1.17% across 353 events and was approximately flat to SPY (+0.03%).
That rising-anchor observation informed the separately frozen `HYP-MOM-03.1`
development question; it was never selected from this reused window as alpha.

## Decision

Record `REUSED_WINDOW_ATTRIBUTION_COMPLETE_NO_PROMOTION_AUTHORITY`.

- Retain the causal evidence that exit/lockout did most of `02.2`'s defensive
  work.
- Reject the simple SMA50-reclaim re-entry as a discovery-window repair.
- Do not interpret positive absolute forward returns as SMA timing skill when
  relative and exposure-matched evidence remains weak.
- Do not tune moving-average lengths, select assets or sectors, or query later
  outcomes from this atlas alone.

The distinct-data candidates and gates were frozen before their 2016-2020
outcomes. See the companion development results for the promotion decision.

## Evidence

- Packet: `runs/research_workbench/operator_hypothesis_lab/hyp_mom_02_attribution_atlas_01_20260810/`
- `variant_panel_summary.csv`
- `mechanical_attribution_summary.csv`
- `event_summary.csv`
- `event_condition_summary.csv`
- `representative_tape_manifest.csv`
- `integrity_checks.csv`
