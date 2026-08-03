# HYP-MOM-01.1 Two Consecutive Green Gap-Ups: Discovery Results

Status: `DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY`

Evidence stage: `DISCOVERY_REUSED_WINDOW`

## Bottom line

The exact, causal rule fired often enough to study, but the generic version did
not show favorable timing evidence in the inspected 2021-2023 window. Its
`52.62%` primary-cost hit rate coexisted with a `-0.0178%` mean trade return:
modest winning trades were more common, while the losing tail was large enough
to erase that majority. Only `1 / 22` independent asset paths beat buy-and-hold,
and the median matched-random timing percentile was `34.25%`.

This is a productive discovery result, not a strategy candidate. It identifies
clear exit-path, environment, and pattern-strength questions without licensing
any filter or exit selected from the inspected outcomes.

## Frozen mechanics

For two consecutive completed sessions `t-1` and `t`, both sessions had to gap
above the prior close and close above their own open. The signal was observable
after `t` closed. Each asset then entered long at the adjusted open of `t+1`,
exited at the adjusted open of `t+6`, and paid 5 bp per side under the primary
cost view. Positions were fixed-quantity and fully invested within each asset
path, completed proceeds were reinvested, overlapping positions were forbidden,
and eligible same-open re-entry was allowed.

The test used 22 stocks spanning eleven sectors from 2021-01-04 through
2023-12-29. It was evaluated per asset and did not form a portfolio. Data were
Alpaca adjusted daily bars with explicit
`as_of_timestamp = 2026-07-30 17:30:00`. Data beginning in 2024 remained
excluded.

## Integrity and support

All required integrity checks passed:

- the copied registry contained exactly 22 unique assets and eleven sectors;
- every required stock and SPY had bounded source coverage;
- the source packet identified Alpaca adjusted daily bars and the explicit
  as-of timestamp;
- the discovery end preceded the excluded confirmation period;
- no duplicate asset-session rows were admitted; and
- the causal signal, next-open entry, five-interval exit, cost, overlap, and
  reinvestment semantics matched the frozen contract.

The rule generated `1,163` eligible signals. `821` were executed and `342`
arrived while the corresponding asset path was already invested.

## Pooled descriptive trade behavior

| Measure | Result |
|---|---:|
| Executed trades | 821 |
| Primary-cost hit rate | 52.6188% |
| Mean primary-cost trade return | -0.017795% |
| Median primary-cost trade return | +0.156563% |
| Mean unconditional five-session return | +0.274603% |
| Positive primary-cost asset paths | 11 / 22 |
| Assets beating buy-and-hold | 1 / 22 |
| Median matched-random percentile | 34.25% |
| Assets at or above the 80th random percentile | 4 / 22 |
| Worst asset-path maximum drawdown | -38.95% |

The difference between the positive median and negative mean is the central
lesson. Direction accuracy alone is not expectancy: a rule can be right more
often than wrong and still lose if its average loss is larger than its average
win. The unconditional five-session control was also stronger on average than
the executed signal trades, which weakens a continuation interpretation.

The asset-level compounded returns should not be pooled into a portfolio claim;
they are 22 independent full-capital thought experiments.

## Calendar-year behavior

| Exit year | Trades | Assets | Mean trade | Median trade | Hit rate |
|---|---:|---:|---:|---:|---:|
| 2021 | 314 | 22 | +0.3966% | +0.4371% | 58.60% |
| 2022 | 270 | 22 | -0.6487% | -0.5277% | 45.56% |
| 2023 | 237 | 22 | +0.1519% | +0.1330% | 52.74% |

This variation makes environment dependence plausible, but these same three
years cannot be searched for a market-state filter and then reused as evidence
for that filter.

## Representative asset paths

- `SHW`, the cross-sectional medoid, executed 41 trades and returned `-6.8%`
  versus `+31.1%` buy-and-hold, with a 30th-percentile random-timing result and
  `-27.3%` maximum drawdown.
- `MCD`, the strongest strategy endpoint, returned `+30.3%` across 39 trades
  and reached the 95th random percentile, but still trailed `+47.4%`
  buy-and-hold.
- `GOOGL`, the weakest strategy endpoint, returned `-31.9%` while buy-and-hold
  returned `+58.5%`; its random percentile was 2 and maximum drawdown was
  `-39.0%`.
- `NEE` returned `+14.5%` versus `-16.0%` buy-and-hold and reached the 86th
  random percentile. It was the only asset to beat ownership, so it is an
  anecdotal question—not a nominated asset, sector, or defensive filter.
- `CAT` had the most trades at 44, yet returned `-14.3%` versus `+72.8%`
  buy-and-hold. More occurrences did not improve the result.

## Representative individual trades

- The best trade, `AXP` in January 2023, returned `+12.17%` after primary
  costs, with `+15.49%` maximum favorable excursion and `-0.87%` maximum
  adverse excursion.
- The worst trade, `PLD` in April-May 2022, returned `-15.54%`; it never moved
  favorably after entry and lost `-5.85%` in the first session.
- The trade nearest the pooled median, `XOM` in February-March 2021, finished
  at `+0.16%` after falling `-2.14%` in the first session and reaching
  `-6.78%` maximum adverse excursion.
- The largest peak-to-exit giveback, `UNP` in January 2023, finished at
  `-15.01%` after a `-13.62%` first session.
- The largest trough-to-exit recovery, `XOM` in September-October 2022,
  finished at `+11.56%` after only `-1.19%` maximum adverse excursion.

These tapes show that the completed visual pattern did not guarantee immediate
follow-through. They motivate path-aware questions but do not choose a stop,
target, or shorter holding period.

## Recommended next discussion

The raw rule should not advance directly to fresh validation. The highest-
signal next step is to discuss one narrow, economically motivated question and
freeze it before another run:

1. **Exit path:** does early failure or post-entry giveback contain causal
   information before day five?
2. **Environment:** why did 2022 and most high-beta paths fail while the lone
   buy-and-hold exception was a utility?
3. **Pattern strength:** do gap magnitude and candle structure add information
   after signal multiplicity and search are controlled?

Changing the exit or signal mechanics would warrant `HYP-MOM-01.2`. A purely
diagnostic decomposition can remain attached to `01.1`, provided it makes no
strategy or validation claim.

## Artifacts

- Contract:
  `operator_hypothesis_lab/docs/HYP_MOM_01_1_TWO_GREEN_GAP_UPS_DISCOVERY_CONTRACT.md`
- Evidence deck:
  `operator_hypothesis_lab/presentations/hyp_mom_01_1_two_green_gap_ups_discovery_evidence.pptx`
- Reproducible runner:
  `operator_hypothesis_lab/scripts/run_hyp_mom_01_1_two_green_gap_ups_discovery.R`
- Ignored evidence packet:
  `runs/research_workbench/operator_hypothesis_lab/hyp_mom_01_1_two_green_gap_ups_discovery_20260803/`
