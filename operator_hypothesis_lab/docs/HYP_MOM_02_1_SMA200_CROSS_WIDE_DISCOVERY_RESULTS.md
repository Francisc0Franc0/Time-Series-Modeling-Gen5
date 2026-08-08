# HYP-MOM-02.1 SMA200 Cross Wide Discovery Results

Status: `WIDE_DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY`

Evidence stage: `DISCOVERY_REUSED_WINDOW`

Run packet: `runs/research_workbench/operator_hypothesis_lab/hyp_mom_02_1_sma200_cross_wide_discovery_20260808/`

## Bottom line

Across this wide 2021-2023 stock panel, the causal next-open SMA200 cross rule
behaved primarily as a **defensive exposure filter**. It reduced typical
drawdown and helped many collapsing stocks lose less, but it usually lagged
continuous ownership and did not show favorable timing relative to matched
circular shifts of the same long/cash schedule.

The result is neither “SMA200 is useless” nor “SMA200 works.” It is a concrete
tradeoff: less time in the market and some downside protection were purchased
with frequent whipsaws and substantial foregone upside.

## Frozen implementation

- SMA: simple mean of the latest 200 completed adjusted closes;
- long state: completed close strictly above its contemporaneous SMA200;
- execution: desired state is implemented at the next open;
- exit: next open after a completed close falls below SMA200;
- exposure: fully invested long in each independently evaluated asset or cash;
- finite-window boundaries: warm-start at the first open when the prior state
  is already above; administrative liquidation at the final open;
- primary costs: 5 bp per side; stress costs: 10 bp per side;
- discovery: January 4, 2021 through December 29, 2023;
- 2024 and later: excluded.

This state-following formulation is mathematically equivalent to buying the
cross above and selling the cross below once the strategy is running. The
warm-start rule avoids turning the arbitrary evaluation start date into a
false signal requirement.

## Coverage

The frozen registry combined the prior 22-name Operator Hypothesis Lab panel
with the previously registered 100-name breadth-attention atlas: 122 unique
stocks across 11 sectors.

- 119 were eligible;
- `APHA` and `SNE` lacked the complete discovery window;
- `LI` had only 108 pre-discovery sessions versus the frozen 220-session
  minimum;
- no identity was replaced.

A bounded provider refresh left the same coverage and results. Its remaining
`partial_history`, `refresh_needed`, and `stale_symbol` warnings are structural:
the explicit as-of timestamp is in 2026 while the query intentionally ends in
2023, and several tickers do not exist for the entire requested 2019 warm-up
range. Every analyzed asset has the exact discovery calendar and required
prehistory.

## Asset-level consequence

| Measure | Wide result |
|---|---:|
| Eligible assets | 119 |
| Completed round trips | 1,729 |
| Median SMA200 strategy return | +6.24% |
| Median buy-and-hold return | +20.79% |
| Median excess versus buy-and-hold | -19.33 pp |
| Positive strategy paths | 70 / 119 |
| Assets beating buy-and-hold | 30 / 119 |
| Median invested fraction | 60.82% |
| Median annualized daily Sharpe | 0.21 |
| Median strategy maximum drawdown | -30.12% |
| Median buy-and-hold maximum drawdown | -36.73% |
| Median drawdown improvement | +4.31 pp |
| Assets with improved drawdown | 79 / 119 |
| Median percentile versus matched circular shifts | 33.8% |
| Assets above the 80th matched-shift percentile | 2 / 119 |

All 30 assets that beat buy-and-hold also improved maximum drawdown, but 49
additional assets improved drawdown while still lagging ownership. This makes
the main economic distinction visible: drawdown defense was much broader than
return improvement.

The typical asset spent about 61% of sessions invested. Some return lag is
therefore an exposure consequence during an upward-biased window, but the
matched timing control shows that reduced exposure is not the whole story.

## What the trade distribution teaches

The 1,729 pooled trades had:

- mean primary return: `+0.86%`;
- median primary return: `-1.35%`;
- hit rate: `25.0%`;
- mean duration: `30.7` sessions;
- median duration: `5` sessions;
- trades lasting 20 sessions or fewer: `71.0%`.

This is the classic convex shape of slow trend following. Price frequently
oscillates around a lagging average, producing many small false starts. A
minority of long-lived trends creates the positive mean trade. Consequently,
hit rate is an especially misleading evaluation metric here: only one trade
in four won, yet the pooled mean was positive because winners were much larger
and longer than the typical loser.

The result also explains why “200-day” does not imply a 200-day holding period.
The average defines a slow anchor; it does not prevent price from crossing that
anchor repeatedly in a few sessions.

## Buy-and-hold versus protection

The median return sacrifice was large: about 19.3 percentage points relative
to buy-and-hold. Median maximum drawdown improved by about 4.3 points. Whether
that exchange is attractive cannot be decided by calling one metric primary
after seeing the results. A growth objective and a capital-preservation
objective will value the same path differently.

The fixed source cohorts make the distinction vivid:

| Cohort | Assets | Median strategy | Median buy-and-hold | Median excess | Median drawdown improvement |
|---|---:|---:|---:|---:|---:|
| Original 22 | 22 | +11.10% | +35.41% | -18.81 pp | +2.42 pp |
| Diversified core | 75 | +7.58% | +25.06% | -23.44 pp | +2.92 pp |
| Retail attention 2020 | 22 | -22.33% | -31.26% | +20.93 pp | +21.78 pp |

The attention cohort is not a success case: its median SMA strategy still lost
22.3%. It is a protection example—the filter lost less than owning many
collapsing stocks continuously. Conversely, the strategy captured only a
fraction of the strong energy rally: the sector's median strategy return was
about +59% versus +167% for ownership. Cohort and sector comparisons remain
descriptive, not selection rules.

## Matched timing control

For each asset, 500 circular shifts moved the complete binary exposure state
against the realized open-to-open returns. The shifts preserve exposure
fraction and the persistent block structure of long and cash states, but break
the actual SMA timing.

The median observed percentile was only `33.8%`; 36 of 119 assets exceeded the
50th percentile and only `MMM` and `GE` exceeded the 80th. Thus the actual
SMA200 alignment was generally not unusually favorable relative to other
placements of the same amount and shape of exposure.

This control is deliberately diagnostic. Shifted states are not proposed as
executable strategies, and their dependent observations are not treated as
independent p-values. Their purpose is to stop us from attributing every
benefit of being out of the market to the specific SMA timing rule.

## Representative path audit

The frozen tapes expose several different consequences:

- `CL`, median excess: strategy `-19.1%` versus essentially flat ownership;
- `CGC`, highest excess: strategy `-15.2%` versus buy-and-hold `-97.9%`—a
  dramatic rescue, but still a loss;
- `CPRX`, lowest excess: strategy `+173.9%` versus buy-and-hold `+416.0%`—a
  large absolute gain that nevertheless missed most of the trend;
- `META`, best drawdown improvement: strategy `+89.7%` versus ownership
  `+30.7%`, with maximum drawdown around `-27.9%` rather than roughly `-79%`;
- `VZ`, highest trade count: almost identical strategy and ownership losses,
  illustrating repeated crossings without benefit;
- `JPM`, longest median hold: strategy `+65.3%` versus ownership `+45.8%`, a
  clean example of a long trend being retained.

`CGC` and `CPRX` are important interpretation checks. “Best excess” can still
lose money, while “worst excess” can still make a great deal of money. Relative
and absolute success are different questions.

## Decision

Record `WIDE_DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY`.

The minimal hypothesis produced a clear, educational result. In this reused
window and wide fixed stock panel, SMA200 long/cash ownership was broadly more
effective at reducing severe drawdowns than at improving returns. Its many
short losing trades and low matched-shift percentile argue against describing
the rule as a general timing edge.

Do not tune the SMA length, add a buffer, select sectors, choose favorable
assets, add stops, or promote the attention-cohort protection after inspecting
this packet. A future variant must begin by declaring its objective—growth,
drawdown defense, or a pre-specified utility combining both—and then freeze a
substantive mechanics change on distinct evidence.

No portfolio, allocation, live advice, or execution behavior is authorized.
