# HYP-REG-04.1 Cross-Sectional Trend-Field Contract

Status: `FROZEN_FOR_DIAGNOSTIC_EXECUTION`

## Where This Fits

`HYP-REG-03.1` and `03.2` established that sector breadth is measurable but
rejected two specific implementations as stable market-direction filters.
`HYP-REG-04.1` opens a new family. It measures the contemporaneous direction,
participation, multi-horizon agreement, and flow of a diverse ETF field rather
than treating past breadth decay as a warning that must persist.

This is the proposed market direction/health axis that could eventually be
tested beside the accepted asset-relative `HYP-REG-01.1` ATR% magnitude axis.
It does not join ATR%, inspect asset strategies, or create permission rules.

## Operating Interpretation

If later promoted through separate overlay and confirmation work, the field
would describe the market surrounding an asset such as TSLA or AMD. ATR% would
describe that asset's own directionless movement magnitude. An unchanged asset
strategy would still generate its entry and exit signal.

`market field x asset ATR% x asset signal` is therefore a possible future
routing architecture, not an inference that a positive field automatically
means buy TSLA or that a negative field automatically means short it.

## Scope Boundary

This lane may calculate causal market measurements, future cross-sectional
measurement targets, and a secondary SPY direction target. It may not compute
strategy P&L, Sharpe, drawdown, costs, trades, allocation, leverage, advice, or
live behavior. It may not join ATR%, select TSLA/AMD behavior, or route any
strategy.

The latent market mode, economic confirmation network, VIX structure,
intraday persistence, and point-in-time constituent breadth remain unopened.

## Evidence Boundary

- Provider: Alpaca adjusted daily OHLCV.
- Explicit as-of: `2026-08-14 17:30:00 America/New_York`.
- Query start: 2016-01-04.
- Development analysis: 2018-01-02 through 2023-12-29.
- Temporal halves: 2018-2020 and 2021-2023.
- Confirmation seal: 2024-01-02 and later are prohibited.
- Missing sessions are not imputed.

The development window has been inspected in earlier lanes. It is not fresh
confirmation. A pass can open only a discussion about a separately frozen
joint-regime diagnostic.

## Fixed Signal Universe

Twenty-four long-lived ETFs provide one market-level observation per session.
They are grouped to prevent a collection of correlated tickers from being
misrepresented as independent evidence:

- **broad/style/size:** RSP, QQQ, IWM, MDY, IWD, IWF;
- **sector/real assets:** XLB, XLE, XLF, XLI, XLK, XLP, XLU, XLV, XLY, VNQ;
- **industry/cyclical:** SMH, XBI, IYT, XHB, XRT, KRE;
- **international:** EFA, EEM.

SPY is context and the secondary external target; it is excluded from the
cross-sectional field. These ETFs are stable exposure proxies, not independent
samples and not exact constituent breadth. Each measurement is first calculated
within each of the four groups, then the four group values receive equal weight.
The ten-member sector group therefore cannot dominate the two-member
international group merely because it contains more tickers.

## Per-Asset Trend Measurement

For signal asset `i`, define close-to-close returns:

`r20_i,t = log(C_i,t / C_i,t-20)`

`r60_i,t = log(C_i,t / C_i,t-60)`

Let `sigma63_i,t-1` be the sample standard deviation of the preceding 63 daily
log returns, ending at `t-1`. Today's return is excluded from the normalizer.

`z20_i,t = r20_i,t / (sigma63_i,t-1 * sqrt(20))`

`z60_i,t = r60_i,t / (sigma63_i,t-1 * sqrt(60))`

The fixed trend score is:

`m_i,t = (z20_i,t + z60_i,t) / 2`

No weight, horizon, or normalizer is fitted.

## Four Separate Field Measurements

For each economic group `g`, first calculate the within-group median direction
and within-group means for participation, agreement, and flow. Then define:

1. **Direction:** `D_t = median_g(median_i-in-g(m_i,t))`.
2. **Participation:** `P_t = mean_g(mean_i-in-g(1[m_i,t > 0]))`.
3. **Agreement:**
   `A_t = mean_g(mean_i-in-g(1[sign(z20_i,t) = sign(z60_i,t)]))`.
4. **Flow:** the equal-group mean of each group's improving-minus-deteriorating
   trend-score fraction over five sessions.

The measurements are retained independently. No fitted scalar health score is
created.

## Fixed Descriptive State Map

- `BROAD_UP`: `D_t >= 0`, `P_t >= 0.60`, `A_t >= 0.60`, and `F_t >= 0`.
- `FRAGILE_UP`: `D_t >= 0` but the full `BROAD_UP` conjunction is not met.
- `BROAD_DOWN`: `D_t < 0`, `P_t <= 0.40`, `A_t >= 0.60`, and `F_t < 0`.
- `FRAGILE_DOWN`: `D_t < 0` but the full `BROAD_DOWN` conjunction is not met.

`BROAD` means cross-sectionally coherent; it does not mean low risk. A broad
down state may be a strong and dangerous negative trend.

## Fixed Targets

### Primary measurement targets

- `future_field_return_h20`: median of the four within-group median
  `log(C_i,t+20 / C_i,t)` values.
- `future_field_participation_h20`: equal-group mean of the within-group
  fractions with a positive H20 close-to-close return.
- `future_participation_change_h5`: `P_t+5 - P_t`.
- `directional_persistence_h20`:
  `sign(D_t) * future_field_return_h20`.

These test whether the field names its own future semantics. They are not
tradable portfolio returns.

### Secondary external target

`spy_return_h20 = log(SPY open_t+21 / SPY open_t+1)`.

The signal is known after close `t`; the SPY target begins at the next open.
It checks whether a market-level field has external directional meaning. SPY
is not the ultimate operating asset.

## Frozen Contrasts

1. **Direction:** `BROAD_UP` minus `BROAD_DOWN`.
2. **Positive-trend health:** `BROAD_UP` minus `FRAGILE_UP`.

All-daily rows provide effect sizes. All 20 deterministic H20 starting offsets
provide non-overlapping direction-stability views. Temporal halves, calendar
years, and 200 deterministic within-year circular state-label rotations are
reported.

## Frozen Gates

All nine gates must pass for
`DIAGNOSTIC_COMPLETE_STOP_BEFORE_ATR_JOIN_OR_STRATEGY`:

1. **Integrity:** 25/25 assets have complete requested-window coverage; every
   field row has 24 signal inputs; timing is causal; 2024+ is excluded.
2. **Direction semantics:** `BROAD_UP` and `BROAD_DOWN` each have at least 100
   daily rows; their future-field-return gap is at least +2.0 percentage points
   and future-participation gap at least +20 percentage points.
3. **Positive-health semantics:** `BROAD_UP` and `FRAGILE_UP` each have at least
   100 rows; broad-up future-field return is at least +0.50 percentage points
   higher, participation at least +10 points higher, and future-negative rate
   at least 10 points lower.
4. **Continuous ordering:** Spearman direction versus future-field return is
   at least 0.15; participation versus future-field return at least 0.10; flow
   versus future H5 participation change at least 0.10; and agreement versus
   directional persistence is positive.
5. **Offset stability:** at least 15/20 offsets contain five observations in
   both broad direction states and at least 14/20 have positive field-return
   and participation gaps.
6. **Temporal transport:** direction return/participation gaps and positive-
   health return/participation gaps are positive in both halves.
7. **Calendar stability:** direction return and participation gaps are positive
   in at least five of six years; positive-health return and participation gaps
   are positive in at least four.
8. **Circular timing control:** actual direction return and participation gaps
   are at or above the 90th percentiles; actual positive-health return and
   participation gaps are at or above the 80th percentiles.
9. **Secondary SPY direction:** broad-up minus broad-down SPY H20 return is at
   least +1.0 percentage point, direction-score SPY-return Spearman is at least
   0.10, SPY-UP AUC is at least 0.55, and the return gap is positive in both
   temporal halves.

If any gate fails, record
`STOP_TREND_FIELD_GATES_FAILED_NO_ATR_JOIN_OR_STRATEGY`.

## Required Artifacts

- candidate-family and eventual-integration explanation;
- frozen registry, run spec, coverage, health, and integrity;
- daily component and field ledger;
- state, continuous, offset, temporal, calendar, and circular summaries;
- purposeful field, state, transport, and external-target visuals;
- concise evidence deck with speaker-note references;
- explicit STOP before ATR joining, strategy overlays, or confirmation access.
