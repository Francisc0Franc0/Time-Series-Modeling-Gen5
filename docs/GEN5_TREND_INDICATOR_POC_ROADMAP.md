# Gen5 Trend-Indicator POC Roadmap

Status: `ROADMAP_DOCUMENTED_NO_NEW_LANE_OPEN`

## Where This Fits

`HYP-REG-01.1` showed that causal, asset-relative ATR% can identify a coherent
and persistent volatility state. Its first hard strategy overlay did not pass,
so ATR% is accepted measurement evidence rather than strategy authority.

Trend has been harder. Cross-sectional breadth and trend-field constructions
did not transport; a faster field did not repair them; Kaufman ER(20) and
Wilder ADX(14) did not predict a straighter future path. `HYP-REG-05.2` then
showed a narrower distinction: HIGH ADX contained some entry-ranking
information, but using it as a binary SMA8/SMA14 permission or exit rule made
the complete policy worse.

The next phase should therefore test distinct trend constructs one at a time,
using the same minimal strategy only after the measurement and causal mechanics
are auditable. This roadmap bookmarks the concepts and defines their sequence.
It does not freeze their parameters, authorize outcome access, combine them
with ATR%, or open confirmation.

## The Dimensions We Are Trying to Separate

“Trend” is not one property:

- **direction:** whether the recent movement is upward or downward;
- **strength:** how large the displacement is relative to noise or volatility;
- **quality:** whether the path is orderly or repeatedly reverses;
- **persistence:** whether returns reinforce or offset one another across a
  specified scale;
- **agreement:** whether several economically distinct horizons point the same
  way;
- **onset:** whether a new directional process may have begun;
- **range escape:** whether price has left a previously established trading
  range and sustained the break.

ATR% measures amplitude rather than any of these directional properties. SMA
8/14 supplies a simple directional trading decision. The purpose of each trend
candidate is to add one separately interpretable dimension—not to build a
large composite score.

## Candidate T1 — Rolling Variance Ratio / Return Persistence

**Priority:** first and recommended.

For aggregation horizon `q`:

```text
VR(q) = Var(r_t + ... + r_(t-q+1)) / (q * Var(r_t))
```

- `VR > 1` is consistent with positive serial dependence or persistence at
  that scale.
- `VR < 1` is consistent with negative serial dependence or reversal.
- `VR ~= 1` is consistent with a random-walk-like return process at that scale.

This is genuinely different from ER and ADX because it measures dependence in
returns rather than the visual smoothness, displacement efficiency, or
directional-movement strength of price. It also does not supply direction;
that is desirable when the unchanged SMA parent already owns direction.

The individual contract should select one heteroskedasticity-robust primary
variance-ratio construction and at most one predeclared scale-durability check.
It should not search aggregation horizons or estimation windows after seeing
strategy outcomes.

**Literature anchors:**

- Lo and MacKinlay, variance-ratio tests of the random-walk hypothesis and
  finite-sample behavior:
  <https://web.mit.edu/Alo/www/Papers/lo-mackinlay-89.html>
- Chow and Denning, joint inference for multiple variance ratios:
  <https://doi.org/10.1016/0304-4076(93)90051-6>

## Candidate T2 — Volatility-Normalized Robust Slope and Fit

**Priority:** second.

Fit a trend to recent log price:

```text
log(P_i) = a + b * i + error_i
```

Keep distinct outputs:

- the sign of `b` for direction;
- slope divided by recent realized volatility for economic strength;
- a fit or monotonicity measure for path quality.

The contract should decide between an ordinary slope with heteroskedasticity-
and-autocorrelation-aware uncertainty and a robust slope such as Theil-Sen.
Ordinary regression t-statistics on overlapping log-price levels must not be
presented as classical independent-error p-values. Fit quality also must not be
treated as evidence of future return by itself.

This candidate overlaps partially with ER but is not identical: ER compares
net displacement with total path length, whereas slope/fit asks how well a
directional linear representation describes the observed path after
volatility normalization.

## Candidate T3 — Multi-Horizon Direction Agreement

**Priority:** third.

Measure volatility-normalized return direction across a small, predeclared
set of short, medium, and long horizons. Preserve:

- the sign at each horizon;
- the degree of sign agreement;
- whether the shortest horizon is joining or opposing the longer horizons.

Do not count several overlapping horizons as independent votes. The indicator
is a structured description of cross-scale agreement, not four independent
confirmations. The individual contract must freeze the horizon set and one
interpretation of full agreement versus transition before accessing outcomes.

This is related to time-series momentum but tests agreement across scales
rather than selecting the best lookback. Moskowitz, Ooi, and Pedersen document
intermediate-horizon time-series momentum across diversified futures, while
also showing that persistence and longer-horizon reversal can coexist:
<https://w4.stern.nyu.edu/facdir/lpederse/papers/TimeSeriesMomentum.pdf>.

## Candidate T4 — Causal Change-Point / Trend-Onset Detection

**Priority:** fourth because it is methodologically more delicate.

Rather than asking whether a mature trend is strong, a sequential CUSUM-like
construction asks whether standardized returns have accumulated evidence of a
change in directional behavior. Its attraction is earlier recognition of
onset. Its risks are material:

- expected equity drift is small relative to daily volatility;
- volatility changes can masquerade as mean or direction changes;
- the reference value and alarm threshold control false detections;
- a detected event is not automatically a durable regime.

This candidate should begin with synthetic false-alarm and detection-delay
calibration. The live-like construction must be one-sided, sequential, and
causal; full-sample retrospective change-point labels are prohibited. The
contract should treat the output first as an event or transition marker, not
force it into a persistent LOW/MEDIUM/HIGH state.

**Literature anchor:** Brown, Durbin, and Evans-style CUSUM monitoring and
later sequential financial-surveillance work motivate the family; a bounded
source review is required before freezing the exact statistic. No threshold
is frozen by this roadmap.

## Candidate T5 — Range Position and Breakout Persistence

**Priority:** fifth; simplest mechanically but closest to becoming a strategy
signal rather than a regime measurement.

A canonical range-location quantity is:

```text
range_position = (P_t - rolling_low) / (rolling_high - rolling_low)
```

The useful question is not merely whether price touched a recent high. It is
whether a range escape persists, rapidly fails, or repeatedly retests the
boundary. The candidate should preserve breakout age and post-break behavior
rather than search many channel lengths.

Moving-average and trading-range-break rules have a formal empirical history;
Brock, Lakonishok, and LeBaron evaluated simple versions using bootstrap null
models: <https://doi.org/10.1111/j.1540-6261.1992.tb04681.x>.

Before freezing, decide whether this belongs in `HYP-REG` as a contextual
range-escape state or in `HYP-MOM` as a direct entry family. The label must
follow the action. Existing Gen5 breakout code does not authorize reusing or
selecting an already favorable specification for this roadmap.

## Common Sequential Protocol

Each candidate receives a separate operator discussion and frozen contract.
Earlier results may teach us about concepts, but may not reactively alter the
mechanics of later candidates after their outcomes are inspected.

### Stage A — Construction and measurement audit

Before strategy performance:

1. define the exact causal statistic, required prehistory, update time, and
   missing-value behavior;
2. validate expected ordering on synthetic persistent, random-walk-like, and
   reversing paths where applicable;
3. verify that the statistic uses only information available through close
   `t`;
4. report continuous distributions, asset-relative behavior, occupancy,
   dwell time, switching, and sensitivity to known data gaps;
5. use representative price/state tapes to confirm that the label means what
   its name claims;
6. define a semantic falsification target appropriate to the construct rather
   than requiring every candidate to predict its own future label.

Stage A can stop a malformed or unusable measurement before strategy contact.
A coherent descriptive state does not automatically pass to confirmation.

### Stage B — Strategy-relative development replay

Unless an individual contract supplies a strong reason otherwise, use:

- the unchanged daily SMA8/SMA14 long/cash parent;
- fresh cross-up entry at next open and parent cross-down exit at next open;
- the candidate only as a fresh-entry eligibility condition;
- skipped entries not deferred;
- no candidate-driven reactive exit in the first version;
- 1x only, 5 bp per side primary and 10 bp stress;
- compounding within the same annual-cell convention;
- unfiltered parent, buy-and-hold, and cash baselines.

The parent supplies direction. A non-directional construct such as variance
ratio should only judge environmental eligibility. A directional candidate
must specify whether it confirms or contradicts the parent without changing
the parent signal itself.

### Stage C — Falsification and gates

Every strategy-relative lane should include:

- exact parent reproduction before interpretation;
- descriptive parent-trade stratification by the candidate value/state;
- 200 deterministic within-asset/year circular timing controls;
- selection of exposure-nearest controls using exposure only;
- return, Sharpe, maximum drawdown, exposure, turnover, hit rate, trade count,
  and representative trade tapes;
- six-year per-asset and calendar-year breadth;
- an explicit gate table and stop status.

Recommended common strategy gates are:

1. causal data and calendar integrity;
2. exact parent reproduction;
3. candidate-specific construction/semantic integrity;
4. median return above the parent;
5. six-year improvement in at least 15 of 24 primary stocks;
6. positive median excess in at least four of six development years;
7. maximum drawdown no worse and Sharpe no lower than the parent;
8. positive absolute median return;
9. actual timing at or above the 80th percentile of exposure-nearest controls
   and above their median.

An individual contract may justify a different semantic gate, but it must not
weaken performance or transport gates after outcome access.

## Common Evidence Boundary

For comparability, the recommended development surface is the already audited
24-stock primary panel plus SPY/QQQ reference rows over 2018-2023. Reuse must be
labeled `DEVELOPMENT_REUSED_WINDOW`, not fresh OOS evidence. The 2024+ interval
remains sealed for each candidate unless that candidate independently passes
all frozen development gates and the operator separately opens confirmation.

Testing all five concepts on one reused window is an educational concept atlas,
not five independent chances to discover deployable alpha. We must not rank the
five retrospectively and call the winner confirmed. A final combination with
ATR%, another trend candidate, allocation, leverage, or live behavior requires
a new economic rationale, a separately frozen interaction policy, and fresh
evidence.

## Recorded Test Order

1. **T1 variance ratio:** statistically distinct return persistence; recommended
   next lane.
2. **T2 robust slope/fit:** direct direction, normalized strength, and linear
   path quality.
3. **T3 multi-horizon agreement:** cross-scale consensus without lookback
   selection.
4. **T4 causal change point:** transition/onset detection after synthetic
   false-alarm calibration.
5. **T5 breakout persistence:** range escape, with taxonomy decided before
   freezing because it may be a strategy rather than a regime filter.

The order controls implementation complexity and interpretability. It is not a
claim that later candidates have lower economic potential.

## Explicitly Deprioritized or Prohibited

- raw Hurst exponent or classical rescaled-range analysis as the next rolling
  filter; short-window estimates can confuse short-range dependence with long
  memory. Lo's modified R/S work found no robust long-range dependence in the
  examined stock-index returns after accounting for short-range effects:
  <https://ideas.repec.org/a/ecm/emetrp/v59y1991i5p1279-313.html>;
- ADX length, threshold, rising-ADX, or state-eligibility grids;
- Aroon, VHF, or similarly close repackagings unless a later source review
  demonstrates a genuinely distinct estimand;
- more breadth-window permutations under the stopped breadth identifiers;
- selecting favorable assets, years, horizons, thresholds, or visual tapes;
- stacking ATR%, several trend measures, leverage, allocation, or live
  behavior before the standalone lanes conclude;
- using future-smoothed, full-sample, or retrospective state assignments for
  causal policy evidence.

## Next Gate

Discuss and freeze T1 only. Its contract must settle the robust variance-ratio
formula, one primary aggregation scale, at most one durability scale, rolling
estimation history, state representation, synthetic tests, and exact Stage B
entry rule before any T1 outcome is read.
