# LIT-MR-02.1 PANEL-A Contract

## Status

`COMPLETED_STOP`

This contract was frozen before any PANEL-A outcomes were computed.

Implementation preserved the frozen registry and mechanics. The completed
result is `STOP_LIT_MR_02_1_PANEL_A_NO_FULL_PASS`.

## Place In The Research Program

`LIT-MR-02.1` remains the strategy-mechanics identifier. Chan's `USO-GLD`
Example 3.2 replication remains the canonical literature instance and retains
its recorded `STOP_LIT_MR_02_1_TRAIN_MECHANISM` result.

`LIT-MR-02.1-PANEL-A` is a fixed replication batch. Changing the asset pair
without changing the formula does not create `02.2`; each row is recorded as
an instance:

`LIT-MR-02.1 / pair_id=P01_IVV_SPY`

The panel does not rescue, overwrite, pool with, or retune the canonical
example.

## Research Question

When the same source-faithful 20-session adaptive raw-price spread rule is
applied to a finite set of economically motivated relationships over the same
2016-2020 TRAIN window:

1. how often is the proposed spread structurally admissible;
2. how often does it converge in the hypothesized direction;
3. how often does the exact cost-aware trading rule produce positive,
   uncertainty-aware evidence; and
4. do results differ between near-substitutes and related but imperfect
   exposures?

This is a template-replication question, not a search for the best pair.

## Why Positive Co-Movement Is The Primary Case

For rolling window \(W_t\), estimate:

\[
Y_i = \alpha_t + \beta_t X_i + \epsilon_i,\quad i \in W_t
\]

with:

\[
\beta_t =
\frac{\sum_{i \in W_t}(X_i-\bar X_t)(Y_i-\bar Y_t)}
     {\sum_{i \in W_t}(X_i-\bar X_t)^2}
\]

The traded source-convention spread is:

\[
S_t = Y_t-\beta_t X_t
\]

For \(\beta_t>0\), long spread means long \(Y\) and short \(X\); short spread
means the reverse. This is the intended relative-value interpretation.

For \(\beta_t<0\):

\[
Y_t-\beta_t X_t = Y_t+|\beta_t|X_t
\]

A long-spread position is then long both assets after gross normalization.
That may still define a mathematical residual, but it is not the same
opposite-leg relative-value trade. Therefore inverse candidates are descriptive
challengers only. They receive beta-sign and spread diagnostics but no trading
replay or promotion comparison in PANEL-A. Allowing same-side execution would
be a substantive future variant, not a minor pair substitution.

## Fixed Pair Registry

The first symbol is modeled \(Y\); the second is hedge/reference \(X\). OLS is
asymmetric, so orientation is part of the frozen contract.

### Primary: near-substitutes

| Pair ID | \(Y\) | \(X\) | Economic rationale |
|---|---|---|---|
| `P01_IVV_SPY` | `IVV` | `SPY` | Highly overlapping S&P 500 index ETFs |
| `P02_IAU_GLD` | `IAU` | `GLD` | Physically backed gold exposure ETFs |
| `P03_SOXX_SMH` | `SOXX` | `SMH` | Semiconductor ETFs with overlapping holdings |
| `P04_VEA_EFA` | `VEA` | `EFA` | Developed-markets ex-US equity exposure |
| `P05_VWO_EEM` | `VWO` | `EEM` | Broad emerging-markets equity exposure |

### Primary: related but imperfect exposures

| Pair ID | \(Y\) | \(X\) | Economic rationale |
|---|---|---|---|
| `P06_QQQ_XLK` | `QQQ` | `XLK` | Growth-heavy Nasdaq versus US technology |
| `P07_IJR_IWM` | `IJR` | `IWM` | S&P SmallCap 600 versus Russell 2000 |
| `P08_KRE_XLF` | `KRE` | `XLF` | Regional banks versus broad financials |
| `P09_IBB_XLV` | `IBB` | `XLV` | Biotechnology versus broad health care |
| `P10_USO_XLE` | `USO` | `XLE` | Oil futures exposure versus energy equities |
| `P11_TLT_IEF` | `TLT` | `IEF` | Long- versus intermediate-duration Treasuries |
| `P12_HYG_LQD` | `HYG` | `LQD` | High-yield versus investment-grade credit |

### Diagnostic only: inverse or sign-unstable challengers

| Pair ID | \(Y\) | \(X\) | Economic rationale |
|---|---|---|---|
| `D01_GLD_UUP` | `GLD` | `UUP` | Gold versus US-dollar exposure |
| `D02_TLT_SPY` | `TLT` | `SPY` | Long Treasuries versus US equities |

## Frozen Mechanics

Every primary pair uses the exact `LIT-MR-02.1` mechanics:

- Alpaca adjusted daily OHLCV only.
- Explicit as-of: `2026-07-24 17:30:00`.
- Requested and analyzed window: `2016-01-04` through `2020-12-31`.
- First 39 common sessions are indicator warm-up.
- 20-session rolling OLS of adjusted close \(Y\) on adjusted close \(X\).
- Spread \(S_t=Y_t-\beta_tX_t\); estimated intercept is not subtracted.
- 20-session rolling spread mean and sample standard deviation.
- \(z_t=(S_t-\bar S_t)/s_t\).
- Enter long spread below \(-1\).
- Enter short spread above \(+1\).
- Exit on zero crossing.
- Signal after close; target at next open.
- No same-close reversal, stop, target, maximum hold, or pair-specific tuning.
- Daily adaptive rehedging.
- One gross-normalized unit:

\[
w_{Y,t}=\frac{d_tY_t}{Y_t+|\beta_t|X_t},\qquad
w_{X,t}=\frac{-d_t\beta_tX_t}{Y_t+|\beta_t|X_t}
\]

where \(d_t \in \{-1,+1\}\) is short- or long-spread direction.

- Primary cost: 5 bp per one-way weight change.
- Stress: 10 bp per one-way weight change plus 100 bp annualized short gross.
- Exact eight TRAIN gates from the canonical instance.
- 2,000 moving-block trade bootstraps, 2,000 matched random-sign controls,
  and 2,000 forward-convergence block bootstraps. Seeds are the canonical seeds
  plus `1000 * pair_index`, fixed before outcomes.

No alternate lookback is inspected. A 10/20/40/60-session comparison would
change the mechanics and must be separately frozen as a future variant.

## Pair-Level Outputs

Each primary pair reports:

- beta coverage and direction support;
- completed long- and short-spread trades;
- mean primary-cost net trade return and block-bootstrap interval;
- completed-trade hit rate;
- matched random-sign p90;
- positive TRAIN years;
- z versus forward-five spread-return correlation and interval;
- dynamic-spread ADF-style statistic and half-life;
- bar-by-bar cumulative return, autocorrelation-adjusted Sharpe, and drawdown;
- all eight gate results.

The inverse challengers report beta-sign coverage, median beta, sign changes,
ADF-style diagnostics, half-life, and signed forward relationship. Trading
performance is explicitly `NOT_RUN`.

## Panel-Level Interpretation

The panel reports all pairs. It does not rank a winner for adoption and does
not drop failed relationships.

Summaries include:

- full-gate passes among the 12 primary pairs;
- pairs with positive mean net return;
- pairs with negative forward-convergence correlation;
- median pair-level net return, hit rate, beta coverage, and bar return;
- separate near-substitute and related-exposure summaries;
- inverse challengers on a separate diagnostic surface.

If no primary pair passes all eight gates, record
`STOP_LIT_MR_02_1_PANEL_A_NO_FULL_PASS`.

If one or more primary pairs pass all eight gates, record
`REVIEW_REQUIRED_LIT_MR_02_1_PANEL_A_PAIR_SPECIFIC_CONFIRMATION`. A pass is only
permission to discuss a new pair-specific sealed confirmation contract. It is
not strategy acceptance, capital allocation, or authority to choose the
largest observed return.

Development and confirmation data remain unopened for every pair.

## Feasibility And Boundaries

All instruments are established US-listed ETFs with daily Alpaca adjusted-bar
feasibility over the requested period. Cached coverage must be audited and any
missing local histories refreshed before the run is usable.

This slice does not:

- add a provider or non-daily data;
- select pairs from observed outcomes;
- scan a larger combinatorial universe;
- tune pair-specific windows, thresholds, exits, or costs;
- trade a negative-beta spread;
- open development or confirmation evidence;
- make historical borrow-availability claims;
- change allocation, live advice, or execution behavior.

## Completed Readout

Run packet:

`runs/research_workbench/literature_grounded/lit_mr_02_1_panel_a_20260728`

All 28 requested pair-leg coverage checks passed for the 2016-2020 window.
The packet's data-health `WARN` records deliberately historical end dates
relative to the 2026 as-of timestamp; the requested range was refreshed and
complete.

Among the 12 primary pairs:

- `0 / 12` passed all eight gates;
- `1 / 12` had a positive mean primary-cost net trade return;
- `3 / 12` had the hypothesized negative forward-convergence point estimate,
  but none had an upper confidence bound below zero;
- median mean net return was `-11.64 bp/trade`;
- median completed-trade hit rate was `34.2%`.

Near substitutes produced `0 / 5` positive mean net returns. Their gross
spread movements were often too small to survive the frozen turnover costs.
Related exposures produced `1 / 7`: `USO-XLE` averaged `+21.66 bp/trade`, but
its interval `[-73.75, +141.56] bp`, matched random-sign p90, positive-beta
coverage, and forward-convergence evidence all failed the frozen requirements.
It is not selected.

The inverse challengers were not traded. `GLD-UUP` and `TLT-SPY` had negative
beta for only `80.1%` and `64.9%` of eligible sessions, with 54 and 66 sign
changes. This confirms that negative-beta assets can be statistically related
while implying same-side positions and unstable strategy semantics.

Development and confirmation remain unopened. Do not choose a winner, change
the 20-session window, or create a pair-specific rescue from this panel.
