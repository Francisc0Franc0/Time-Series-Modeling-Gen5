# LIT-MOM-02.1 Opening-Gap Momentum Contract

Status: `FROZEN_BEFORE_OUTCOME_RETRIEVAL`

## Literature anchor

Ernest P. Chan's *Algorithmic Trading: Winning Strategies and Their
Rationale* (2013), Example 7.1, printed pages 156-157 / PDF pages 174-175,
describes a same-day momentum rule for the Dow Jones STOXX 50 futures contract
identified in the source as `FSTX`.

For session \(t\), let \(O_t,H_t,L_t,C_t\) be open, high, low, and close, and
let \(\sigma_{t-1}^{90}\) be the sample standard deviation of the 90 most
recent close-to-close returns available before session \(t\). With
\(k=0.1\):

\[
q_t =
\begin{cases}
+1, & O_t > H_{t-1}(1+k\sigma_{t-1}^{90}) \\
-1, & O_t < L_{t-1}(1-k\sigma_{t-1}^{90}) \\
0, & \text{otherwise.}
\end{cases}
\]

The narrative-consistent source return is

\[
r_t^{source}=q_t(C_t/O_t-1).
\]

The printed MATLAB return line instead evaluates
`positions.*(op-cl)./op`, the negative of the narrative-consistent return.
That sign is inconsistent with the prose, long/short labels, and rising
Figure 7.1. Gen5 preserves it only as `LITERAL_PRINTED_CODE_DIAGNOSTIC`; it is
not the implemented momentum strategy.

Chan reports 13% APR and 1.4 Sharpe from July 16, 2004 through May 17, 2012.
This is a published, selected in-sample result. The source does not supply the
continuous-contract roll construction, costs, or a point-in-time record of the
other futures tested before FSTX was called best. Gen5 therefore records the
original example as `SOURCE_REFERENCE_ONLY`, not as an exact reproduction.

## Mechanism and claim boundary

The proposed mechanism is continuation after an opening auction crosses the
previous session's extreme. Overnight information or clustered stop orders may
create a cascade in the same direction. The POC asks only whether that signed
open-to-close continuation survives realistic delayed entry and costs in the
predeclared retail panel.

It does not claim that:

- every overnight gap should continue;
- the rule is a swing strategy;
- an ETF proxy reproduces futures-session or futures-roll economics;
- the source's selected FSTX result was out of sample; or
- a TRAIN or DEVELOPMENT result authorizes live trading.

## Causal retail translation

- Canonical historical input: Alpaca SIP adjusted daily OHLCV.
- Opening-auction observation time: `09:31:00 America/New_York`.
- Earliest entry proxy: adjusted SIP one-minute bar open at `09:32:00`.
- Exit proxy: adjusted daily close under a precommitted market-on-close order.
- Causal gross event return: \(q_t(C_t/E_t-1)\), where \(E_t\) is the 09:32
  entry proxy.
- Source-style same-open return: noncausal diagnostic only.
- Printed-sign return: literal-code diagnostic only.
- Primary round-trip friction: 10 bp.
- Stress round-trip friction: 20 bp.
- Historical borrow availability and fees are not reconstructible; short-side
  results are research diagnostics, not proof of short executability.

## Frozen windows

- `as_of_timestamp`: `2026-08-01 17:30:00 America/New_York`.
- Warm-up query start: `2016-08-01`.
- TRAIN: `2017-01-03` through `2020-12-31`.
- DEVELOPMENT: `2021-01-04` through `2023-12-29`.
- CONFIRMATION: `2024-01-02` onward, sealed.

No DEVELOPMENT entry data may be requested for an instrument unless that
instrument clears every frozen TRAIN gate. Confirmation remains sealed even
if DEVELOPMENT is favorable.

## Two frozen stages

### Small POC

The eight `poc_anchor=TRUE` instruments are `FEZ, SPY, QQQ, IWM, TLT, GLD,
USO, UUP`. `FEZ` is a U.S.-traded European-equity proxy, not FSTX. The other
anchors deliberately span equity, duration, commodity, and currency behavior.

### Wide atlas

The full registry contains 92 instruments selected before outcomes across:

- broad U.S. equity;
- U.S. sector and industry ETFs;
- international equity ETFs;
- fixed-income ETFs;
- commodity ETFs;
- currency ETFs;
- leveraged/inverse ETFs; and
- a labeled individual-stock domain challenger.

The atlas is breadth evidence under unchanged mechanics, not a search that
permits selecting a visually attractive failure.

## Frozen per-instrument TRAIN gates

1. **Integrity:** all point-in-time, lag, date, direction, and price checks pass.
2. **Entry coverage:** at least 95% of selected events have a valid 09:32 entry.
3. **Two-sided support:** at least 24 valid events, at least eight long and eight
   short events, spanning at least three calendar years.
4. **Directional accuracy:** more than 50% of causal event returns have the
   predicted sign.
5. **Primary mean:** mean primary-cost event return is positive.
6. **Uncertainty:** the moving-block-bootstrap one-sided 90% lower bound for
   mean primary-cost event return is positive.
7. **Direction falsification:** the observed mean exceeds the 90th percentile
   of 1,000 seeded random sign flips of the same causal intraday moves.
8. **Stress and stability:** 20 bp stress cumulative return is positive and at
   least three calendar years have positive primary-cost mean event return.

These gates are Gen5 design, not Chan's published checklist. They deliberately
separate adequate event support, correct directional prediction, cost-aware
payoff, uncertainty, a mechanism-specific sign control, and temporal stability.

## Fixed diagnostics

- signal counts by long/short direction and calendar year;
- hit rate and mean return overall and by direction;
- same-open reference versus 09:32 primary and stress outcomes;
- literal printed-code sign check;
- naive and autocorrelation-adjusted Sharpe;
- cumulative event return and maximum drawdown;
- moving-block interval for mean event return;
- randomized-sign distribution;
- gap magnitude versus subsequent signed return; and
- representative event tapes.

## Prohibited rescue paths

After inspection, do not change `k=0.1`, the 90-session volatility window,
opening threshold, 09:31/09:32 timing, same-close exit, costs, registry,
partitions, support thresholds, bootstrap settings, sign-control settings, or
gate conjunction. Do not delete the short side, select only an attractive
category, substitute same-open results for causal results, or open
confirmation. Any such change requires a new substantive decimal lane.

## Dialogue authority

This contract implements operator decision `D97`: briefly discuss and then
execute Example 7.1 as a small textbook POC followed by a wide atlas, while
preserving the literature-study evidence workflow.
