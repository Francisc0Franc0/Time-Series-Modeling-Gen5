# Gen5 T1 Multi-Asset Trend Persistence POC Contract

Status: `IMPLEMENTED_STOP_T1_TREND_PERSISTENCE`

## Purpose

T1 is the first implemented slice from the mechanism-first retail quant
detour. It asks whether one simple, low-turnover trend measurement has
useful conditional exposure quality across genuinely different liquid markets.

This is not a technical-indicator contest. The economic prior is that
information diffusion, institutional repositioning, hedging demand, and
behavioral underreaction can create medium-horizon persistence.

The operator accepted and froze this contract before implementation. The POC
was then run without changing its universe, signal, timing, controls, costs,
windows, or gates. It creates research evidence only and no live advice or
order authority.

## Frozen research question

At a scheduled month-end decision, does a liquid asset whose trailing
12-month adjusted total return exceeds the return of an executable Treasury
bill proxy subsequently produce better next-month excess return than when its
trend is non-positive?

At portfolio level, does allocating fixed sleeves to trend-positive assets and
otherwise to the Treasury bill proxy improve risk-adjusted compounding versus:

1. static equal weight across the identical risk assets; and
2. an exposure-matched equal-weight control?

## Economic mechanism

T1 is allowed to succeed for a mixture of:

- gradual information incorporation;
- slow institutional rebalancing;
- persistence in macroeconomic and policy shocks;
- behavioral anchoring and underreaction;
- compensation for bearing trends that can reverse sharply.

T1 is not interpreted as proof that a moving average or return lookback
“predicts” intrinsic value.

## Frozen universe

### Risk assets

| Sleeve | Symbol | Economic role |
|---:|---|---|
| 1 | `SPY` | US large-cap equity |
| 2 | `IWM` | US small-cap equity |
| 3 | `EFA` | Developed ex-US equity |
| 4 | `EEM` | Emerging-market equity |
| 5 | `TLT` | Long-duration US Treasury |
| 6 | `IEF` | Intermediate US Treasury |
| 7 | `LQD` | Investment-grade corporate credit |
| 8 | `HYG` | High-yield corporate credit |
| 9 | `GLD` | Gold |
| 10 | `SLV` | Silver |
| 11 | `DBC` | Broad commodity futures exposure |
| 12 | `UUP` | US dollar exposure |
| 13 | `VNQ` | US real estate equity |
| 14 | `XLE` | Energy equity |

### Cash proxy

- `BIL`: executable short-Treasury ETF proxy.

The fixed list avoids selecting winners after seeing T1 outcomes. Every
instrument must have adequate adjusted history before its first eligible
decision. Missing or incomplete symbols cannot be silently replaced.

## Data authority

- Provider: Alpaca.
- Canonical bars: adjusted daily OHLCV.
- Research feed: the repository's accepted SIP-adjusted daily path.
- Every query carries an explicit `as_of_timestamp`.
- Market sessions come from the existing explicit calendar authority.
- No module may infer the latest session independently.
- Month-end means the final completed regular market session of the calendar
  month under the explicit as-of boundary.

No intraday, news, options, fundamentals, alternative data, or new provider is
needed for T1.

## Frozen signal

At month-end decision `t`, for risk asset `i`:

```text
asset_trend_12m(i,t)
  = log(adjusted_close(i,t) / adjusted_close(i,t-12 month-ends))

cash_trend_12m(t)
  = log(adjusted_close(BIL,t) / adjusted_close(BIL,t-12 month-ends))

trend_excess_12m(i,t)
  = asset_trend_12m(i,t) - cash_trend_12m(t)

signal(i,t)
  = ON  if trend_excess_12m(i,t) > 0
  = OFF otherwise
```

The primary rule contains no fitted coefficient, percentile, probability
threshold, or TRAIN-selected parameter.

## Decision and execution timing

1. Observe the final adjusted close of the completed month.
2. Compute signals after the scheduled 17:30 America/New_York decision.
3. Submit hypothetical orders no earlier than the following regular-session
   open.
4. Hold the resulting sleeves until the next scheduled month-end decision and
   following-open rebalance.

No month-end-close execution is allowed. Entry and exit accounting use the
next executable open.

## Frozen portfolio rule

- Divide capital into fourteen equal sleeves.
- If a sleeve's asset signal is `ON`, allocate that sleeve to the asset.
- If its signal is `OFF`, allocate that sleeve to `BIL`.
- Rebalance monthly at the next open.
- Long-only.
- Fully funded.
- No leverage.
- No volatility scaling.
- No optimization.
- No cross-asset ranking.
- No discretionary override.

If every risk asset is `OFF`, the portfolio is 100% `BIL`.

## Frozen controls

### Primary passive benchmark

Monthly rebalanced equal weight across the same fourteen risk assets.

### Cash / no-risk benchmark

100% `BIL`.

### Exposure-matched control

At each T1 rebalance:

- observe T1's fraction of sleeves that are `ON`;
- invest that same fraction equally across all fourteen risk assets;
- invest the remainder in `BIL`.

This control uses no asset-specific trend selection. It distinguishes the value
of trend-conditioned asset choice from the simpler effect of carrying less
risky exposure.

## Cost model

- Primary one-way implementation cost: `5 bp` of notional traded.
- Stress cost: `10 bp` one way.
- Apply cost to every rebalance trade, including switches into or out of `BIL`.
- No commission rebate or favorable price improvement.
- No tax claim.

T1 is low turnover by construction, but zero-cost results are not sufficient.

## Historical evidence boundary

The available Alpaca equity/ETF history begins in 2016. T1 therefore uses:

- lookback establishment: 2016 calendar year;
- retrospective development: 2017-01 through 2021-12 decisions;
- retrospective confirmation: 2022-01 through 2024-12 decisions;
- later historical shadow: 2025-01 through the last completed month before
  contract freeze.

The later historical shadow is not called prospective evidence because the
operator is familiar with the broad market history.

True prospective shadow authority begins with the first scheduled month-end
decision after this contract is approved and frozen.

## Measurement layer

Before portfolio interpretation, report:

- pooled next-month asset-minus-BIL return for `ON` and `OFF` observations;
- `ON minus OFF` separation by asset and calendar year;
- fraction of assets and years with positive separation;
- count of eligible decisions and missing observations;
- distribution of the number of `ON` sleeves each month.

This tests the trend mechanism directly rather than relying only on one
portfolio equity curve.

## Portfolio layer

For T1 and all three controls, report:

- cumulative net return;
- annualized compound return;
- annualized volatility;
- maximum drawdown;
- return divided by absolute maximum drawdown;
- monthly turnover;
- risky-asset exposure;
- calendar-year return;
- asset contribution to T1-minus-control return.

These are research metrics only. No result changes live behavior.

## Frozen pass gates

T1 records `PASS_T1_TO_PROSPECTIVE_SHADOW` only if all of the following hold:

1. Every timing, coverage, explicit-as-of, adjusted-bar, and next-open
   integrity gate passes.
2. Pooled `ON minus OFF` next-month excess return is positive in retrospective
   confirmation.
3. At least `8 / 14` risk assets have positive full-history `ON minus OFF`
   separation.
4. Net T1 annualized return exceeds the exposure-matched control in
   retrospective confirmation under the primary `5 bp` cost.
5. T1 maximum drawdown is at least `10%` smaller in relative terms than the
   static equal-weight benchmark in retrospective confirmation.
6. T1 annualized return is no more than `2 percentage points` below static
   equal weight in retrospective confirmation.
7. No one risk asset contributes more than `35%` of T1's cumulative net
   advantage over the exposure-matched control.
8. The central conclusions survive the `10 bp` one-way cost stress.
9. Fixed `9-month` and `15-month` lookback diagnostics do not both reverse the
   primary 12-month conclusion. They are diagnostics only and cannot replace
   the primary rule.

If any required gate fails, record:

```text
STOP_T1_TREND_PERSISTENCE
```

Do not rescue a STOP by selecting another lookback, deleting an asset, changing
the cash proxy, adding volatility scaling, or redefining the evaluation window
after inspecting results.

## Human-facing artifacts

The completed POC produced:

- signal-support and ON/OFF separation charts;
- monthly risky-exposure tape;
- T1 and benchmark equity/drawdown panels;
- asset-contribution chart;
- representative month-end decision tapes;
- gate summary;
- concise report and updated slide deck.

## Frozen implementation readout

The accepted contract was implemented and run under explicit
`as_of_timestamp = 2026-07-27 17:30:00`.

- All `15 / 15` required symbols matched the complete `SPY` reference-session
  calendar from `2016-01-04` through `2026-07-01`: `2,638` sessions each,
  with zero missing or extra sessions.
- All `10 / 10` integrity and leakage checks passed.
- Confirmation pooled `ON minus OFF` next-month asset-minus-BIL return was
  `-29.71 bp`.
- Only `5 / 14` risk assets had positive full-history separation.
- At `5 bp` one way, confirmation T1 CAGR was `3.29%` with `-3.51%`
  maximum drawdown. The exposure-matched control CAGR was `3.88%`; static
  equal-weight CAGR was `4.55%` with `-12.79%` maximum drawdown.
- T1 reduced maximum drawdown by `72.5%` relative to static equal weight, but
  trailed the exposure-matched control by `0.59 percentage points` of CAGR.
- `5 / 9` frozen gates passed.

The decision is:

```text
STOP_T1_TREND_PERSISTENCE
```

The result is a valid falsification of the frozen persistence mechanism. It
also demonstrates useful exposure reduction, but the exposure-matched control
shows that this defense is not evidence of asset-specific trend-selection
alpha.

Key evidence:

- `runs/research_workbench/retail_quant_mechanisms/t1_multi_asset_trend_20260727/t1_report.md`
- `runs/research_workbench/retail_quant_mechanisms/t1_multi_asset_trend_20260727/t1_gate_summary.csv`
- `presentations/gen5_t1_multi_asset_trend_evidence.pptx`

## What T1 does not open

- PCA or state routing;
- machine learning;
- Markov models;
- parameter search;
- tactical leverage;
- shorting;
- options;
- intraday execution;
- live advice or automated orders;
- adoption of T1 as the Gen5 production strategy.

## Operator decision

The operator approved the fourteen risk assets, `BIL` cash proxy, 12-month
asset-minus-BIL signal, monthly next-open execution, fixed sleeves, controls,
costs, historical evidence boundary, and nine gates before the POC ran. T1 is
now closed under its frozen STOP. Any later trend experiment must be declared
as a new question rather than a rescue of this result.
