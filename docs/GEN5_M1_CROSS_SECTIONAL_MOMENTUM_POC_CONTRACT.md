# Gen5 M1 Cross-Sectional Momentum POC Contract

Status: `IMPLEMENTED_STOP_M1_RANKING_MECHANISM`

## Implementation readout

The operator approved this contract exactly as frozen. M1 was implemented and
run with Alpaca SIP adjusted daily bars under explicit as-of
`2026-07-27 17:30:00`.

- All 24 ranked ETFs plus `BIL` shared the same `2,638` reference sessions
  from `2016-01-04` through `2026-07-01`.
- All `11 / 11` integrity and timing checks passed.
- Confirmation mean rank IC was `0.029382`, but only `19 / 36` months were
  positive versus the required `21 / 36`.
- Mean top-minus-bottom return was `22.10 bp` per month, but only `6 / 12`
  complete quarters were positive versus the required `7 / 12`.
- Observed top-K excess was `26.84 bp` per month versus the frozen random-policy
  p90 of `33.74 bp`.
- Emerging-country ETFs supplied `92.3%` of positive spread contribution
  versus the `50%` group cap; the largest ETF supplied `25.4%` versus the
  `25%` cap.
- The 6-minus-1 diagnostic reversed while 18-minus-1 supported the primary, so
  the two diagnostic horizons did not both reverse.

Only `2 / 6` M1A gates passed. Record:

```text
STOP_M1_RANKING_MECHANISM
```

M1B was structurally not run. No M1 portfolio CAGR, drawdown, turnover,
portfolio P&L, allocation, or live behavior was computed or interpreted.
Preserve the result as falsification evidence; do not rescue M1 by retuning
the universe, horizon, quartile, group neutralization, or confirmation window.

Primary packet:
`runs/research_workbench/retail_quant_mechanisms/m1_cross_sectional_momentum_20260727`.

Evidence deck:
`presentations/gen5_m1_cross_sectional_momentum_evidence.pptx`.

## Purpose

M1 is the proposed second implementation slice from the mechanism-first retail
quant detour. T1 tested whether each asset's own trend relative to cash
contained useful conditional exposure information. M1 asks a different
question: whether relative winners in a contemporaneous equity-ETF opportunity
set continue to outperform relative losers and the eligible panel average.

M1 is a ranking experiment, not a market-timing rule. A passing M1 result would
not show when the portfolio should move to cash, and it would not rescue the
stopped T1 mechanism.

This contract converts the operator-approved M1 direction into exact proposed
universe, eligibility, timing, measurement, portfolio, control, cost, and STOP
rules. No M1 data pull, outcome calculation, random-control simulation,
portfolio replay, live advice, or order behavior is authorized until the
operator accepts this exact contract.

## Frozen research questions

### M1A — ranking mechanism

At a completed month-end decision, do equity ETFs with stronger trailing
12-minus-1-month adjusted returns subsequently produce higher next-month
returns than weaker ETFs in the same point-in-time eligible panel?

### M1B — retail portfolio implementation

Only if M1A passes, does a monthly, fully invested, equal-weight top-quartile
portfolio outperform equal weight across the identical eligible panel after
realistic costs without unacceptable concentration or drawdown deterioration?

M1B remains mechanically closed if any required M1A gate fails.

## Economic mechanism

M1 is allowed to succeed because of:

- gradual information incorporation;
- investor underreaction and anchoring;
- slow institutional capital reallocation;
- benchmark and mandate constraints;
- persistence in sector, country, macroeconomic, and policy leadership.

M1 is not interpreted as proof that recent winners have higher intrinsic
value. It can experience sharp reversals when crowded leadership unwinds or
market direction changes rapidly.

## Why the initial universe is equity-only

Ranking raw returns across equities, bonds, commodities, and currencies can
become a disguised volatility or asset-class risk-premium comparison. M1
therefore begins with liquid equity ETFs whose returns are more economically
comparable.

This does not eliminate overlap or common equity beta. Broad eligibility,
group attribution, randomized top-K controls, and concentration gates are
required to show whether the result is more than one dominant region or
industry.

## Proposed fixed universe

Every proposed ETF began trading before the 2016 history boundary. The
identities are fixed before M1 outcomes are inspected.

### United States sectors — 9

| Group | Symbol | Exposure |
|---|---|---|
| US sector | `XLB` | Materials |
| US sector | `XLE` | Energy |
| US sector | `XLF` | Financials |
| US sector | `XLI` | Industrials |
| US sector | `XLK` | Technology |
| US sector | `XLP` | Consumer staples |
| US sector | `XLU` | Utilities |
| US sector | `XLV` | Health care |
| US sector | `XLY` | Consumer discretionary |

### Developed-country equities — 7

| Group | Symbol | Exposure |
|---|---|---|
| Developed country | `EWA` | Australia |
| Developed country | `EWC` | Canada |
| Developed country | `EWG` | Germany |
| Developed country | `EWH` | Hong Kong |
| Developed country | `EWJ` | Japan |
| Developed country | `EWL` | Switzerland |
| Developed country | `EWU` | United Kingdom |

### Emerging-country equities — 8

| Group | Symbol | Exposure |
|---|---|---|
| Emerging country | `EIDO` | Indonesia |
| Emerging country | `EWT` | Taiwan |
| Emerging country | `EWY` | South Korea |
| Emerging country | `EWZ` | Brazil |
| Emerging country | `EWW` | Mexico |
| Emerging country | `EZA` | South Africa |
| Emerging country | `FXI` | China large-cap |
| Emerging country | `INDA` | India |

`BIL` is the no-risk comparator only. It is not ranked and does not replace an
ineligible risk ETF inside the top quartile.

### Survivor limitation

This is a fixed panel of ETFs known to exist today and selected for long
history. It cannot support a claim that the same funds would have been found
from the full ETF market at each historical date. M1 may claim only that the
frozen long-lived panel exhibits or fails to exhibit the tested mechanism.

If a proposed symbol lacks adequate Alpaca history or fails authority checks,
record a pre-outcome coverage STOP. Do not substitute a more convenient ETF.

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
needed for M1.

## Point-in-time eligibility

At month-end decision `t`, an ETF is eligible only if all conditions hold:

1. It is one of the 24 fixed symbols.
2. It has at least 13 completed month-end observations through `t`.
3. It has an adjusted close for the completed decision session.
4. It has at least 60 observed bars across the preceding 63 reference
   sessions, including the decision session.
5. Its decision-session adjusted close is at least `$5`.
6. Its median adjusted dollar volume across those observed trailing sessions
   is at least `$5 million`, where adjusted dollar volume is adjusted close
   multiplied by adjusted volume.
7. The required `t-12` and `t-1` completed month-end adjusted closes exist.

No backward fill, forward fill, interpolation, or cross-symbol imputation is
allowed.

A month is admissible only if:

- at least `18 / 24` ETFs are eligible;
- at least `6 / 9` US-sector ETFs are eligible;
- at least `5 / 7` developed-country ETFs are eligible; and
- at least `6 / 8` emerging-country ETFs are eligible.

If monthly breadth fails, produce no rank, outcome, or portfolio decision for
that month. Do not lower the requirement after inspecting results.

## Frozen signal

At completed month-end `t`, for eligible ETF `i`:

```text
momentum_12_1(i,t)
  = log(adjusted_close(i,t-1 month) /
        adjusted_close(i,t-12 months))
```

The most recent completed month is deliberately excluded. The primary signal
contains no fitted coefficient, volatility adjustment, percentile threshold
selected from TRAIN, or outcome-informed parameter.

### Rank construction

- Rank `momentum_12_1` descending within the eligible panel.
- Highest momentum receives rank 1.
- Rank correlation uses average ranks for exact signal ties.
- Portfolio membership uses descending momentum with symbol ascending as the
  deterministic tie-break.
- `K(t) = ceiling(eligible_count(t) / 4)`.
- The top basket is the first `K(t)` symbols.
- The bottom basket is the last `K(t)` symbols.

Ranks are relative measurements. They do not make returns normally
distributed or guarantee that the relationship is stationary.

## Decision, execution, and outcome timing

1. Observe the completed month-end adjusted close and eligibility data.
2. Compute eligibility, the 12-minus-1 signal, and ranks after the scheduled
   17:30 America/New_York decision.
3. Enter hypothetical positions no earlier than the following regular-session
   open.
4. Exit or rebalance at the regular-session open following the next completed
   month-end decision.

For asset `i`:

```text
next_month_return(i,t)
  = following_open_after_next_month_end(i) /
    following_open_after_t(i) - 1
```

The same open-to-open interval applies to every eligible ETF, basket, and
control. No month-end-close execution is allowed.

## Historical evidence boundary

M1 uses:

- lookback establishment: 2016 calendar year;
- retrospective development: 2017-01 through 2021-12 decisions;
- retrospective confirmation: 2022-01 through 2024-12 decisions;
- later historical shadow: 2025-01 through the last completed month before
  contract freeze.

These are honest retrospective labels. Broad market history is already known
to the operator. True prospective shadow authority begins with the first
scheduled month-end after this exact contract is accepted and frozen.

No development result may change the universe, eligibility, primary lookback,
portfolio mapping, controls, costs, or gates.

## M1A measurement layer

For each admissible month, report:

- cross-sectional Spearman correlation between `momentum_12_1` and
  `next_month_return`;
- top-quartile minus bottom-quartile mean next-month return;
- top-quartile minus eligible-panel equal-weight return;
- counts by month, quarter, year, ETF, and economic group;
- top and bottom membership turnover;
- asset, group, month, quarter, and year contribution to the measured spread;
- representative ranking tapes showing signal ranks, eligibility, next-open
  entry, and next-open outcome.

Inference and stability are based on monthly and quarterly cross-sections, not
on treating all asset-month rows as independent observations.

## Frozen randomized top-K control

Use `2,000` deterministic random policies with seed `5401`.

For each admissible month and each policy:

1. select `K(t)` eligible ETFs without replacement;
2. compute their equal-weight next-month return;
3. subtract the eligible-panel equal-weight return over the same interval;
4. pool the policy's monthly excess across retrospective confirmation.

The observed top-basket mean excess is compared with the empirical
distribution of the `2,000` random-policy means.

Random selection controls for the mechanical consequences of holding a
concentrated K-name basket. It does not create an alternative economic theory.

## M1A frozen gates

M1A passes only if all six gates hold in retrospective confirmation:

1. Every explicit-as-of, adjusted-bar, eligibility, common-interval,
   next-open, and no-outcome-in-signal integrity check passes.
2. Mean monthly Spearman rank correlation is positive and at least `21 / 36`
   confirmation months have positive rank correlation.
3. Mean top-minus-bottom return is positive and at least `7 / 12`
   confirmation quarters have positive top-minus-bottom return.
4. Observed mean top-minus-eligible-equal-weight return exceeds the empirical
   `90th percentile` of the `2,000` seeded random-policy means.
5. No economic group supplies more than `50%`, no ETF more than `25%`, and no
   calendar year more than `50%` of total positive top-minus-bottom arithmetic
   contribution.
6. Fixed `6-minus-1` and `18-minus-1` diagnostics do not both reverse the
   primary conclusion. A diagnostic supports M1 only when both its
   confirmation mean rank correlation and mean top-minus-bottom return are
   positive.

If any M1A gate fails, record:

```text
STOP_M1_RANKING_MECHANISM
```

Do not compute or interpret the M1B portfolio replay.

## M1B frozen portfolio rule

M1B opens only after M1A passes.

- Invest `100%` equally across the top `K(t)` eligible ETFs.
- Rebalance monthly at the following open.
- Long-only.
- Fully funded.
- No cash remainder inside M1.
- No leverage.
- No volatility scaling.
- No hold zone.
- No rank smoothing.
- No discretionary override.

Full investment keeps M1 focused on relative selection rather than aggregate
exposure timing.

## Frozen M1B controls

### Primary passive benchmark

Monthly equal weight across every point-in-time eligible ETF.

### No-risk comparator

`100% BIL`.

### Bottom basket

Equal weight across the bottom `K(t)` ETFs. This is a measurement comparator,
not an authorized short portfolio.

### Random K-name policies

The same frozen `2,000` random policies used in M1A.

No exposure-matched control is required because M1 and eligible-panel equal
weight are both fully invested in risk ETFs.

## Cost model

- Primary one-way cost: `5 bp` of notional traded.
- Stress one-way cost: `10 bp`.
- Apply cost to every rebalance trade.
- Initial deployment is charged.
- No commission rebate, favorable price improvement, tax claim, or fractional
  execution advantage.
- Monthly one-way turnover is one half of the absolute portfolio-weight
  change, including initial deployment.

## M1B reporting

For M1 and all portfolio controls, report:

- cumulative net return;
- annualized compound return;
- annualized volatility;
- maximum drawdown;
- return divided by absolute maximum drawdown;
- calendar-year return;
- monthly turnover;
- ETF and group contribution;
- worst month and worst quarter;
- representative rebalance tapes.

These are research metrics only and cannot change live behavior.

## M1B frozen gates

If M1A passes, M1B passes only if all four gates hold:

7. Net M1 annualized compound return exceeds eligible-panel equal weight in
   retrospective confirmation at `5 bp` one way.
8. Net M1 annualized compound return still exceeds eligible-panel equal weight
   under the `10 bp` one-way stress.
9. Median monthly one-way turnover is no greater than `50%`.
10. M1 maximum drawdown is no more than `5 percentage points` worse than
    eligible-panel equal weight in retrospective confirmation.

If M1A passes but any M1B gate fails, record:

```text
STOP_M1_PORTFOLIO_IMPLEMENTATION
```

If all ten gates pass, record:

```text
PASS_M1_TO_PROSPECTIVE_SHADOW
```

Passing does not authorize production use. It opens only a separately governed
prospective shadow.

## Falsification discipline

Do not rescue a STOP by:

- replacing or deleting ETFs after inspecting outcomes;
- switching from 12-minus-1 to a favorable formation horizon;
- changing the quartile or minimum breadth;
- adding volatility scaling, trend filters, or cash timing;
- adding a hold zone or turnover optimizer;
- weakening the randomized-control percentile;
- redefining the confirmation window;
- promoting a group-neutral or risk-adjusted challenger after seeing the
  primary result.

Any future challenger requires a new economic rationale, new contract, and
fresh evidence boundary.

## Human-facing artifacts

The eventual POC should produce:

- universe and eligibility coverage chart;
- monthly rank-IC and top-minus-bottom panels;
- random-policy null-distribution chart;
- ETF, group, and year contribution charts;
- top/bottom membership and turnover tape;
- representative ranking and rebalance tapes;
- M1A gate summary;
- M1B equity/drawdown and gate summary only if M1A passes;
- concise report and updated slide deck.

## What M1 does not open

- T1 redesign;
- exposure timing or cash permission;
- machine learning;
- PCA or state routing;
- Markov models;
- volatility scaling;
- shorting;
- leverage;
- options;
- intraday execution;
- live advice or automated orders;
- adoption of momentum as the Gen5 production strategy.

## Exact operator approval requested

Approve or revise:

- the 24 fixed equity ETFs and three economic groups;
- point-in-time eligibility and monthly breadth requirements;
- the 12-minus-1 rank and top/bottom quartiles;
- monthly next-open execution and next-open outcomes;
- the M1A-first hard STOP before portfolio replay;
- the `2,000` seeded random top-K control;
- the six M1A gates;
- the fully invested M1B portfolio and controls;
- `5 bp` primary and `10 bp` stress costs;
- the four M1B gates;
- the retrospective and prospective evidence boundaries.
