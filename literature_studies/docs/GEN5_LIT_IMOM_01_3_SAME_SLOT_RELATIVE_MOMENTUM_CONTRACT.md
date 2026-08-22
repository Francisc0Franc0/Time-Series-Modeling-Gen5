# LIT-IMOM-01.3 Same-Slot Relative Momentum Contract

Status: `FROZEN_IMPLEMENTATION_APPROVED_RESULTS_UNREAD`

Frozen on `2026-08-21` after the operator approved a minimal test of recurring
time-of-day relative momentum. No `01.3` target, feature, coefficient,
forecast loss, placebo comparison, or outcome was computed before this
contract.

## Narrative hypothesis

Large investors often split orders across sessions and execute against
recurring liquidity or benchmark schedules. If stock-specific buying or
selling pressure is visible in one regular-session 30-minute slot, part of
that pressure may recur in the same slot on the following trading session.

The frozen question is:

> Does a stock's SPY-relative open-to-close return in one 30-minute slot
> predict its SPY-relative return in the same slot on the next trading
> session, beyond target-slot seasonality, the prior session's complete
> relative return, and every deliberately displaced prior-session slot?

This is not another Chan horizon transport. It has one fixed session lag and
one fixed corresponding-slot target. It fits no strategy and computes no
trading or performance outcome.

## Frozen universe and roles

Reuse every row of:

`operator_hypothesis_lab/registries/gen5_intraday_momentum_poc_registry.csv`

The registry contains exactly 26 instruments under SHA-256:

`ED6A9C87E00E53970528F9638BFB972323D47AF86B273C19A13DC89DE9D7B4AF`

- `SPY` is the benchmark only and receives no asset forecast.
- The 22 `diverse_stock_panel` rows are the candidate family.
- `AMD` and `TSLA` are remembered operator-case diagnostics only.
- `QQQ` is an ETF reference diagnostic only.

Thus 25 non-SPY instruments are fitted and reported, while exactly 22 stocks
enter candidate false-discovery and broad-panel gates. No instrument may be
added, removed, substituted, or reclassified after outcomes.

## Frozen data boundary and session admission

- Provider: Alpaca SIP only.
- Bars: adjusted `30Min` OHLCV with adjustment `all`.
- Cache record as-of timestamp:
  `2026-08-13 17:30:00 America/New_York`.
- Design as-of timestamp:
  `2026-08-21 17:30:00 America/New_York`.
- Query/cache start: `2017-09-01`.
- Maximum included date: `2023-12-29`.
- TRAIN target sessions: `2018-01-02` through `2020-12-31`.
- DEVELOPMENT target sessions: `2021-01-04` through `2023-12-29`.
- Locked confirmation begins `2024-01-02`.

Apply the ten outcome-independent Alpaca archive exclusions frozen by the
parent intraday series:

`2018-05-02`, `2018-05-03`, `2018-08-07`, `2019-08-12`, `2019-10-09`,
`2021-04-19`, `2021-10-25`, `2022-01-24`, `2022-01-26`, and `2022-03-08`.

The wrong-clock comparison requires the complete 13-slot grid. Admit a
predictor/target pair only when both consecutive sessions contain exactly one
bar in every regular slot from `09:30` through `15:30` ET for all 26 registry
instruments. Recognized early closes are valid data but are excluded from
this analysis rather than imputed. Do not bridge an archive-excluded or
incomplete session: the predictor must be the target's immediately preceding
session in the unfiltered SPY trading calendar.

Every instrument must match the admitted SPY timestamps, contain no duplicate
timestamps, have finite positive OHLC and nonnegative volume, carry the frozen
provider metadata, and supply at least 700 target sessions in both TRAIN and
DEVELOPMENT. Overnight and weekend intervals are not returns in this test.

## Frozen causal observation

For non-SPY instrument `i`, session `d`, and regular slot `s` in `1,...,13`,
define the open-to-close log return and SPY-relative return:

\[
r_{i,d,s}=\log(C_{i,d,s}/O_{i,d,s}), \qquad
x_{i,d,s}=r_{i,d,s}-r_{SPY,d,s}.
\]

For a target session `d`, let `d-1` mean its immediately preceding admitted
full session. The fixed target is:

\[
y_{i,d,s}=x_{i,d,s}.
\]

The same-slot predictor is `x(i,d-1,s)`. The general relative-momentum control
is the preceding session's full regular-session open-to-close relative return:

\[
g_{i,d-1}=\log(C_{i,d-1,13}/O_{i,d-1,1})
-\log(C_{SPY,d-1,13}/O_{SPY,d-1,1}).
\]

All predictors are known after the preceding close, before the target
session. No target-day close, high, low, volume, or SPY return enters a
predictor.

## TRAIN-frozen normalization

For each asset, estimate from TRAIN only:

- target mean and standard deviation separately for each target slot;
- source-return mean and standard deviation separately for each source slot;
  and
- one mean and standard deviation for the full-session relative return.

Require every standard deviation to be finite and positive. Apply these
unchanged moments to DEVELOPMENT. The modeled target and both return
predictors are TRAIN-standardized. This gives every target slot equal loss
scale and prevents the naturally volatile opening or close from dominating a
common coefficient.

## Frozen forecast authorities

Fit independently by instrument on TRAIN using unpenalized base-R ordinary
least squares. Require finite, nondegenerate, full-rank fits.

| ID | Forecast of standardized next-session slot-relative return |
|---|---|
| `M0_CLOCK` | 13 target-slot fixed effects only |
| `M1_DAY` | target-slot effects plus prior full-session relative return |
| `M2_SAME` | `M1_DAY` plus the preceding session's corresponding-slot relative return |

The same-slot coefficient is common across the 13 target slots. Slot-specific
coefficients may be reported descriptively but may not replace it.

## Frozen wrong-clock falsification

Fit twelve additional models `P01` through `P12`. Each model is identical to
`M2_SAME` except that its slot predictor is displaced circularly by `k` slots:

\[
s_k=((s-1+k) \bmod 13)+1, \qquad k=1,...,12.
\]

All thirteen source alignments therefore use identical assets, target
sessions, target slots, controls, and target values. The twelve displaced
models are negative controls, not candidates. No offset may be selected as a
new hypothesis after inspection.

## Loss and contrasts

Use squared error on the TRAIN-standardized target. Equal-average the 13 slot
losses within each target session; all point estimates and inference operate
on these ordered session means. Also report unscaled squared error and MAE.

Positive contrasts favor the model named second:

- `G10 = loss(M0_CLOCK) - loss(M1_DAY)`;
- `S21 = loss(M1_DAY) - loss(M2_SAME)`; and
- `S20 = loss(M0_CLOCK) - loss(M2_SAME)`.

For each displaced model, define
`Wk = loss(M1_DAY) - loss(Pk)`. Clock specificity is:

\[
U=mean(S21)-\max_{k=1,...,12}mean(W_k).
\]

Equivalently, `U > 0` means `M2_SAME` has lower mean loss than the best
outcome-selected wrong-clock model. The best offset is reported only as a
falsification diagnostic.

## Dependence, placebos, and multiplicity

For each fitted asset and for the equal-weight 22-candidate panel, use a
10,000-draw stationary-block bootstrap of ordered target sessions with
expected block length 20 sessions and quantile type 7. Recompute the maximum
over all twelve wrong-clock models within every bootstrap draw when inferring
`U`; do not condition on the observed best offset.

Use deterministic asset seeds
`2026082170 + 10 * registry_order + contrast_order`, with contrasts ordered
`G10`, `S21`, `S20`, `U`. Use seed `2026082990` for the broad-panel bootstrap.
Report observed means, uncentered percentile 90% intervals, and one-sided
centered-null probabilities that each differential is no greater than zero.

Apply BH `q=0.10` separately for `G10`, `S21`, `S20`, and `U` across all 22
candidate stocks, including negative and null rows. AMD, TSLA, and QQQ receive
intervals and probabilities but no q-value.

## Frozen survival gates

An asset becomes a
`SAME_SLOT_RELATIVE_MOMENTUM_DEVELOPMENT_CANDIDATE` only if:

1. `S21`, `S20`, and `U` are positive;
2. all three have strictly positive 90% lower bounds and BH q-values
   `<=0.10`;
3. the TRAIN-fitted `M2_SAME` same-slot coefficient is positive; and
4. the asset is one of the 22 candidate stocks.

A broad-panel clue requires:

1. equal-weight candidate-panel `S21`, `S20`, and `U` are positive;
2. all three have strictly positive 90% lower bounds and one-sided
   probabilities `<=0.05`;
3. the cross-asset medians of observed `S21` and `U` are positive; and
4. the median TRAIN-fitted same-slot coefficient across candidates is
   positive.

A general-day clue requires positive `G10`, a strictly positive 90% lower
bound, and BH q `<=0.10`; it does not satisfy the same-slot hypothesis.

## Decision map

- **No broad clue and no asset candidate:** record
  `STOP_LIT_IMOM_01_3_NO_CLOCK_SPECIFIC_RELATIVE_MOMENTUM`.
- **Same-slot improvement that fails `U`:** stop; the result is not specific
  to the recurring clock slot.
- **General-day clue only:** report it without relabeling it as same-slot
  momentum or opening another horizon test.
- **Broad-panel clue or asset candidate:** report bounded DEVELOPMENT evidence
  only. Do not access confirmation or construct a strategy automatically.
- **Mechanical or analytical gate failure:** stop without reducing the model,
  placebo set, universe, or session requirements.

## Locked confirmation and closed work

No bar on or after `2024-01-02` may enter this execution. Only an exact frozen
DEVELOPMENT clue could later enter one-shot confirmation after new operator
authorization.

This contract does not authorize asset, slot, lag, horizon, benchmark,
normalization, model, placebo, bootstrap, or FDR tuning; favorable-period or
favorable-offset selection; volume, volatility, regime, news, nonlinear, or
order-book predictors; thresholds, positions, hedges, trades, costs, turnover,
P&L, Sharpe, drawdown, allocation, leverage, advice, execution, or live
behavior; or native futures, FX, crypto, options, extended-hours, or post-2023
data.
