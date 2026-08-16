# HYP-REG-05.1 Path Trendability Diagnostic Contract

Status: `FROZEN_FOR_DEVELOPMENT_EXECUTION`

## Decision Context

`HYP-REG-04.1` and `HYP-REG-04.2` showed that slow and fast signed market
direction fields could describe recent conditions without reliably preserving
their direction. This lane changes the predicted property rather than
shortening the same signal again.

The question is:

> Can recent path trendability identify periods followed by a straighter,
> less reversal-prone price path, without using strategy returns or selecting
> a direction to trade?

This is an asset-relative measurement diagnostic. It is not an entry rule,
strategy overlay, ATR% combination, or confirmation run.

## Frozen Candidates

### Primary: Kaufman Efficiency Ratio

For trailing length `L = 20`:

`ER_L(t) = abs(log(C_t) - log(C_t-L)) / sum(abs(diff(log(C))))`

over the same trailing path. ER is bounded from zero to one. It measures net
progress divided by total distance traveled. Direction is stored separately as
the sign of the trailing net move.

### Benchmark: Wilder ADX

Use canonical Wilder Directional Movement and `ADX(14)`:

- positive and negative directional movement come from competing expansions
  in consecutive highs and lows;
- each is Wilder-smoothed and divided by Wilder-smoothed True Range to form
  `+DI` and `-DI`;
- `DX = 100 * abs(+DI - -DI) / (+DI + -DI)`;
- ADX is the Wilder-smoothed average of DX.

ADX is directionless. Its accompanying direction is the sign of `+DI - -DI`.
The five-session change in ADX is a secondary descriptive readout only. It
cannot promote ADX or replace the frozen level test.

## Frozen Universe and Data

- 26 registered assets:
  - AMD and TSLA as canonical operator cases;
  - 22 sector-diverse stocks;
  - SPY and QQQ as broad reference ETFs.
- Alpaca adjusted daily OHLCV only.
- Explicit as-of timestamp:
  `2026-08-14 17:30:00 America/New_York`.
- Query start: `2016-01-04`.
- Development interval: `2018-01-02` through `2023-12-29`.
- Confirmation begins `2024-01-02` and remains sealed.
- No imputation, synthetic bars, provider expansion, or future-date access.

The registry is frozen at:

`operator_hypothesis_lab/registries/hyp_reg_05_1_path_trendability_registry.csv`

## Asset-Relative State Construction

Each raw candidate is ranked against its own preceding 252 completed values.
The current value is excluded from the historical reference window.

The percentile is converted to a causal hysteretic state:

- enter `LOW` below the 30th percentile;
- leave `LOW` above the 40th percentile;
- enter `HIGH` above the 70th percentile;
- leave `HIGH` below the 60th percentile;
- otherwise remain or enter `MEDIUM`.

These thresholds match the accepted ATR% measurement lane for later
interpretability. They are not chosen from trendability outcomes.

## Future Path Targets

The measurement is known after close `t`. Every future path starts at the next
session's open and ends at the close of the `H`th future session.

### Primary geometry target

For `H` future sessions:

`FER_H = abs(log(C_t+H / O_t+1)) / sum(abs(future path log steps))`

where the first step is next-open to next-close and subsequent steps are
close-to-close. FER is directionless and bounded from zero to one.

### Secondary semantic targets

- `direction_survival_H`: whether the future net move has the same sign as the
  candidate's trailing direction.
- `turn_rate_H`: sign changes among successive future path steps divided by
  the available adjacent step pairs.

Horizon roles are frozen:

- `H5`: onset readout;
- `H10`: primary swing-horizon target;
- `H20`: durability target.

No horizon may replace another after outcomes are observed.

## Evaluation Surfaces

For ER and ADX separately, report:

1. per-asset Spearman association between causal percentile and future FER;
2. panel median association and the number of positive assets;
3. low/medium/high future-FER medians and high/low ratios;
4. high-minus-low direction-survival gaps;
5. high-minus-low future-turn-rate gaps;
6. all ten non-overlapping H10 starting offsets;
7. the two fixed temporal halves and six calendar years;
8. within-asset, within-year circular timing controls;
9. state occupancy, switching, run duration, and one-session reversals;
10. raw ER/ADX agreement and the non-promotional five-session ADX-change
    readout.

Overlapping daily results remain descriptive. Promotion gates use the frozen
non-overlapping samples where specified.

## Candidate Gates

Integrity is common. Each candidate is then evaluated independently so ADX is
not forced to fail merely because ER is primary, and ER is not selected merely
because it beats ADX.

### G1 — integrity

- 26/26 complete requested-range coverage;
- at least 252 causal history values before the first admitted percentile;
- future paths start at next open;
- 2024+ absent;
- no strategy, PnL, Sharpe, drawdown, ATR-state, or allocation columns.

### G2 — H10 continuous ordering

- median per-asset non-overlapping Spearman at least `+0.08`;
- at least `18/26` assets positive.

### G3 — H10 state separation

- median per-asset high/low future-FER ratio at least `1.08`;
- at least `18/26` assets have high above low.

### G4 — H20 durability

- median per-asset non-overlapping Spearman at least `+0.05`;
- at least `17/26` assets positive;
- median high/low future-FER ratio at least `1.05`.

### G5 — path semantics

At H10:

- median high-minus-low direction survival at least `+3 pp`;
- at least `17/26` assets have positive survival gaps;
- median high-minus-low future turn rate at most `-2 pp`;
- at least `17/26` assets have lower turn rates in high than low.

### G6 — H10 offset stability

- all ten offsets valid;
- at least `7/10` offsets have positive median per-asset Spearman and a
  median high/low FER ratio above one.

### G7 — temporal transport

- median H10 Spearman and high/low FER ratio are favorable in both
  `2018-2020` and `2021-2023`;
- at least `4/6` calendar years are favorable on both measures.

### G8 — circular timing control

Actual H10 median Spearman and median log high/low FER ratio must each rank at
or above the 90th percentile of 200 deterministic within-asset, within-year
circular controls.

### G9 — state usability

Across assets:

- median occupancy of every state is at least 15%;
- median switches per asset-year is between 4 and 40;
- median one-session reversal share is at most 10%;
- median state-run duration is at least 3 sessions.

## Decision Logic

- A candidate earns diagnostic discussion only if G1 and all of its G2-G9
  gates pass.
- If neither candidate passes, record
  `STOP_PATH_TRENDABILITY_GATES_FAILED_NO_ATR_JOIN_OR_STRATEGY`.
- If one or both pass, record the candidate names and
  `DIAGNOSTIC_COMPLETE_STOP_BEFORE_ATR_JOIN_OR_STRATEGY`.

Passing does not authorize:

- a trading signal or performance calculation;
- an ATR% combination;
- indicator or horizon tuning;
- selection of a favorable asset subset;
- access to 2024+ confirmation data.

## Literature Grounding

- J. Welles Wilder Jr., *New Concepts in Technical Trading Systems* (1978),
  Directional Movement Concept and Directional Movement System.
- Perry J. Kaufman, *Trading Systems and Methods*, efficiency ratio and
  adaptive trend measurement.
- Lo and MacKinlay's variance-ratio work remains a documented later
  statistical alternative; it is not part of this lane.
