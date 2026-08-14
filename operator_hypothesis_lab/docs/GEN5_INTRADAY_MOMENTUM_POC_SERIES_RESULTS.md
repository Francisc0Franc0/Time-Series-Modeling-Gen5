# Gen5 Intraday Momentum POC Series Results

Status: `DEVELOPMENT_COMPLETE_STOP_BEFORE_REGIME_FILTER`

Decision authority: `D125`, completed under `D126`

## Question

What happens when four simple, unfiltered long/cash momentum policies are
tested on the same admitted daily and 30-minute stock panel, with causal
next-bar execution, explicit costs, 1x and fixed-quantity 1.8x leverage, and
whole-session timing controls?

The four estimands were:

1. `HYP-MOM-06.1`: daily SMA8/SMA14 crossover;
2. `HYP-IMOM-01.1`: the same numeric crossover on 30-minute bars;
3. `HYP-IMOM-02.1`: TRAIN-selected price/SMA cross using session-scaled
   anchors; and
4. `LIT-IMOM-01.1`: a session-scaled long/cash adaptation of Chan's Chapter 6
   lookback/holding-period screen and overlapping sleeve execution.

No regime filter was fitted. The 2024+ confirmation period was not queried.

## Data admission and the SIP gap decision

The frozen universe contained 24 stocks plus SPY and QQQ. The provider was
Alpaca SIP adjusted `30Min` OHLCV with an explicit as-of timestamp. A first
calendar comparison incorrectly treated some post-close bars on early-close
days as regular-session bars; the admission module was corrected before any
strategy result was accepted.

Ten sessions then remained absent from the Alpaca SIP historical archive for
SPY and the entire atlas:

`2018-05-02`, `2018-05-03`, `2018-08-07`, `2019-08-12`, `2019-10-09`,
`2021-04-19`, `2021-10-25`, `2022-01-24`, `2022-01-26`, and `2022-03-08`.

A matched Alpaca IEX request supplied zero replacement bars. Yahoo's
historical 30-minute endpoint returned HTTP 422 because the requested periods
were outside its 60-day intraday window. The approved outcome-independent
fallback therefore excluded the same ten sessions globally, without
imputation, and reran admission. All 26 assets then matched the corrected SPY
calendar exactly with 19,415 development bars each. This is a common-calendar
conditional study, not a claim that the missing sessions did not occur.

## Frozen evaluation

- Development: 2018 through 2023.
- Expanding TRAIN and twelve quarterly outer tests: 2021Q1 through 2023Q4.
- Every block began in cash and ended flat.
- Signals used completed bars; primary execution was the next open.
- Daily costs: 5 bp/side primary, 10 bp/side stress.
- 30-minute costs: 10 bp/side primary, 20 bp/side stress.
- Debt financing: 6% primary and 10% stress.
- Parameter selection used only 1x TRAIN evidence.
- Baselines included cash, same-leverage buy-and-hold, 200 deterministic
  whole-session timing shifts, one-bar delay, and gross/stress scenarios.

Median returns below use the 24-stock breadth panel. Daily/fixed-SMA blocks are
asset-years; selected intraday policies use asset-quarters.

| Lane | 1x median return | Positive blocks | Median buy-and-hold | Median direct excess | Median max drawdown | Trades |
|---|---:|---:|---:|---:|---:|---:|
| `HYP-MOM-06.1` daily SMA8/14 | +8.95% | 70.14% | +14.60% | -5.83 pp | -14.59% | 1,394 |
| `HYP-IMOM-01.1` 30m SMA8/14 | -14.47% | 18.75% | +14.49% | -26.62 pp | -25.11% | 17,900 |
| `HYP-IMOM-02.1` price/SMA | -0.86% | 39.24% | +2.01% | -3.32 pp | -7.01% | 1,933 |
| `LIT-IMOM-01.1` Chan sleeves | 0.00% | 14.24% | +2.01% | -4.58 pp | 0.00% | 49,363 sleeves |

The Chan row includes all-cash assignments when no TRAIN candidate was
admissible. Only 115 of 288 stock-quarters traded. Within those active blocks,
the 1x median return was -2.79%, only 35.65% were positive, median direct
excess was -6.92 pp, and median maximum drawdown was -9.79%.

## Lane readouts

### HYP-MOM-06.1 — daily SMA8/SMA14

The daily rule was the only lane with a positive median absolute return. Its
actual timing ranked at the 95.0th percentile of 200 equally exposed
whole-session shifts, with an upper-tail randomization p-value of 0.0547.
That is useful timing evidence, but not ownership alpha: median direct excess
versus buy-and-hold was -5.83 pp and only a partial share of the upward drift
was captured. Stress costs reduced median return to +7.87%; a one-session
delay changed it to +9.08%, so the result was not dependent on exact next-open
timing. The 1.8x overlay increased median absolute return to +11.94% but
worsened direct underperformance and drawdown; leverage did not create a new
edge.

Decision: retain as the best unfiltered baseline and a possible future regime
research parent, not as a promoted strategy.

### HYP-IMOM-01.1 — 30-minute SMA8/SMA14

The numeric `8/14` pair did not transport across clocks. The 30-minute rule
completed 17,900 trades with 248.9x median annual turnover, a -0.37% median
trade, and an 11-bar median hold. Its actual timing was better than most
equally exposed shifts (98.0th percentile), but both actual and null policies
lost heavily. Positive gross open-to-close and overnight components existed;
the frozen 10 bp/side cost model consumed them. Stress costs drove median
return to -33.29%, and the one-bar delay to -15.48%. The 1.8x overlay worsened
median return to -28.21%.

Decision: stop this exact high-turnover parameterization. Its failure does not
show that all intraday SMA momentum is invalid; it shows that these horizons
and frictions are economically mismatched.

### HYP-IMOM-02.1 — TRAIN-selected price/SMA

TRAIN selected the longest 520-bar anchor in every fold: symmetric through
2022Q4, then a 130-bar asymmetric exit in 2023. That apparent stability did
not transport into stable OOS performance. Median return was -0.86%, median
direct excess -3.32 pp, and the actual panel return was worse than all 200
whole-session timing shifts. Stress costs and one-bar delay worsened the
median to -1.85% and -1.30% respectively. The 1.8x overlay also worsened the
result.

Decision: stop the selected family before confirmation. Do not select the
attractive TSLA or AMD tapes after inspection.

### LIT-IMOM-01.1 — Chan-style intraday sleeves

The TRAIN screen used `L in {13,26,65,130,260}`, `H in {13,26,65}`,
`min(L,H)` spacing, at least 40 pairs, positive Pearson correlation, and naive
`p <= 0.10`. Admission varied from 9 to 12 of 26 assets per quarter. A
positive signal launched one `1/H` sleeve at the next open and held it for
exactly H bars; non-admitted assets stayed in cash.

The all-panel median return and its shifted-control median were both zero
because cash dominated the cross-section. This makes the return percentile
degenerate rather than favorable. Direct excess was -4.58 pp and ranked near
the bottom of the timing null. Active blocks also lost at the median. The
one-bar-delay panel median remains exactly zero after restoring all-cash rows
to the same denominator as primary and stress scenarios.

Decision: record a completed textbook transport exercise and stop before
confirmation. Naive candidate p-values are screening statistics, not proof of
independent intraday evidence.

## What the leverage overlay taught us

No strategy breached the frozen 25% maintenance-equity proxy. That does not
make 1.8x benign. Across every lane, leverage enlarged the magnitude of the
underlying result and generally deepened drawdown. A small fraction of 1.8x
buy-and-hold blocks became nonfinite after losses exceeded modeled equity, so
direct-excess summaries are intentionally unavailable for those blocks rather
than silently clipped.

## Series conclusion

Record `DEVELOPMENT_COMPLETE_STOP_BEFORE_REGIME_FILTER`.

The series produced one useful positive baseline and three clear
falsifications:

- the daily 8/14 rule captured meaningful absolute drift and some timing value
  but did not beat ownership;
- the same numeric horizons on 30-minute bars were overwhelmed by turnover;
- the longer price/SMA selector was less costly but did not beat timing
  controls; and
- Chan-style intraday horizon selection admitted an unstable minority and did
  not transport economically.

The next open decision belongs to the operator: whether to design a separate,
causal regime-filter research contract. Any such lane must be a new estimand,
must not optimize on these outcomes, and must preserve 2024+ as distinct
evidence unless the operator explicitly opens it.

## Artifacts

- Contract: `docs/GEN5_INTRADAY_MOMENTUM_POC_SERIES_CONTRACT.md`
- Registry: `operator_hypothesis_lab/registries/gen5_intraday_momentum_poc_registry.csv`
- Evidence packet: `runs/research_workbench/operator_hypothesis_lab/intraday_momentum_poc_series_20260813`
- Fixed-frequency deck: `operator_hypothesis_lab/presentations/hyp_mom_06_1_hyp_imom_01_1_frequency_evidence.pptx`
- Price/SMA deck: `operator_hypothesis_lab/presentations/hyp_imom_02_1_price_sma_evidence.pptx`
- Chan deck: `operator_hypothesis_lab/presentations/lit_imom_01_1_chan_sleeves_evidence.pptx`
