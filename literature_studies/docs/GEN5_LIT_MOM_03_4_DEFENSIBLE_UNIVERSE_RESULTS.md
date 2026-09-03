# LIT-MOM-03.4 Defensible Deployment-Cohort Results

## Question

Does the broad-stock relative-ranking clue survive when the fleet is fixed from
information available before the evaluation period rather than from stocks
known to retain long histories through the endpoint?

## Answer

Barely, and not at a magnitude that justifies promotion.

Relative-only rotation earned 10.80% net CAGR from January 2021 through March
2026, versus 10.66% for equal-weight ownership of the same causally scoreable
deployment cohort. The resulting ranking difference was only +0.14 percentage
points. That is much smaller than the +0.90-point difference observed in the
static survivor-biased 88-stock atlas.

The full dual-momentum rule earned 9.39% CAGR. Its positive-return gate cost
1.41 points versus relative-only while improving maximum drawdown by only 0.05
points. SPY was the strongest return comparator at 12.80% CAGR, although its
-26.10% maximum drawdown was deeper than the stock-fleet implementations near
-21%.

Record `DEFENSIBLE_UNIVERSE_REPLAY_COMPLETE_STOP_RANKING_EDGE_NOT_NOMINATED`.
The unchanged broad-stock translation should not advance to tuning or a
robustness search.

## Why this universe is more defensible

- The source cohort is the SPDR S&P 500 ETF Trust holdings report dated
  September 30, 2020 and accepted by the SEC in November 2020.
- The frozen registry contains 481 identities that had exact 2016-2020 Alpaca
  adjusted-bar coverage. No post-2020 outcome selected membership.
- The evaluation begins in January 2021.
- Later mergers, failures, acquisitions, and ticker disappearances remain in
  the evidence. They are not replaced with successful current constituents.
- Weekly ranking uses only identities with current, 10-week-lag, and
  25-week-lag closes known on that decision date.

This is a fixed deployment-date cohort rather than rolling historical S&P 500
membership. That narrower claim is reproducible and appropriate for the
question being asked.

## Data admission

The bounded cache refresh completed across the 482 required symbols, including
SPY. Raw workbench health remained `WARN` because 44 frozen identities ceased
to cover the full requested endpoint. Those incomplete histories are expected
evidence under an ex-ante cohort, not grounds to delete the identities.

All ten terminal-aware admission gates passed:

- 481-row registry and source hash matched;
- all 11 contemporaneous sectors were represented;
- source timing preceded evaluation;
- SPY's execution calendar was complete;
- scoreable breadth began at 481, had a median of 454, and a minimum of 437;
- the one-third selection count was exact each week; and
- the largest terminal-proxy weight fraction was 0.047%, far below the frozen
  5% ceiling.

The replay therefore covered 271 weekly open-to-open intervals from January 7,
2021 through March 19, 2026.

## Descriptive results

| Variant | Net CAGR | Maximum drawdown | Annual volatility | Ending wealth |
|---|---:|---:|---:|---:|
| Source dual momentum | 9.39% | -20.62% | 15.04% | 1.594x |
| Relative only | 10.80% | -20.67% | 15.77% | 1.703x |
| Equal-weight eligible cohort | 10.66% | -20.91% | 16.29% | 1.692x |
| Absolute only | 4.57% | -13.27% | 8.45% | 1.261x |
| SPY ownership | 12.80% | -26.10% | 16.05% | 1.869x |
| Cash/no trade | 0.00% | 0.00% | 0.00% | 1.000x |

## What changed after the bias repair

The broad 88-stock atlas suggested that cross-sector ranking might add a small
return increment. The ex-ante cohort preserves the same basic competition
structure but removes the most important favorable selection: knowing which
stocks survived and maintained full histories through 2026.

The ranking increment did not reverse, but it compressed from +0.90 points to
+0.14 points. This is consistent with a weak or unstable effect that cannot be
distinguished from implementation noise on this evidence. The result is not a
failed proof that momentum never exists. It is a stop for this particular
10/25-week, one-third, broad-stock implementation.

The cash gate again fails as a return engine. In this later cohort its drawdown
improvement versus relative-only was only 0.05 points, despite costing 1.41
CAGR points. Absolute-only confirms that broad positive-return permission by
itself is not the source of the portfolio's return.

## Decision and STOP

Do not tune nearby horizons, selection fractions, or the cash threshold to
rescue this result. Do not promote the static-atlas +0.90-point observation.
Preserve the broader conceptual lesson:

1. momentum may be a weak portfolio-level tendency;
2. ranking universe and baseline determine whether it looks economically
   useful; and
3. a conventional diversified ownership portfolio can be a stronger use of
   the same investable opportunity set than an elaborate rotation rule.

No inference, multiplicity family, parameter search, leverage, live advice, or
capital deployment authority is opened.

## Artifacts

- Contract:
  `literature_studies/docs/GEN5_LIT_MOM_03_4_DEFENSIBLE_UNIVERSE_CONTRACT.md`
- Packet:
  `runs/research_workbench/literature_grounded/lit_mom_03_4_defensible_universe_20260903/`
- Module:
  `literature_studies/R/gen5_lit_mom_03_4_defensible_universe.R`
- Runner:
  `literature_studies/scripts/run_gen5_lit_mom_03_4_defensible_universe.R`
- Focused tests:
  `literature_studies/tests/testthat/test_gen5_lit_mom_03_4_defensible_universe.R`
- Human-facing study:
  `literature_studies/presentations/gen5_lit_mom_03_1_dual_momentum_study.pptx`

## Next decision

Close this exact broad-stock translation. The higher-value next huddle is to
separate two jobs:

- design a conventional, low-cost diversified core portfolio around the
  operator's horizon, liquidity needs, tax accounts, and actual drawdown
  tolerance; and
- keep strategy research in a separately capped experimental sleeve until a
  candidate earns genuine forward authority.

That core portfolio would be an investment-policy exercise, not evidence that
LIT-MOM-03.4 found edge.
