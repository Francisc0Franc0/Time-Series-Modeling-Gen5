# LIT-MOM-03.3 Broad Cross-Sector Stock-Fleet POC Results

## Question

Does the dual-momentum ranking principle look different when all 88 stocks
compete in one portfolio, allowing the strategy to substitute across sectors
instead of forcing a separate contest inside each eight-stock sector?

## Short answer

Yes, the competitive structure mattered descriptively. Relative-only rotation
across the full 88-stock fleet produced 17.95% net CAGR, versus 17.04% for
equal-weight ownership of all 88 stocks. That +0.90 percentage-point result is
the first positive ranking-versus-owning-the-fleet comparison in this transport
sequence.

The complete source rule did not preserve that return advantage. Adding the
positive-return gate reduced CAGR to 16.69%, 0.35 points below equal weight and
1.26 points below relative-only. The gate did improve maximum drawdown to
-24.83%, versus -28.57% for relative-only and -32.51% for equal weight. This is
again a defense-for-return tradeoff, not a clean full-rule win.

The result is an interesting descriptive POC, not edge evidence. The 88-stock
fleet is static and survivor-biased, no statistical inference or robustness
test was opened, and the same 2016-2026 history has now informed several related
questions.

## Frozen design

- Universe: the pre-existing `GICS_CORE` atlas, containing eight long-history
  liquid stocks in each of 11 sectors.
- Competition structure: all 88 stocks rank together in one fleet.
- Breadth translation: the source rule selects three of nine names per sleeve,
  a one-third fraction. The broad POC freezes 29 of 88 per sleeve. This value
  was chosen before outcomes and was not searched.
- Signal: completed Wednesday close, with the same Monday-Wednesday holiday
  fallback as LIT-MOM-03.1 and LIT-MOM-03.2.
- Horizons: unchanged 10- and 25-week simple returns.
- Allocation: 50/50 sleeves, equal-weight slots, overlap allowed, and failed
  positive-momentum slots assigned to cash.
- Execution: next complete common-session open.
- Cost: 5 basis points per one-way traded notional, using drifted pretrade
  weights.
- Controls: equal-weight 88, relative-only, absolute-only, SPY ownership, and
  cash/no trade.
- Window: 507 complete weekly open-to-open intervals from 2016-06-30 through
  2026-03-19.

## Descriptive results

| Variant | Net CAGR | Maximum drawdown | Annual volatility | Mean invested weight | Annualized one-way turnover |
|---|---:|---:|---:|---:|---:|
| Source dual momentum | 16.69% | -24.83% | 15.11% | 97.74% | 8.64x |
| Relative only | 17.95% | -28.57% | 15.92% | 100.00% | 8.38x |
| Absolute only | 8.09% | -15.15% | 8.47% | 63.85% | 4.39x |
| Equal-weight 88 | 17.04% | -32.51% | 16.61% | 100.00% | 0.73x |
| SPY ownership | 14.36% | -29.16% | 16.56% | 100.00% | 0.10x |
| Cash/no trade | 0.00% | 0.00% | 0.00% | 0.00% | 0.00x |

The relative-only portfolio finished at 4.972 times initial wealth, compared
with 4.615 times for equal-weight 88, 4.480 times for source dual momentum, and
3.682 times for SPY.

## What changed versus the sector-by-sector POCs

LIT-MOM-03.2 forced every stock to compete only with seven close sector peers.
That source rule beat equal-weight CAGR in only one of eleven sectors. LIT-MOM-
03.3 permits a weak sector to lose allocation to a strong sector as well as a
weak stock to lose allocation to a strong stock. The fixed-date allocation
snapshots confirm that sector weights moved materially through time; no sector
was permanently assigned a fixed quota.

Across the full sample, Information Technology received the largest average
source weight at 12.88%. Financials followed at 10.57%. Consumer Staples and
Utilities received the smallest average weights, near 6.8%. The largest weekly
weight in any one sector was 27.59%. That is meaningful substitution, but not a
single-sector portfolio in disguise.

## What the controls mean

The key comparison is relative-only versus equal-weight 88. Its +0.90-point
CAGR difference is the descriptive contribution of ranking and rotation before
the absolute gate. It is promising enough to preserve, but small relative to
the biases and untested choices still present.

Source dual momentum versus relative-only isolates the positive-momentum veto.
The veto cost 1.26 CAGR points while improving maximum drawdown by 3.74 points.
Source versus equal weight therefore combines two effects that point in
opposite directions: cross-sector relative ranking helped return, while the
cash gate gave back more return than ranking added and softened drawdown.

Absolute-only reinforces the interpretation. It reached only 8.09% CAGR with
63.85% mean exposure, showing that broad cash permission by itself was not the
return engine. SPY remained a useful attainable ownership comparator: both the
source and relative-only variants exceeded its CAGR in this retrospective
window, while source also had a shallower drawdown.

## Evidence boundary and STOP

Record `BROAD_CROSS_SECTOR_STOCK_FLEET_POC_COMPLETE_DESCRIPTIVE_ONLY`.

This result does not justify trading or promotion. The static atlas conditions
on names that survived and retained long histories. The breadth translation is
rational but not yet robust. Costs are stylized, no capacity or liquidity
stress was added, and the full sample is retrospective rather than sealed OOS.
No bootstrap inference, multiplicity family, alternate horizon, alternate
top-N, point-in-time universe, forward test, leverage, or live authority was
opened.

## Artifacts

- Packet:
  `runs/research_workbench/literature_grounded/lit_mom_03_3_broad_stock_fleet_20260903/`
- Module:
  `literature_studies/R/gen5_lit_mom_03_3_broad_stock_fleet.R`
- Runner:
  `literature_studies/scripts/run_gen5_lit_mom_03_3_broad_stock_fleet.R`
- Focused tests:
  `literature_studies/tests/testthat/test_gen5_lit_mom_03_3_broad_stock_fleet.R`
- Human-facing study:
  `literature_studies/presentations/gen5_lit_mom_03_1_dual_momentum_study.pptx`

## Next decision

The cleanest next gate is not another hand-curated fleet. If the operator wants
to pursue the +0.90-point relative-ranking clue, the next meaningful upgrade is
a point-in-time stock universe or another ex-ante universe construction that
removes static-survivor selection. A small, frozen robustness battery can
follow, but only after deciding whether the universe-bias repair is worth the
data effort. The positive-momentum gate should remain a separately named risk
control rather than being credited as part of the return signal.
