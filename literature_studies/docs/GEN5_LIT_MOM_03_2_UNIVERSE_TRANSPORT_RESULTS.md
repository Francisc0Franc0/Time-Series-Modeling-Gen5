# LIT-MOM-03.2 Universe-Transport POC Results

## Question

Can the published dual-momentum principle be transported beyond its original
nine-ETF fleet, and can the same mechanics be meaningfully applied to curated
stock portfolios?

## Short answer

The mechanics can be applied to either ETFs or stocks. The frozen 2016-2026
transport results do **not** show broad return improvement, however. They show
that universe choice is part of the hypothesis rather than a neutral input.

The clean ten-sector-ETF fleet returned 8.53% annualized under the source rule,
versus 11.98% for equal-weight ownership of all ten sector ETFs and 14.36% for
SPY. Its maximum drawdown improved to -22.21%, versus -31.95% for equal weight.
The rule therefore exchanged return for a smoother path in this fleet.

Across eleven static eight-stock sector baskets, the source rule beat each
sector's equal-weight basket on CAGR in only 1/11 cases: Information
Technology, by 0.43 percentage points. It produced a shallower maximum
drawdown in 6/11 sectors. These are descriptive POCs, not inference or edge
claims.

## Frozen design

- Window: 507 complete weekly open-to-open intervals from 2016-06-30 through
  2026-03-19.
- Signal: completed Wednesday close, with the same Monday-Wednesday holiday
  fallback as LIT-MOM-03.1.
- Mechanics: unchanged 10- and 25-week simple returns, top three in each
  sleeve, positive-return permission, 50/50 sleeves, and equal-weight slots.
- Execution: next complete common-session open.
- Cost: 5 basis points per one-way traded notional, using drifted pretrade
  weights.
- Controls: equal-weight universe, relative-only, absolute-only, SPY
  ownership, and cash/no trade.
- Inference, horizon search, top-N search, forward confirmation, leverage, and
  live authority remained closed.

## Universe ladder

The first fleet contains ten long-lived U.S. sector SPDRs with complete local
history from the 2016 query start: XLB, XLE, XLF, XLI, XLK, XLP, XLRE, XLU,
XLV, and XLY. XLC was excluded before outcomes because its inception was after
the query start.

The stock experiment reuses the project's pre-existing return-geometry atlas:
eight long-history liquid stocks in each of eleven GICS-labeled sectors. This
keeps the source rule's top-three-from-roughly-nine geometry approximately
constant. The stock baskets are explicitly labeled
`STATIC_SURVIVOR_BIASED_EXPLORATORY_POC`. They were not reconstructed from
point-in-time memberships and cannot establish ex-ante tradeability.

## Descriptive results

| Fleet | Source CAGR | Equal-weight CAGR | Relative-only CAGR | Source minus equal | Source max drawdown | Equal-weight max drawdown |
|---|---:|---:|---:|---:|---:|---:|
| U.S. sector ETFs | 8.53% | 11.98% | 11.86% | -3.45 pp | -22.21% | -31.95% |
| Communication Services stocks | 14.62% | 15.16% | 17.89% | -0.54 pp | -31.94% | -41.76% |
| Consumer Discretionary stocks | 15.72% | 18.60% | 20.73% | -2.88 pp | -35.96% | -38.38% |
| Consumer Staples stocks | 8.14% | 12.20% | 10.65% | -4.06 pp | -24.68% | -18.44% |
| Energy stocks | 3.55% | 11.90% | 8.09% | -8.36 pp | -55.10% | -70.43% |
| Financial stocks | 14.33% | 18.10% | 17.68% | -3.76 pp | -32.91% | -43.64% |
| Health Care stocks | 10.47% | 15.12% | 11.84% | -4.64 pp | -28.10% | -21.39% |
| Industrial stocks | 14.88% | 14.95% | 17.69% | -0.07 pp | -40.38% | -41.15% |
| Information Technology stocks | 34.15% | 33.73% | 37.53% | +0.43 pp | -39.83% | -39.74% |
| Materials stocks | 9.94% | 14.56% | 12.68% | -4.62 pp | -39.05% | -35.61% |
| Real Estate stocks | 6.29% | 10.08% | 10.69% | -3.79 pp | -31.68% | -34.08% |
| Utility stocks | 3.28% | 10.29% | 7.24% | -7.00 pp | -33.93% | -27.04% |

## What the component control says

The absolute-momentum gate was economically active in these universes. Mean
invested weight ranged from 77.8% in Energy to 93.5% in sector ETFs. Relative
only outperformed source dual momentum in all twelve fleets, by 1.36 to 5.01
CAGR percentage points. At the same time, source maximum drawdown was
shallower than relative-only in 9/12 fleets.

This is a consistent tradeoff: the absolute gate frequently moved the
portfolio to cash during later rebounds as well as during declines. It acted
as a defensive exposure reducer, not as a return-enhancing timing filter.
That contrasts with the original nine-ETF source fleet, where exposure
averaged 97.44% and source was almost identical to relative only.

## Interpretation

The principle is mathematically asset-agnostic but not economically
universe-agnostic. Relative ranking requires a fleet whose members provide
useful substitution opportunities. Ranking eight stocks within one sector
does not automatically create value because common sector shocks dominate,
the strongest names may remain strong for long periods, and rotating among
them can sell durable winners. Ranking sector ETFs also failed to improve raw
return over owning the full fleet in this particular window.

The Information Technology result is not a promoted exception. It is only
0.43 CAGR points above equal weight, carries essentially the same maximum
drawdown, and comes from a survivor-biased basket containing extraordinary
historical winners. Treating that one green cell as validation would be the
exact outcome-driven curation error this breadth test was designed to expose.

The defensible conclusion is therefore not "stocks cannot use momentum." It
is that the exact source rule did not transport as a general-purpose return
enhancer across these curated fleets. Its more reproducible behavior was
drawdown shaping, purchased with lower CAGR.

## Evidence boundary and STOP

Record `UNIVERSE_TRANSPORT_POC_COMPLETE_DESCRIPTIVE_ONLY`.

No bootstrap inference or multiplicity family was added because this was a
first descriptive transport map. No universe was removed or replaced after
outcomes were observed. No point-in-time stock membership, broad 88-stock
portfolio, breadth-scaled top-N, alternate horizon, robustness battery, or
forward test was opened.

## Artifacts

- Packet:
  `runs/research_workbench/literature_grounded/lit_mom_03_2_universe_transport_20260903/`
- Module:
  `literature_studies/R/gen5_lit_mom_03_2_universe_transport.R`
- Runner:
  `literature_studies/scripts/run_gen5_lit_mom_03_2_universe_transport.R`
- Focused tests:
  `literature_studies/tests/testthat/test_gen5_lit_mom_03_2_universe_transport.R`
- Human-facing study:
  `literature_studies/presentations/gen5_lit_mom_03_1_dual_momentum_study.pptx`

## Next decision

A next slice should not search for a stock basket that turns green. The two
clean choices are:

1. freeze a breadth-preserving rule for the full 88-stock atlas, where top-N
   scales with universe size, to test cross-sector substitution rather than
   within-sector rotation; or
2. treat the absolute gate as an explicit risk-control candidate and compare
   its return cost with simpler exposure controls.

Point-in-time stock membership becomes necessary before any stock-universe
result can support promotion.
