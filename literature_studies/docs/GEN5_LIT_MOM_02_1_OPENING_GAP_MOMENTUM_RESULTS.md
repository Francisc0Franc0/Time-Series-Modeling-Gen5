# LIT-MOM-02.1 Opening-Gap Momentum Results

Status: `STOP_LIT_MOM_02_1_OPENING_GAP_NO_TRAIN_NOMINEE`

Evidence deck:
[`gen5_lit_mom_02_1_opening_gap_evidence.pptx`](../presentations/gen5_lit_mom_02_1_opening_gap_evidence.pptx)

## Question

Does the direction of an opening gap beyond the previous session's extreme
predict continuation through the same close after a causal 09:32 entry and
retail transaction costs?

## What Chan's Example 7.1 actually does

Chan uses a 90-session lagged standard deviation of close-to-close returns and
sets `entryZscore=0.1`. A long signal occurs when today's open exceeds
yesterday's high multiplied by `1 + 0.1 sigma`; a short signal is the mirror
below yesterday's low. The position exits at the same close.

The source reports 13% APR and 1.4 Sharpe for `FSTX` from July 16, 2004 through
May 17, 2012. It also says FSTX was the best result after testing a number of
futures. That makes the headline useful textbook context but selected
in-sample evidence. The continuous-contract data and roll construction are not
supplied, so Gen5 recapitulates the example rather than claiming an exact
source-period reproduction.

The printed MATLAB return line, `positions.*(op-cl)./op`, is the negative of
the return implied by the prose and position labels. The rising Figure 7.1 is
also inconsistent with treating that literal sign as the strategy. Gen5 keeps
the literal line as an audit diagnostic and implements the narrative-consistent
momentum direction.

## Causal translation

The official open is needed to determine whether the gap crossed the threshold.
It cannot simultaneously be treated as a fill obtained after observing that
fact. The primary Gen5 translation therefore:

1. observes the completed opening auction at 09:31 ET;
2. uses the adjusted 09:32 SIP minute-bar open as the entry proxy;
3. exits at the adjusted daily close; and
4. charges 10 bp round trip, with a 20 bp stress view.

The same-official-open path is `NONCAUSAL_REFERENCE`. Historical borrow
availability and fees are not available, so the short side is research
evidence rather than proof of executable historical shorting.

## Small POC

The eight anchors were fixed before outcomes: `FEZ, SPY, QQQ, IWM, TLT, GLD,
USO, UUP`. `FEZ` is a U.S.-traded European-equity proxy, not FSTX futures.

| Symbol | Gates | Events | Long / short | Direction | Mean primary | Primary cumulative | Stress cumulative | Same-open reference |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| FEZ | 3/8 | 501 | 288 / 213 | 42.3% | -14.84 bp | -53.12% | -71.62% | -24.23% |
| SPY | 5/8 | 358 | 251 / 107 | 54.2% | -4.25 bp | -15.15% | -40.71% | +10.48% |
| QQQ | 4/8 | 342 | 245 / 97 | 51.5% | -7.80 bp | -24.88% | -46.66% | -9.01% |
| IWM | 4/8 | 261 | 162 / 99 | 51.7% | -7.62 bp | -19.33% | -37.88% | +1.36% |
| TLT | 4/8 | 448 | 243 / 205 | 51.1% | -9.21 bp | -34.28% | -58.04% | +4.16% |
| GLD | 4/8 | 423 | 240 / 183 | 50.4% | -8.94 bp | -31.93% | -55.44% | +3.61% |
| USO | 3/8 | 370 | 206 / 164 | 45.7% | -8.83 bp | -31.73% | -52.87% | +7.53% |
| UUP | 2/8 | 364 | 169 / 195 | 47.5% | -10.54 bp | -31.96% | -52.75% | -2.07% |

No anchor passed. The small POC therefore supplied no OOS nominee.

## Wide atlas

The unchanged rule was applied to 92 predeclared instruments across nine
categories. All 92 passed integrity and support. Seventy-one passed the 95%
09:32 entry-coverage requirement. The evidence then weakened:

- 45/92 exceeded 50% direction accuracy;
- 7/92 had a positive 10 bp primary-cost mean;
- 1/92 had a positive one-sided 90% bootstrap lower bound;
- 14/92 beat the seeded random-sign 90th percentile; and
- 0/92 passed the stress-and-stability conjunction.

Across 28,189 valid atlas events, the causal gross mean was only +0.48 bp per
event. The same-open reference mean was +0.63 bp. Both are far smaller than
the 10 bp retail round-trip friction, producing a pooled primary mean of
-9.52 bp. Long events were 50.84% directionally correct; short events were
47.25% correct. The rule therefore showed, at most, a very small gross
continuation tendency that did not survive the frozen retail translation.

Category medians were negative in all nine categories. Median primary means
ranged from -4.88 bp/event for leveraged or inverse ETFs to -12.98 bp/event
for industry ETFs.

## The XLP near-miss

`XLP` cleared seven gates:

- 201 valid events across all four TRAIN years;
- 112 long and 89 short events;
- 54.7% direction accuracy;
- +7.61 bp primary-cost mean;
- +0.71 bp one-sided 90% lower bound;
- +15.54% primary cumulative return; and
- a mean above the random-sign p90.

It failed the predeclared final gate because the 20 bp stress path returned
-5.49%, despite three positive calendar years. This is a legitimate near-miss,
not authority to relax costs, query its DEVELOPMENT outcome, or declare a
consumer-staples strategy. `EWW`, `UPRO`, and `JNJ` had positive primary point
estimates but negative uncertainty bounds and negative stress outcomes.

## Decision

Record `STOP_LIT_MOM_02_1_OPENING_GAP_NO_TRAIN_NOMINEE`.

- DEVELOPMENT entry data were not queried.
- CONFIRMATION beginning January 2, 2024 remains sealed.
- Do not rescue XLP, substitute same-open accounting, lower costs, drop the
  short side, select a category, change the gap threshold, or alter the
  volatility window on inspected evidence.
- A futures-native test with defensible continuous-contract data and
  futures-specific costs would be a different data and execution contract,
  not a decimal tweak to this retail atlas.

## Evidence packet

Generated artifacts are under
`runs/research_workbench/literature_grounded/lit_mom_02_1_opening_gap_atlas_01_20260801/`.
The packet includes the frozen registry, coverage audit, event manifest,
09:32 entry audit, small-POC and atlas summaries, eight-gate table, year table,
event tape, run specification, report, and visuals.

## Source boundary

Literature mechanics and published context come from Ernest P. Chan,
*Algorithmic Trading: Winning Strategies and Their Rationale* (2013), Example
7.1, printed pages 156-157 / PDF pages 174-175. The timing translation,
registry, costs, gates, random-sign control, conclusions, and STOP language are
Gen5 design under dialogue decision `D97`.
