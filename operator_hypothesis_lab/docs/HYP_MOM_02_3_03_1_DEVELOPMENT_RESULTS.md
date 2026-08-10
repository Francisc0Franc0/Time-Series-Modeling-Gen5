# HYP-MOM-02.3 and HYP-MOM-03.1 Development Results

Status: `STOP_NO_DEVELOPMENT_NOMINEE_CONFIRMATION_UNOPENED`

## Frozen candidates

`HYP-MOM-02.3` kept the qualified SMA200 entry and SMA50 exit from `02.2`, but
allowed later re-entry after a fresh SMA50 reclaim while price remained above
SMA200. Its declared parent was the strict-lockout `COMPOSITE_022` policy.

`HYP-MOM-03.1` treated a rising SMA200 as the regime permission and a fresh
SMA50 reclaim as the setup. It exited after loss of SMA50 or the rising-SMA200
permission. Its declared parent was fresh-cross `FRESH_021`.

Both were frozen with next-open execution, 5/10 bp per-side costs, full-capital
long-only compounding, buy-and-hold, 500 exposure-matched circular controls,
and nine conjunctive development gates before strategy outcomes were computed.

## Data feasibility amendment before outcomes

The bounded Alpaca refresh returned complete 2016-2020 bars for 114 registry
names but no pre-2016 observations. This was discovered before any candidate
outcome was computed. The declared 2016-2020 boundary was retained: the first
220 observed sessions of every eligible asset were used only as causal
indicator warm-up, the path started in cash on the next session, and evaluation
continued through 2020-12-31. Eight incomplete histories—LIN, ACB, SNAP, CGC,
BYND, APHA, SPCE, and LI—were excluded without replacement. This uniform
amendment changed no signal, parameter, cost, parent, gate, or later boundary.

## Development readout

| Policy | Median return | Stress | Positive assets | Median exposure | Median maximum drawdown | Matched-control excess | Control percentile |
|---|---:|---:|---:|---:|---:|---:|---:|
| Strict `02.2` parent | +5.54% | +4.75% | 73 / 114 | 19.51% | -17.04% | -5.15 pp | 39.8% |
| `HYP-MOM-02.3` re-entry repair | +6.65% | +3.99% | 72 / 114 | 31.45% | -22.27% | -11.68 pp | 31.9% |
| Fresh `02.1` parent | +14.79% | +13.36% | 81 / 114 | 55.59% | -30.75% | -20.55 pp | 25.4% |
| `HYP-MOM-03.1` pullback reclaim | +3.23% | +1.78% | 64 / 114 | 30.68% | -21.51% | -11.75 pp | 28.8% |

Raw positive returns were not enough. Every policy's actual calendar timing
ranked below its exposure-matched circular control median. This means the
policies benefited from being invested during a rising historical market, but
the observed SMA timing did not beat alternative placements with the same
amount of exposure.

### HYP-MOM-02.3 versus strict 02.2

The re-entry repair changed median return by +3.06 percentage points and
improved 62 of 114 assets (54.39%), narrowly missing the 55% breadth gate. It
also increased median exposure by 12.72 points and median trades by 12, while
worsening median drawdown by 4.40 points. Four calendar years had positive
equal-asset mean returns, but positive contribution was too concentrated in
one sector (46.0%). It failed matched-control excess, control percentile,
parent-improvement breadth, sector breadth, and drawdown gates.

### HYP-MOM-03.1 versus fresh 02.1

The pullback-reclaim policy improved median maximum drawdown by 9.42 points and
reduced median exposure by 27.89 points, but changed median return by -9.02
points and improved only 48 of 114 assets. It had three positive calendar
years and adequate trade/sector breadth, but failed matched-control excess,
control percentile, and parent-improvement breadth.

The representative tapes show why single winners cannot override the panel:
NIO and CPRX were favorable outliers; FCX and PLUG were severe deteriorations;
CVX and AMGN were close to the respective median parent-relative changes.

## Gate decision and sealed evidence

Neither candidate cleared all nine frozen gates. Record
`STOP_NO_DEVELOPMENT_NOMINEE_CONFIRMATION_UNOPENED`.

- The context atlas was structurally not run.
- No strategy queried 2024-2025 confirmation outcomes.
- The 2026-and-later sealed period was not queried.
- No asset selection, moving-average tuning, portfolio construction, or live
  authority follows from this work.

The useful lesson is narrower: faster exits can reshape drawdown, but simple
moving-average permission and re-entry rules have not demonstrated incremental
calendar-timing skill after matching exposure. A future lane needs a genuinely
new causal hypothesis rather than a softer version of these gates.

## Evidence

- Packet: `runs/research_workbench/operator_hypothesis_lab/hyp_mom_sma_followup_development_2016_2020_20260810/`
- `coverage.csv`
- `variant_panel_summary.csv`
- `candidate_parent_comparison.csv`
- `development_gates.csv`
- `annual_summary.csv`
- `representative_tape_manifest.csv`
- `integrity_checks.csv`
