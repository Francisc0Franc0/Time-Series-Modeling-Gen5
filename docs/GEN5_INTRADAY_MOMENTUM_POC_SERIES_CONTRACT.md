# Gen5 Intraday Momentum POC Series Contract

Status: `DEVELOPMENT_COMPLETE_STOP_BEFORE_REGIME_FILTER`

Roadmap authority: `D125`

## Questions

1. `HYP-MOM-06.1`: what follows from a fresh daily SMA8/SMA14 long/cash
   crossover?
2. `HYP-IMOM-01.1`: what follows from the same numeric crossover on 30-minute
   bars?
3. `HYP-IMOM-02.1`: can TRAIN select a portable session-scaled price/SMA
   policy?
4. `LIT-IMOM-01.1`: can TRAIN select a portable 30-minute Chan `L/H` policy
   under canonical overlapping sleeves?

All questions are long-only, unfiltered, and per asset. No portfolio or live
authority is opened.

## Frozen evidence boundary

- Query/prehistory start: `2017-09-01`.
- Development: `2018-01-02` through `2023-12-29`.
- First expanding TRAIN: `2018-01-02` through `2020-12-31`.
- Causal outer tests: twelve calendar quarters from `2021Q1` through `2023Q4`.
- Confirmation: `2024-01-02+`, sealed and not queried.
- Explicit as-of timestamp: `2026-08-13 17:30:00 America/New_York`.

Fixed-rule SMA8/SMA14 results are also reported in six cash-bounded calendar
years from 2018 through 2023. No position crosses a reporting-block boundary.

## Frozen universe

Use `operator_hypothesis_lab/registries/gen5_intraday_momentum_poc_registry.csv`:

- AMD and TSLA are outcome-aware canonical educational cases;
- 22 stocks reuse the previously frozen two-per-sector literature atlas;
- SPY and QQQ are reference ETFs.

The 24-stock panel governs breadth summaries and global price/SMA selection.
The ETFs are reported separately. Coverage failures are excluded without
replacement and remain visible.

## Intraday data admission

- Provider/feed: Alpaca SIP.
- Timeframe: `30Min`.
- Adjustment: `all`.
- Regular session only: bar starts `09:30` through `15:30` ET.
- Normal session: 13 bars.
- Early-close sessions may contain seven bars ending `12:30` ET.
- Every admitted asset must match SPY's timestamp calendar exactly over the
  development interval and have at least 520 pre-development bars.
- Reject duplicate timestamps, nonpositive/nonfinite OHLC, invalid OHLC
  ordering, off-grid timestamps, confirmation bars, and incomplete pagination.
- Cache yearly RDS packets under ignored `data_cache/alpaca_intraday_30min/`.

The intraday module is research-only and cannot alter the stable Gen5 daily
provider.

### Outcome-independent archive correction

Before accepting any strategy result, the admission audit corrected
early-close handling and identified ten sessions absent from the Alpaca SIP
historical archive across SPY and the frozen atlas. A matched Alpaca IEX query
filled zero gaps, and Yahoo rejected the historical 30-minute requests because
they were outside its 60-day intraday window. Under the operator-approved
fallback, the same ten sessions were excluded globally with no imputation:

`2018-05-02`, `2018-05-03`, `2018-08-07`, `2019-08-12`, `2019-10-09`,
`2021-04-19`, `2021-10-25`, `2022-01-24`, `2022-01-26`, and `2022-03-08`.

All 26 assets then passed exact corrected-calendar parity with 19,415
development bars each. The strategy contracts and 2024+ seal remained
unchanged.

## Common execution and accounting

- Signals use completed bars.
- Primary execution is the next bar open.
- Delay sensitivity executes one complete bar later.
- Blocks start in cash and force liquidation at the final block close.
- Positions may cross overnight inside a block.
- Reinvest realized profits and losses at subsequent entries.
- Test `1x` and fixed-quantity `1.8x`.
- At entry, notional is leverage times current strategy equity; shares remain
  fixed until exit.
- Financing accrues on debt by actual elapsed calendar time.
- Maintenance-equity proxy: 25%.

Costs and financing:

| Frequency | Primary cost | Stress cost | Primary financing | Stress financing |
|---|---:|---:|---:|---:|
| Daily | 5 bp/side | 10 bp/side | 6% annual | 10% annual |
| 30-minute | 10 bp/side | 20 bp/side | 6% annual | 10% annual |

Parameter selection uses only `1x` primary-cost TRAIN evidence. Leverage cannot
select or rescue a policy.

## Fixed SMA8/SMA14 mechanics

For both daily and M30 data:

- fresh `SMA8 > SMA14` cross: enter next open;
- fresh `SMA8 <= SMA14` cross: exit next open;
- start in cash even if the first in-window bar is already above;
- require a fresh in-window cross before entry.

The daily reference is aggregated from the admitted M30 SIP bars so frequency
comparisons share identities, corporate-action treatment, and calendar.

## Price/SMA selection family

Slow anchors are `65,130,260,520` bars. Each has:

- symmetric exit below the same anchor; and
- asymmetric exit below `round(anchor/4)`.

For each outer fold, score every candidate across TRAIN calendar years using
equal-weight fractional ranks of median return, positive-stock breadth,
median Sharpe, median maximum drawdown, and median excess versus buy-and-hold.
Average yearly composites. Form a one-standard-error tolerance set around the
best mean and select the lowest median trade-count candidate; ties prefer the
longer anchor and then symmetric mechanics.

Replay the selected candidate on the next quarter without refitting.

## Chan selection and sleeves

Candidate grid:

\[
L \in \{13,26,65,130,260\},\qquad H \in \{13,26,65\}.
\]

- Past and subsequent returns are close-to-close.
- TRAIN anchors advance by `min(L,H)` (`CHAN_MIN_STEP`).
- Minimum support: 40 return pairs.
- Admissible: positive Pearson correlation with naive `p <= 0.10`.
- Select per asset by largest correlation t-statistic; ties prefer shorter `H`
  and then shorter `L`.
- If no candidate is admissible, that asset holds cash for the next quarter.
- A positive signal launches one of `H` equal-capital sleeves at the next open.
- Each sleeve is held exactly `H` bars and is reused only after its prior trade
  exits. At 1.8x, each sleeve applies the same fixed-quantity leverage overlay.

Inference must remain labeled naive at the candidate level. Whole-session
timing shifts provide the strategy-level null while preserving time of day.

## Required baselines and controls

- cash;
- 1x and 1.8x fixed-quantity buy-and-hold;
- corresponding daily SMA8/SMA14 path;
- 200 deterministic exposure/timing shifts by whole sessions at the same
  leverage;
- next-bar versus one-complete-bar-delay execution;
- gross, primary, and stress scenarios.

## Required outputs

For every lane report return, Sharpe, drawdown, time underwater, exposure,
turnover, trade count, hit rate, mean/median trade, holding duration, financing,
minimum equity, maintenance-proxy breaches, positive breadth, and direct- and
timing-control excess.

Produce AMD/TSLA tapes plus representative winner, loser, whipsaw, and extended
trend paths. Intraday diagnostics separate entry time, same-session versus
overnight contribution, and normal versus early-close sessions.

## Stop and interpretation

These are unfiltered POCs. Passing a descriptive metric does not authorize a
regime filter, confirmation access, asset selection, portfolio, advice, or live
execution. After all lanes are recorded, pause for the regime-design discussion
required by D125.

The completed readout is recorded in
`operator_hypothesis_lab/docs/GEN5_INTRADAY_MOMENTUM_POC_SERIES_RESULTS.md`.
No lane is promoted. Regime-filter design remains a separate operator gate.
