# LIT-MOM-01.1 Interday Time-Series Momentum POC Contract

Status: `OOS_DEVELOPMENT_COMPLETE_STOP_RECOMMENDED`

## Place in the literature-study progression

`LIT-MOM-01.1` opens the first momentum family in Literature-Grounded
Strategy Research. It is a textbook exercise derived from Ernest P. Chan's
Chapter 6 and Example 6.1, not a continuation of the organically developed
Gen5 momentum lanes.

The visible objective is a causal daily swing strategy whose signal, position
path, trade sleeves, bar-by-bar P&L, and uncertainty can all be inspected.
It does not change live advice, execution, leverage, or provider scope.

## Source workflow

Chan does not choose 250/25 without an upstream test. For each lookback \(L\)
and holding period \(H\), he first estimates:

\[
R_t^{past}(L)=C_t/C_{t-L}-1
\]

\[
R_t^{future}(H)=C_{t+H}/C_t-1
\]

and compares their correlation and nominal Pearson p-value over:

\[
L,H \in \{1,5,10,25,60,120,250\}.
\]

His `TU` table identifies several correlation/p-value compromises. He chooses
250/25 for Example 6.1: a 12-month sign held for about one month, consistent
with the time-series-momentum paper cited in the chapter and with his
preference for a reasonably short holding period. The choice is informed,
but it is not the unique mathematical optimum of the table.

## Example 6.1 rule

For adjusted close \(C_t\), Chan defines a 250-session time-series momentum
signal:

\[
s_t =
\begin{cases}
+1 & C_t > C_{t-250}\\
-1 & C_t < C_{t-250}\\
0 & C_t = C_{t-250}
\end{cases}
\]

Each day starts one sleeve worth \(1/25\) of capital and holds it for 25
sessions. The aggregate target exposure is therefore:

\[
w_t = \frac{1}{25}\sum_{h=1}^{25}s_{t-h}
\]

so exposure moves gradually from fully short to fully long rather than
flipping the whole account on one observation.

Chan applies that selected rule to the two-year Treasury-note future `TU`,
reports a
June 1, 2004-May 11, 2012 in-sample Sharpe ratio of about 1.0, APR of 1.7% on
notional capital, and maximum drawdown of 2.5%, and emphasizes that futures
leverage changes the capital interpretation.

## What “nonoverlapping” means here

With \(L=250\) and \(H=25\), testing every day would reuse most of the same
future observations in adjacent outcomes. That makes the nominal sample size
look much larger than the independent information content.

Chan's prose and Figure 6.1 advance the anchor by the shorter interval,
`min(L,H)`. For 250/25 this means one anchor every 25 sessions: future-return
windows do not overlap, while the 250-session predictor windows still do.
The printed MATLAB condition advances by `max(L,H)`, which conflicts with the
prose, figure, and the reported sample-size/p-value behavior. Neither scheme
makes every raw return interval across adjacent pairs independent.

The POC therefore reports three clearly labeled views:

1. `CHAN_MIN_STEP`: every 25 sessions; source-faithful primary mechanism
   diagnostic with nonoverlapping future outcomes.
2. `STRICT_FULL_PAIR_STEP`: every 275 sessions; no raw price interval is
   reused between adjacent past/future pairs, but the sample is too small for
   strong inference.
3. `DAILY_OVERLAPPING`: every eligible session; descriptive only and never
   used as independent-sample evidence.

The ordinary Pearson p-value for `CHAN_MIN_STEP` is reported only as the
book-style statistic. Because predictor windows overlap, it is not treated as
literal posterior evidence or as a frozen gate. A seeded moving-block
bootstrap interval and the strict-spacing sensitivity are reported beside it.

## Retail translation and instrument boundary

The canonical Gen5 provider does not supply futures. The single frozen
instrument is:

- `SHY`: iShares 1-3 Year Treasury Bond ETF.

`SHY` is selected before outcomes because its maturity exposure is the nearest
liquid Alpaca-tradable ETF proxy to the source's two-year Treasury future. The
POC uses adjusted OHLCV so distributions enter the historical total-return
path.

This is not a literal `TU` replication:

- an ETF has fund expenses, distributions, and share-borrow mechanics;
- it does not reproduce a futures contract's margin or roll-return path; and
- Chan's proposed persistence-of-roll-return explanation is therefore not
claimed for `SHY`.

No alternate ETF may replace `SHY` after outcomes. A multi-asset atlas or a
true futures reproduction would be a separately frozen replication batch.

## Frozen TRAIN-only horizon selection

The primary SHY POC reconstructs the upstream table before applying the
strategy:

1. Publish all 49 \(L,H\) combinations from the source grid.
2. Use Chan's `min(L,H)` anchor spacing.
3. Require at least 20 correlation pairs.
4. Retain the 1-session holding rows in the teaching table but exclude them
   from selection to preserve the operator's swing-trading boundary;
   selectable holding periods are at least 5 sessions.
5. Rank supported candidates by the largest Pearson-correlation t-statistic,
   breaking an exact tie toward the shorter holding period and then shorter
   lookback.
6. Require the selected candidate to have positive correlation and nominal
   p-value no greater than 0.10 before it can pass the horizon-screen gate.

The t-statistic balances correlation magnitude and sample count, but the 49
tests are related and the nominal p-value is not multiplicity-adjusted proof.
The complete table is published, and the conditional DEVELOPMENT replay is
the real falsification surface.

`CANON_250_25` remains a side-by-side source reference under the same causal
execution and costs. It cannot replace the TRAIN-selected SHY horizon after
outcomes.

## Causal execution

- Signal: calculated after the adjusted close of session \(t\).
- Entry: adjusted open of session \(t+1\).
- Sleeve size: `1/H` of capital, where \(H\) is selected on TRAIN.
- Sleeve exit: adjusted open \(H\) trading sessions after entry.
- Aggregate exposure: net sum of active sleeves, bounded to `[-1, +1]`.
- Evaluation windows begin flat. Signals before the evaluation start do not
  create inherited positions.
- Net turnover is `abs(target exposure - prior exposure)`; opposing sleeves
  may cross-net.
- Primary cost: `5 bp` per one-way unit of turnover.
- Stress cost: `10 bp` per one-way unit of turnover plus `100 bp` annualized
  on short gross exposure.
- No leverage beyond one-times notional.

The source-style lagged-position close-to-close curve is retained only as a
clearly labeled teaching diagnostic. It cannot override the causal
next-open result.

## Frozen windows

- Explicit as-of timestamp: `2026-07-30 17:30:00 America/New_York`.
- Query/warm-up start: `2016-01-04`.
- TRAIN: `2017-01-03` through `2020-12-31`.
- DEVELOPMENT: `2021-01-04` through `2023-12-29`.
- CONFIRMATION: `2024-01-02` onward remains sealed.

Only TRAIN bars are queried initially. DEVELOPMENT is queried once if and only
if every TRAIN gate passes. CONFIRMATION is not queried by this POC.

### Post-freeze coverage correction

The preliminary runner requested 2015 warm-up bars, but the approved Alpaca
path returned zero `SHY` and `SPY` observations before January 2016. That made
the apparent 2016 strategy year an uninvested warm-up artifact. The
preliminary packets ending in `_v2` and `_v3` are invalid and non-authoritative.

Before accepting any result, the query start was moved to the first mutually
covered session (`2016-01-04`) and TRAIN to the first session with a complete
250-session lookback (`2017-01-03`). No instrument, source grid, canonical
250/25 reference, cost, gate, seed, DEVELOPMENT date, or outcome-driven choice
changed. DEVELOPMENT remained sealed during the correction.

## Frozen TRAIN gates

| Gate | Requirement | Role |
|---:|---|---|
| 1 | All coverage, ordering, timing, and finite-price integrity checks pass. | Firm structural |
| 2 | The selected horizon has at least 20 screening pairs, positive correlation, nominal p-value no greater than 0.10, and holding period of at least 5 sessions. | Screen/admissibility |
| 3 | At least 40 `CHAN_MIN_STEP` selected-rule pairs and 40 completed selected-horizon sleeves. | Firm support |
| 4 | Past-sign versus future-sign accuracy is above 50%. | Direction |
| 5 | Primary-cost causal cumulative TRAIN return is positive and autocorrelation-adjusted Sharpe is positive. | Economic |
| 6 | Stress-cost causal cumulative TRAIN return is positive and at least three TRAIN calendar years are positive. | Friction/stability |

Passage is conjunctive. The full 49-cell table, bootstrap interval,
strict-spacing correlation, long-call precision, short-call precision,
buy-and-hold comparison, maximum drawdown, contribution concentration,
canonical 250/25 reference, and source-style curve are important diagnostics
but not hidden gates.

## Required evidence

The packet must contain:

- the complete 49-cell TRAIN horizon table and frozen selected row;
- all three correlation-sampling views for the selected rule and canonical
  250/25 reference;
- a source-style Pearson statistic plus dependence-aware caveats;
- moving-block bootstrap draws and interval;
- past/future sign confusion matrix and directional scorecard;
- one row per completed selected-horizon sleeve;
- one row per causal open-to-open portfolio bar;
- gross, primary-cost, and stress-cost equity/drawdown paths;
- calendar-year returns;
- long versus short sleeve contribution;
- buy-and-hold `SHY` context;
- exposure and signal tape; and
- a gate table with an immutable STOP or conditional OOS verdict.

## STOP and interpretation rules

If any TRAIN gate fails, stop without querying DEVELOPMENT. Do not rescue the
result by changing the instrument, grid, selection rule, minimum holding
period, selected horizon, canonical 250/25 reference, direction, costs, date
window, sampling convention, or gates.

If all gates pass, run the one frozen DEVELOPMENT replay with the same formula
and a flat start. DEVELOPMENT is OOS evidence because no parameter is selected
from its outcomes.

Historical ETF borrow availability is not proven by adjusted bars. A positive
result would remain a research exercise, not authority for live shorting,
allocation, leverage, advice, or execution.
