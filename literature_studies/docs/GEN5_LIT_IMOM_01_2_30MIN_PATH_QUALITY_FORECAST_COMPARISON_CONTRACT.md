# LIT-IMOM-01.2 30-Minute Path-Quality Forecast Comparison Contract

Status: `STOP_LIT_IMOM_01_2_NO_CLOCK_CONTROLLED_PATH_QUALITY_FORECAST`

Frozen on `2026-08-21` after the operator approved a close bar-domain
transport of `LIT-MOM-01.5` to 30-minute data. No `01.2` feature, target,
forecast loss, coefficient, contrast, or outcome was computed before this
contract.

The frozen execution subsequently retained all 26 instruments and all 624
cells. Drift/clock baselines were lowest-loss for 21/26 instruments in their
respective chains, raw return for five, and path quality for none. No raw or
path row survived the controlled gates. See the
[results](GEN5_LIT_IMOM_01_2_30MIN_PATH_QUALITY_FORECAST_COMPARISON_RESULTS.md).

## Place in the research progression

`LIT-MOM-01.5` found that neither raw trailing return nor its asymmetric
path-quality extension improved consistently on a constant-drift forecast at
daily resolution. That null does not logically exclude predictability within
or across trading sessions because a daily return aggregates overnight and
intraday increments whose effects may cancel.

`LIT-IMOM-01.1` previously tested a session-scaled Chan screen and trading
sleeve. Its unstable admission and negative economic transport are relevant
prior evidence, but they are not this estimand. `01.2` fits no strategy,
selects no horizon, and computes no trading or performance outcome.

The frozen question is:

> Across a predeclared 30-minute stock panel and unchanged numeric bar-domain
> horizon surface, does causal positive-path coherence and shock
> concentration improve future-return forecasts beyond raw trailing return,
> constant drift, and TRAIN-fitted clock seasonality?

## Frozen universe

Reuse every row of:

`operator_hypothesis_lab/registries/gen5_intraday_momentum_poc_registry.csv`

The registry contains exactly 26 instruments under SHA-256:

`ED6A9C87E00E53970528F9638BFB972323D47AF86B273C19A13DC89DE9D7B4AF`

- 22 diverse stock candidates;
- `AMD` and `TSLA` as remembered operator-case diagnostics only; and
- `SPY` and `QQQ` as ETF reference diagnostics only.

All 26 rows are fitted and reported. The four remembered/reference rows are
excluded from candidate false-discovery families. No instrument may be added,
removed, or substituted after outcomes.

## Frozen data boundary and admission

- Provider: Alpaca SIP only.
- Bars: adjusted `30Min` OHLCV with provider adjustment `all`.
- Cache record as-of timestamp:
  `2026-08-13 17:30:00 America/New_York`.
- Design as-of timestamp:
  `2026-08-21 17:30:00 America/New_York`.
- Query/cache start: `2017-09-01`.
- Maximum included date: `2023-12-29`.
- TRAIN anchors: `2018-01-02` through targets ending no later than
  `2020-12-31`.
- DEVELOPMENT anchors: `2021-01-04` through targets ending no later than
  `2023-12-29`.
- Locked confirmation begins `2024-01-02`.

Use regular US trading hours only: bar starts `09:30` through `15:30` ET on
normal sessions and through `12:30` ET on recognized early closes. Preserve
the ten outcome-independent Alpaca archive exclusions frozen by the parent
intraday series:

`2018-05-02`, `2018-05-03`, `2018-08-07`, `2019-08-12`, `2019-10-09`,
`2021-04-19`, `2021-10-25`, `2022-01-24`, `2022-01-26`, and `2022-03-08`.

Exclude those sessions globally without imputation. Every instrument must
match the resulting SPY timestamp calendar in each period, have no duplicate
timestamps, contain finite positive OHLC and nonnegative volume, carry the
frozen feed/timeframe/adjustment metadata, and supply at least 9,000 common
anchors in both TRAIN and DEVELOPMENT. Overnight gaps remain part of the
ordered bar path and may not be filled or treated as 30 elapsed minutes.

## Frozen bar-domain horizon surface

The numeric grid is a direct bar-domain transport, not a duration-scaled
translation:

\[
L \in \{5,10,25,60,120,250\}, \qquad
H \in \{5,10,25,60\}.
\]

Thus the surface ranges from roughly 2.5 trading hours through about 19
regular sessions. All 24 cells are forecast and equally weighted. No cell is
selected, dropped, promoted, or reweighted.

For signal bar `t`, use all 250 prior closes and all 60 future open intervals
to form one common anchor panel per period. Define the future target:

\[
Y_{t,H}=\log(O_{t+1+H}/O_{t+1}).
\]

This is a completed-close forecast of the return beginning at the next bar
open. Targets may cross normal session, overnight, weekend, holiday, or early-
close boundaries exactly as present in the admitted calendar.

## Frozen causal features

For the `L` ordered close-to-close log steps ending at signal close `t`:

\[
X_{t,L}=\log(C_t/C_{t-L}),
\]

\[
ER_{t,L}=|X_{t,L}|/\sum |r_j|,
\qquad
SC_{t,L}=\max |r_j|/\sum |r_j|.
\]

Set `ER=0` and `SC=0` only when every step is zero. Define:

\[
Q_{t,L}=\max(X_{t,L},0)ER_{t,L},
\qquad
S_{t,L}=\max(X_{t,L},0)SC_{t,L}.
\]

All features use information available at signal close. The expected
mechanism remains a positive coefficient on `Q` and a negative coefficient
on `S`.

## Frozen forecast authorities

Fit every authority independently by instrument and cell using TRAIN only.
Standardize `X`, `Q`, and `S` with TRAIN moments and apply the frozen
transformation to DEVELOPMENT. Use unpenalized base-R ordinary least squares
and require finite, nondegenerate, full-rank fits.

### Exact drop-in chain

| ID | Forecast |
|---|---|
| `B0_DRIFT` | intercept only |
| `B1_RAW` | intercept plus `X` |
| `Q2_PATH` | intercept plus `X`, `Q`, and `S` |

### Clock-aware falsification chain

Use the signal bar's known regular-session slot as a 13-level TRAIN-fitted
factor, with one reference level and no outcome-derived merging:

| ID | Forecast |
|---|---|
| `C0_CLOCK` | bar-slot fixed effects only |
| `C1_CLOCK_RAW` | bar-slot fixed effects plus `X` |
| `C2_CLOCK_PATH` | bar-slot fixed effects plus `X`, `Q`, and `S` |

The clock-aware chain does not add an investable feature hypothesis. It asks
whether apparent path prediction survives ordinary opening, midday, and
closing return seasonality. An invalid cell invalidates the complete
instrument comparison; no model may be reduced after observation.

## Loss comparison

For each model, instrument, cell, and DEVELOPMENT anchor, divide squared
forecast error by that cell's TRAIN target variance. Equal-average the 24
cells at each anchor, then equal-average anchors within each session. Asset
point estimates and inference use these session-level means so early-close
sessions and normal sessions receive equal weight.

Positive contrasts favor the model named second:

- `D10 = loss(B0_DRIFT) - loss(B1_RAW)`;
- `D21 = loss(B1_RAW) - loss(Q2_PATH)`;
- `D20 = loss(B0_DRIFT) - loss(Q2_PATH)`;
- `K10 = loss(C0_CLOCK) - loss(C1_CLOCK_RAW)`;
- `K21 = loss(C1_CLOCK_RAW) - loss(C2_CLOCK_PATH)`; and
- `K20 = loss(C0_CLOCK) - loss(C2_CLOCK_PATH)`.

`K21` is primary. `K20` ensures path quality beats the clock-only baseline.
The `D` chain preserves exact daily-engine comparability.

Report scaled and unscaled loss, MAE, model coefficients, and TRAIN feature
support. Also report predeclared diagnostics by anchor slot and whether the
target crosses at least one session boundary. These diagnostics may explain a
result but may not create candidates or select horizons.

## Dependence and multiplicity

For every instrument and contrast, use the ordered session-level loss
differential in a 10,000-draw stationary-block bootstrap with expected block
length 20 sessions. Use deterministic seed
`2026082160 + 10 * registry_order + contrast_order`, where contrasts are
ordered `D10`, `D21`, `D20`, `K10`, `K21`, `K20`.

Report the observed mean, uncentered percentile 90% interval, and one-sided
centered-null probability that the differential is no greater than zero.
Apply BH `q=0.10` separately by contrast across all 22 candidate stocks,
including negative and null outcomes. AMD, TSLA, SPY, and QQQ receive
probabilities and intervals but no candidate q-value.

## Candidate gate

An instrument becomes a
`CLOCK_CONTROLLED_PATH_QUALITY_DEVELOPMENT_CANDIDATE` only if:

1. exact-chain `D21 > 0` and `D20 > 0`;
2. clock-chain `K21 > 0` and `K20 > 0`;
3. `K21` and `K20` both have strictly positive 90% lower bounds and BH
   q-values `<=0.10`;
4. median standardized `C2_CLOCK_PATH` coefficients across all 24 cells have
   `Q > 0` and `S < 0`; and
5. the row is one of the 22 candidate stocks.

A clock-controlled raw-return clue requires positive `D10` and `K10`, a
strictly positive `K10` lower bound, and `K10` BH q `<=0.10`. It does not
authorize horizon selection or a strategy.

## Decision map

- **No candidates:** record
  `STOP_LIT_IMOM_01_2_NO_CLOCK_CONTROLLED_PATH_QUALITY_FORECAST`.
- **Exact-only clue that fails clock control:** stop and attribute the clue to
  unresolved clock seasonality.
- **Clock-controlled candidate:** report a bounded discovery only; do not
  open confirmation or trading automatically.
- **Raw clue but no path candidate:** record it without reopening Chan horizon
  selection.

## Locked confirmation and closed work

No bar on or after `2024-01-02` may enter this execution. Only an exact frozen
DEVELOPMENT candidate could later enter one-shot confirmation after a new
operator authorization.

This contract does not authorize feature, horizon, slot, asset, penalty,
bootstrap, or FDR tuning; favorable-year or favorable-time-of-day selection;
regime, volume, volatility, cross-sectional, news, or nonlinear predictors;
thresholds, positions, trades, costs, turnover, P&L, Sharpe, drawdown,
allocation, leverage, advice, execution, or live behavior; or native futures,
FX, crypto, options, extended-hours, or post-2023 data.
