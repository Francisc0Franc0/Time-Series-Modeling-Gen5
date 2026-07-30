# LIT-MR-06.1 Causal Buy-on-Gap Intraday Reversion POC Contract

Status: `FROZEN_APPROVED_IMPLEMENTATION`

## Place in the literature-study progression

`LIT-MR-06.1` is the first Chapter 4 lane and the first deliberately intraday
literature exercise. It translates Ernest Chan's Example 4.1 into an
executable causal experiment while keeping the original same-open calculation
as a quarantined reference diagnostic.

This is a research-only exception inside `literature_studies/`. It does not
change the canonical Gen5 adjusted-daily data contract, provider boundary,
advice-only behavior, or live execution scope.

## Question

Among a fixed cross-section of liquid US stocks, do unusually negative
overnight gaps that open above a lagged 20-session moving average tend to
rebound between a realistically delayed entry and the closing print strongly
enough to survive ordinary costs and falsification controls?

## Source proposition

For stock \(i\) on session \(t\):

\[
r_{i,t}^{cc} = \frac{C_{i,t}}{C_{i,t-1}} - 1
\]

\[
\sigma_{i,t}^{90} =
  SD(r_{i,t-90}^{cc}, \ldots, r_{i,t-1}^{cc})
\]

\[
g_{i,t} = \frac{O_{i,t}}{L_{i,t-1}} - 1
\]

A stock is eligible when:

\[
g_{i,t} < -\sigma_{i,t}^{90}
\quad\text{and}\quad
O_{i,t} > MA_{20}(C_{i,t-20}, \ldots, C_{i,t-1})
\]

The source ranks eligible stocks from the most negative gap upward, buys at
most ten, allocates one tenth of capital to each selected stock, and exits at
the close. If fewer than ten qualify, unused sleeves remain cash.

Chan's source-period calculation uses the official open both to finish the
signal and as the fill. The book explicitly notes that this cannot literally
be executed after observing the official open. The source-style
open-to-close result is therefore labeled `NONCAUSAL_REFERENCE` and can never
pass a Gen5 gate.

## Primary causal translation

- Signal timestamp: `09:31:00 America/New_York`, after the 09:30-09:31 minute
  and official opening information are observable.
- Signal inputs: current-session adjusted official open and only prior-session
  adjusted daily lows, closes, and close-to-close returns.
- Entry proxy: adjusted 1-minute bar open stamped `09:32:00
  America/New_York`. This deliberately leaves a full minute between the
  signal timestamp and the historical fill proxy.
- Exit instruction: a closing-auction order is assumed to be committed after
  entry and before the broker cutoff.
- Exit fill proxy: the adjusted daily close. It is a practical historical
  closing-print proxy, not a claim of exact closing-auction queue priority.
- Primary round-trip cost: `10 bp`.
- Stress round-trip cost: `20 bp`.
- Position sizing: each selected stock receives `10%` of starting-day
  capital. Unused sleeves remain cash; capital is reset daily for the
  additive textbook POC.
- Direction: long only. A short mirror would be a new substantive variant,
  not a reactive rescue.

The primary return for a selected stock is:

\[
R_{i,t}^{primary}
  = \frac{C_{i,t}}{O_{i,t}^{09:32}} - 1 - 0.001
\]

The daily portfolio return is:

\[
R_t^{portfolio}
  = \frac{1}{10}\sum_{i \in S_t} R_{i,t}^{primary}
\]

where \(S_t\) contains at most ten stocks. The `1/10` denominator is fixed even
when fewer than ten qualify.

## Frozen windows and audit boundary

- Explicit as-of timestamp: `2026-07-24 17:30:00 America/New_York`.
- Daily warm-up query begins: `2018-08-01`.
- TRAIN: `2019-01-02` through `2020-12-31`.
- DEVELOPMENT: `2021-01-04` through `2023-12-29`.
- CONFIRMATION: `2024-01-02` onward remains sealed.

DEVELOPMENT may be queried only for an atlas instance that passes every frozen
TRAIN gate. The canonical instance receives no exception.

## Frozen atlas

The source used S&P 500 constituents. Point-in-time constituent histories are
not locally available for this minimal exercise, so the atlas uses ten
predeclared static survivor panels of liquid, long-history stocks. These are
pedagogical cross-sections, not historical index reconstructions.

| Order | Instance | Category | Benchmark | Frozen symbols |
|---:|---|---|---|---|
| 601 | `G01_BROAD_US` | Broad large-cap control | `SPY` | `AAPL,MSFT,AMZN,GOOGL,META,NVDA,JPM,JNJ,XOM,PG,HD,CVX,ABBV,BAC,KO,PEP,CAT,WMT,MRK,MCD` |
| 602 | `G02_TECHNOLOGY` | Technology | `XLK` | `AAPL,MSFT,NVDA,AVGO,ORCL,CRM,AMD,ADI,TXN,QCOM,CSCO,IBM,AMAT,MU,INTU` |
| 603 | `G03_FINANCIALS` | Financials | `XLF` | `JPM,BAC,WFC,C,GS,MS,BLK,AXP,USB,PNC,BK,STT,SCHW,CME,ICE` |
| 604 | `G04_ENERGY` | Energy | `XLE` | `XOM,CVX,COP,EOG,SLB,OXY,MPC,VLO,PSX,HES,HAL,BKR,KMI,WMB,DVN` |
| 605 | `G05_HEALTH_CARE` | Health care | `XLV` | `JNJ,LLY,MRK,ABBV,PFE,AMGN,GILD,BMY,UNH,CVS,CI,HUM,MDT,TMO,DHR` |
| 606 | `G06_CONSUMER_STAPLES` | Consumer staples | `XLP` | `PG,KO,PEP,WMT,COST,PM,MO,MDLZ,CL,KMB,GIS,SYY,KR,HSY,KHC` |
| 607 | `G07_INDUSTRIALS` | Industrials | `XLI` | `CAT,DE,GE,HON,UPS,UNP,RTX,LMT,NOC,ETN,EMR,ITW,PH,MMM,CMI` |
| 608 | `G08_DISCRETIONARY` | Consumer discretionary | `XLY` | `AMZN,HD,MCD,NKE,SBUX,LOW,TJX,BKNG,ORLY,AZO,ROST,DRI,TGT,GM,F` |
| 609 | `G09_COMMUNICATION` | Communication services | `XLC` | `GOOGL,META,NFLX,DIS,CMCSA,T,VZ,TMUS,CHTR,EA,TTWO,OMC,IPG,FOX,FOXA` |
| 610 | `G10_UTILITIES` | Utilities | `XLU` | `NEE,SO,DUK,AEP,SRE,D,EXC,XEL,ED,WEC,PEG,AWK,ETR,ES,PPL` |

The atlas tests sector breadth, not ten statistically independent
hypotheses. Every result is published. No panel may be hidden, substituted,
or redefined after outcomes.

## Fixed diagnostics and controls

Each instance reports:

- source-style noncausal open-to-close return;
- causal 09:32-to-close gross, primary-cost, and stress-cost returns;
- selected-stock hit rate and up/down accuracy;
- daily P&L, annualized naive Sharpe, autocorrelation-adjusted Sharpe, and
  maximum drawdown;
- event counts, portfolio-day counts, average invested sleeves, and symbol
  contribution concentration;
- same-window benchmark return from 09:32 to close;
- a seeded random-stock control that selects the same number of stocks from
  the lagged-MA-qualified panel without using the gap threshold or ranking;
- a no-MA ablation that retains the negative-gap threshold; and
- block-bootstrap intervals over portfolio days.

The moving-average ablation is diagnostic. It is not a hidden alternative and
cannot replace the frozen rule if it looks better.

## Eight TRAIN gates

| Gate | Requirement | Role |
|---:|---|---|
| 1 | All integrity and timing checks pass; no current close/low enters the signal; all entry timestamps are strictly after `09:31`. | Firm structural |
| 2 | At least `95%` of selected candidate-days have a valid 09:32 entry and close proxy. | Firm structural |
| 3 | At least `60` completed stock-events across at least `30` portfolio days. | Firm support |
| 4 | Mean primary-cost stock-event return is positive. | Performance |
| 5 | One-sided 90% block-bootstrap lower bound for mean primary-cost portfolio-day return is above zero. | Uncertainty |
| 6 | Mean primary-cost portfolio-day excess return over the matched benchmark sleeves is positive. | Opportunity-cost |
| 7 | Observed mean primary-cost portfolio-day return exceeds the 90th percentile of the seeded random-stock control. | Falsification |
| 8 | Stress-cost cumulative return is positive and no one symbol supplies more than `50%` of positive gross P&L. | Friction/concentration |

An instance passes only by conjunction. No weighted score, near-pass rescue,
or cross-panel winner selection is allowed.

## Interpretation boundary

- Static current survivors create material survivorship and membership bias.
- The panels omit delisted securities and historical additions/deletions.
- Daily adjusted and intraday adjusted data must agree around corporate
  actions; mismatched rows fail integrity rather than being silently repaired.
- The 09:32 bar open and daily close are fill proxies, not guaranteed
  executable prices.
- Results establish only whether the simple textbook mechanism is observable
  in these fixed pedagogical panels.
- A deployable claim would require point-in-time membership, delisted-stock
  coverage, quote-aware fills, closing-auction validation, capacity analysis,
  and a separately approved live design.

## STOP rules

Stop without DEVELOPMENT for every instance that misses any TRAIN gate.
Do not rescue a miss by changing the gap multiple, 90/20-session windows,
top-ten rule, entry minute, costs, panel membership, random seed, or gates.

Do not open the short mirror, swing adaptation, another provider, production
order path, or live behavior from this contract.
