# HYP-REG-04.2 Fast Cross-Sectional Trend-Impulse Contract

Status: `FROZEN_FOR_DERIVATIVE_DEVELOPMENT_EXECUTION`

## Where This Fits

`HYP-REG-04.1` showed that an equal-group 20/60-session trend field was a
coherent description of the recent market but did not preserve its meaning
into the next 20 sessions. Broad negative states were frequently followed by
recovery. `HYP-REG-04.2` asks a materially different, retrospectively motivated
question: does a newly broadening five-session impulse preserve direction and
participation over the next five to ten sessions?

This remains a standalone market-measurement diagnostic. It does not join the
accepted asset-relative ATR% magnitude state, inspect TSLA or AMD strategies,
or create a trading permission rule.

## Research Status and Evidence Boundary

This hypothesis was created after inspecting 2018-2023 results from earlier
regime lanes. That period is therefore derivative development evidence, not
fresh confirmation.

- Provider: Alpaca adjusted daily OHLCV.
- Explicit as-of: `2026-08-14 17:30:00 America/New_York`.
- Query start: 2016-01-04.
- Derivative development: 2018-01-02 through 2023-12-29.
- Temporal halves: 2018-2020 and 2021-2023.
- Confirmation seal: 2024-01-02 and later are prohibited.
- Missing sessions are not imputed.

A pass can open only a discussion about separately freezing untouched
confirmation. It cannot promote a regime filter or authorize an ATR% join.

## Scope Boundary

This lane may calculate causal market measurements, future cross-sectional
semantic targets, and secondary next-open SPY targets. It may not calculate
strategy P&L, Sharpe, drawdown, hit rate, trades, costs, allocation, leverage,
advice, or live behavior. It may not invert a failed result, choose among a
lookback grid, inspect 2024+, join ATR%, or alter an asset strategy.

## Fixed Universe and Equal-Group Aggregation

The 24 field ETFs and four economic groups are unchanged from `HYP-REG-04.1`:

- **broad/style/size:** RSP, QQQ, IWM, MDY, IWD, IWF;
- **sector/real assets:** XLB, XLE, XLF, XLI, XLK, XLP, XLU, XLV, XLY, VNQ;
- **industry/cyclical:** SMH, XBI, IYT, XHB, XRT, KRE;
- **international:** EFA, EEM.

SPY is excluded from the field and retained only as a secondary external
target. Every cross-sectional statistic is calculated within each group first;
the four group values then receive equal weight.

## Per-Asset Measurements

For field asset `i` at close `t`:

`r5_i,t = log(C_i,t / C_i,t-5)`

`r20_i,t = log(C_i,t / C_i,t-20)`

Let `sigma63_i,t-1` be the sample standard deviation of the preceding 63 daily
log returns ending at `t-1`. The current session is excluded.

`z5_i,t = r5_i,t / (sigma63_i,t-1 * sqrt(5))`

`z20_i,t = r20_i,t / (sigma63_i,t-1 * sqrt(20))`

No horizon, normalizer, or weight is fitted.

## Four Separate Field Measurements

1. **Fast direction:**
   `D5_t = median_g(median_i-in-g(z5_i,t))`.
2. **Fast participation:**
   `P5_t = mean_g(mean_i-in-g(1[z5_i,t > 0]))`.
3. **Participation impulse:**
   `I5_t = P5_t - P5_t-5`.
4. **Medium context direction:**
   `D20_t = median_g(median_i-in-g(z20_i,t))`.

The measurements remain separate. There is no fitted scalar score.

`alignment_t = 1[sign(D5_t) = sign(D20_t)]` distinguishes continuation from a
fresh reversal. It is a diagnostic label, not an extra requirement imposed on
the primary impulse state.

## Fixed State Map

- `BROAD_UP_IMPULSE`: `D5_t >= 0`, `P5_t >= 0.60`, and `I5_t > 0`.
- `OTHER_UP`: `D5_t >= 0` without the full broad-up conjunction.
- `BROAD_DOWN_IMPULSE`: `D5_t < 0`, `P5_t <= 0.40`, and `I5_t < 0`.
- `OTHER_DOWN`: `D5_t < 0` without the full broad-down conjunction.

Each row also receives one context label: `UP_CONTINUATION`, `UP_REVERSAL`,
`DOWN_CONTINUATION`, or `DOWN_REVERSAL`. Context labels are reported but are
not used to select a winning variant.

## Fixed Targets

### Primary H5 semantics

- `future_field_return_h5`: equal-group median five-session close-to-close
  field return.
- `future_field_participation_h5`: equal-group fraction with positive H5
  return.
- `future_participation_change_h5 = P5_t+5 - P5_t`.
- `directional_persistence_h5 = sign(D5_t) * future_field_return_h5`.

### H10 durability and H20 decay

The same field-return, participation, and directional-persistence quantities
are calculated at H10. H10 is a required durability check. H20 is reported
only as a decay diagnostic and cannot rescue or veto an otherwise clear H5/H10
result.

### Secondary external targets

- `spy_return_h5 = log(SPY open_t+6 / SPY open_t+1)`.
- `spy_return_h10 = log(SPY open_t+11 / SPY open_t+1)`.

Signals are known after close `t`; external targets begin at the next open.
SPY is a transport check, not the final operating asset.

## Frozen Contrasts and Inference

1. **Fast direction:** `BROAD_UP_IMPULSE` minus `BROAD_DOWN_IMPULSE`.
2. **Positive impulse health:** `BROAD_UP_IMPULSE` minus `OTHER_UP`.

All daily rows provide effect sizes. Five H5 offsets and ten H10 offsets
provide horizon-spaced views. Temporal halves, calendar years, and 200
deterministic within-year circular rotations of the state labels are reported.

## Frozen Gates

All ten gates must pass for
`DIAGNOSTIC_COMPLETE_STOP_BEFORE_CONFIRMATION_ATR_JOIN_OR_STRATEGY`:

1. **Integrity:** complete 25/25 requested-window coverage; every field row has
   24 inputs; equal four-group aggregation; causal next-open targets; no 2024+.
2. **H5 direction semantics:** both broad impulse states have at least 75 daily
   rows; broad-up minus broad-down future-field return is at least +0.50
   percentage points and future participation at least +10 points.
3. **H5 positive-impulse semantics:** broad-up impulse and other-up each have at
   least 75 rows; broad-up return is at least +0.20 points higher,
   participation at least +5 points higher, and future-negative rate at least
   5 points lower.
4. **Continuous ordering:** Spearman `D5` versus future H5 field return is at
   least 0.10; `P5` versus future H5 field return at least 0.10; `I5` versus
   future H5 participation change at least 0.10; and alignment versus H5
   directional persistence is positive.
5. **H5 offset stability:** all five offsets contain at least ten observations
   in both broad impulse states and at least four of five have positive field-
   return and participation gaps.
6. **H10 durability:** broad-up minus broad-down H10 field return is at least
   +0.50 points, participation at least +5 points, and at least seven of ten
   H10 offsets have both gaps positive.
7. **Temporal transport:** H5 direction and positive-impulse return and
   participation gaps are positive in both temporal halves.
8. **Calendar stability:** H5 direction return and participation gaps are both
   positive in at least five of six years; positive-impulse gaps are both
   positive in at least four.
9. **Circular timing control:** actual H5 direction return and participation
   gaps are at or above the 90th percentiles; positive-impulse gaps are at or
   above the 80th percentiles.
10. **Secondary SPY H5 direction:** broad-up minus broad-down SPY H5 return is
    at least +0.30 points; `D5`/SPY-return Spearman is at least 0.10; SPY-UP AUC
    is at least 0.55; and the SPY return gap is positive in both halves.

If any gate fails, record
`STOP_FAST_TREND_IMPULSE_GATES_FAILED_NO_CONFIRMATION_ATR_JOIN_OR_STRATEGY`.

## Required Artifacts

- frozen contract, registry, run specification, coverage, health, and integrity;
- causal daily field ledger and state/context summaries;
- H5/H10 continuous, offset, temporal, calendar, and circular evidence;
- H20 decay readout;
- focused field, onset, ordering, transport, and SPY visuals;
- concise evidence deck with speaker-note references;
- progress-log and dialogue-index updates;
- explicit stop before confirmation, ATR joining, or strategy work.
