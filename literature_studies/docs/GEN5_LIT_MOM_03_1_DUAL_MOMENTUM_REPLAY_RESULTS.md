# LIT-MOM-03.1 Causal Dual-Momentum Replay Results

## Question

On the clean local 2016-2026 window, did the source-described combination of
relative ranking and absolute-momentum permission add economic value after a
causal execution translation, modest costs, and comparison with simpler
policies?

## Frozen replay

- Signals use completed Wednesday closes and the source's unchanged 10- and
  25-week rank/allocation mechanics.
- Target weights take effect at the next complete common-session open and are
  held to the following weekly execution open.
- The replay is self-financing and uses drifted pretrade weights.
- Cost is 5 basis points per one-way traded notional, including movements to
  and from cash. There is no artificial final liquidation charge.
- The final target without a complete next execution interval is excluded.
- Frozen controls are cash/no trade, weekly equal-weight all nine,
  relative-only top-three sleeves, absolute-only fixed asset shares, and
  continuous SPY ownership.
- Source-minus-control uncertainty uses 5,000 eight-week moving-block
  bootstrap draws, with Benjamini-Hochberg correction across the five frozen
  comparisons.

## Main readout

Across 507 weekly open-to-open intervals from 2016-06-30 through 2026-03-19:

| Policy | Ending wealth | Net CAGR | Annual volatility | Max drawdown | Annual one-way turnover |
|---|---:|---:|---:|---:|---:|
| Source dual momentum | 3.053 | 12.17% | 12.33% | -15.45% | 8.45x |
| Relative only | 3.055 | 12.18% | 12.34% | -15.45% | 8.30x |
| Equal-weight all nine | 2.366 | 9.27% | 10.27% | -20.79% | 0.48x |
| Absolute only | 1.749 | 5.92% | 5.98% | -7.62% | 4.20x |
| SPY ownership | 3.682 | 14.36% | 16.56% | -29.16% | 0.10x |
| Cash/no trade | 1.000 | 0.00% | 0.00% | 0.00% | 0.00x |

The source construction produced a real-looking return/drawdown compromise:
it compounded faster and drew down less than equal-weighting the entire
universe, and it had much less drawdown than SPY. It did not, however, beat
SPY on raw CAGR in this window.

## What the controls reveal

The decisive result is component attribution, not the 3.05x endpoint.

- Source versus relative only: the paths were virtually identical. The source
  CAGR was lower by 0.005 percentage points, the terminal-wealth ratio was
  0.9996, and the bootstrap interval for mean weekly difference straddled
  zero. The source held 97.44% invested on average. Therefore the
  absolute-momentum veto contributed almost nothing in this particular
  implementation and period.
- Source versus equal-weight all nine: source CAGR was 2.90 percentage points
  higher and maximum drawdown was 5.33 points shallower. The eight-week block
  interval for mean weekly difference was -0.038% to +0.137%, with BH
  q=0.202, so this attractive retrospective difference was not stable enough
  to separate statistically in the frozen comparison family.
- Source versus absolute only: source CAGR was 6.25 points higher, and the
  positive weekly difference survived the frozen BH family (q=0.002). This
  says ranking mattered relative to the deliberately diluted absolute-only
  construction; it does not prove that the combined source rule is unique.
- Source versus SPY: source CAGR was 2.18 points lower, while maximum drawdown
  was 13.71 points shallower. The weekly difference interval crossed zero.
  Whether that lower-return/lower-drawdown tradeoff is preferable is an
  operator objective question, not a statistical victory.
- Source versus cash: the source was plainly positive in this retrospective
  window and the weekly difference survived BH. Cash is necessary as a
  no-trade hurdle, but it is not the demanding ownership comparator.

All three broad phases were positive for the source: +29.4% in 2016-2019,
+36.0% in 2020-2022, and +73.5% in 2023-2026. Calendar-year returns were
negative in the partial 2016 start and in 2022, positive in all other observed
years, and almost exactly matched relative-only year by year.

## Interpretation

This slice supports a narrower claim than “dual momentum is edge.” A simple,
diversified relative-strength rotation policy produced an appealing
retrospective risk/return shape on the available nine-ETF window. The source's
absolute-momentum layer did not supply visible incremental protection or
return because nearly every selected slot was already positive. The result is
therefore better described as a promising **relative-rotation prototype**
than as confirmation of a distinct dual-momentum mechanism.

The comparison with SPY also illustrates the long-only hurdle discussed in
the opening deck. An active timing policy can look smooth and still leave raw
return on the table versus continuously owning a strong appreciating asset.
The active policy's possible value here is risk shaping, not demonstrated
outperformance.

## Evidence boundary and STOP

Record
`RETROSPECTIVE_VALUE_ADD_REPLAY_COMPLETE_NO_ROBUSTNESS_OR_FORWARD_AUTHORITY`.
This window overlaps the history on which the publisher selected the 10/25
week and top-three specification. It is not untouched confirmation. The
publisher's 2008-2015 segment remains unavailable under the current Alpaca
account and was not imputed. No alternate parameters, universe changes,
leverage, robustness battery, forward window, or live decision were opened.

## Artifacts

- Replay packet:
  `runs/research_workbench/literature_grounded/lit_mom_03_1_dual_momentum_replay_20260902/`
- Human-facing study:
  `literature_studies/presentations/gen5_lit_mom_03_1_dual_momentum_study.pptx`
- Replay module:
  `literature_studies/R/gen5_lit_mom_03_1_dual_momentum_replay.R`
- Runner:
  `literature_studies/scripts/run_gen5_lit_mom_03_1_dual_momentum_replay.R`
- Focused tests:
  `literature_studies/tests/testthat/test_gen5_lit_mom_03_1_dual_momentum_replay.R`

## Subsequent transport POC

The operator next opened a universe-only breadth test while preserving the
10/25-week, top-three, next-open, and 5-bps mechanics. See the
[universe-transport results](GEN5_LIT_MOM_03_2_UNIVERSE_TRANSPORT_RESULTS.md).
The source rule failed to improve CAGR over equal-weight ownership in the
clean sector-ETF fleet and in 10/11 static stock-sector baskets. Its more
consistent transported behavior was shallower drawdown at the cost of return.
That descriptive POC did not open robustness or forward authority.
