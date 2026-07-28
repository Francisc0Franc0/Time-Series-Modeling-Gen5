# Gen5 S0 Statistical-Arbitrage Admissibility POC Contract

Status: `PROPOSED_EXACT_CONTRACT_AWAITING_OPERATOR_APPROVAL`

## Context

S0 is the proposed third mechanism-first detour. T1 rejected robust
asset-specific trend persistence under its frozen design. M1 then rejected a
robust cross-sectional ranking mechanism before portfolio replay. S0 asks:

> Do temporary residual dislocations among economically related, liquid equity
> ETFs converge out of sample often and broadly enough to justify a
> prospective shortability shadow?

This contract translates the operator-approved conceptual freeze into an exact
proposal. It does not yet authorize data retrieval, pair formation, outcome
calculation, portfolio replay, live shorting, order placement, or performance
claims. Implementation begins only after the operator approves this exact
contract.

## Claim boundary

S0A may establish only that a frozen class of relative-value dislocations
showed repeatable historical convergence after ordinary two-leg transaction
costs.

S0A cannot establish point-in-time historical borrow availability, historical
locate availability or borrow fees, production profitability, capacity, live
fill quality, or suitability for automated execution.

Alpaca exposes current `shortable` and `borrow_status` fields and current locate
workflows, but its documented interfaces do not provide a general historical
archive of those conditions. Historical adjusted OHLCV therefore supports a
mechanism test, not a fully executable historical short-side P&L claim.

## Two-stage gate

### S0A — historical mechanism admissibility

S0A tests whether TRAIN-selected residual relationships converge OOS after
next-open timing and conservative ordinary costs.

### S0B — prospective executability shadow

S0B remains closed unless every S0A gate passes and the operator separately
opens it. S0B would record current shortability, borrow status, locate
availability, quoted fees, hypothetical order tickets, and subsequent
convergence without placing orders.

No historical borrow field may be backfilled from current status.

## Frozen data authority

- Provider: Alpaca only.
- Bars: adjusted daily OHLCV.
- Feed: the repository's accepted Alpaca daily-bar feed.
- Decision data: completed daily adjusted bars only.
- Explicit freeze timestamp:
  `2026-07-24 17:30:00 America/New_York`.
- No analytical helper may call `Sys.Date()` or infer the latest session.
- Every query must carry the explicit `as_of_timestamp`.
- Provider behavior remains inside the provider layer.

No quote, option, news, fundamental, index, or new-provider data enters S0A.

## Frozen survivor panel

S0A uses 37 unleveraged equity ETFs divided into four groups. Membership is
fixed now and is not claimed to be a historically reconstructed ETF universe.
Point-in-time eligibility controls when a fixed member can enter a fold; it
does not remove fixed-panel survivor bias.

### US sectors

`XLB, XLC, XLE, XLF, XLI, XLK, XLP, XLRE, XLU, XLV, XLY`

### US size and style

`IWB, IWM, IWD, IWF, IWN, IWO, MDY, IJR`

### Developed-country equity

`EWA, EWC, EWG, EWH, EWI, EWJ, EWL, EWN, EWS, EWU`

### Emerging-country equity

`EEM, EWT, EWY, EWW, EWZ, FXI, INDA, TUR`

The claim is conditional on this frozen, currently observable panel.

## Point-in-time ETF eligibility

At a quarterly formation close, an ETF is eligible only when all conditions
hold using information available by that close:

- at least 480 complete sessions exist inside the 504-session TRAIN window;
- the most recent adjusted close is at least `$10`;
- median adjusted-close times volume over the preceding 63 sessions is at
  least `$25 million`;
- no duplicate session or future-dated bar exists;
- the next-open and required outcome opens are available before an event can
  enter the measurement set.

Missing data never inherit a favorable value. An ETF or pair simply becomes
ineligible.

## Walk-forward schedule

- Formation frequency: quarterly.
- Formation dates: the final completed regular session before each calendar
  quarter begins.
- TRAIN: the 504 completed sessions ending at the formation close.
- OOS: the following calendar quarter.
- Parameters remain frozen throughout that OOS quarter.

Historical labels:

- lookback establishment: 2016 through 2017;
- retrospective development: 2018Q1 through 2021Q4;
- retrospective confirmation: 2022Q1 through 2024Q4;
- later historical shadow: 2025Q1 through 2026Q2.

Development may debug mechanics but may not change this contract after any
development outcome is inspected. Confirmation alone determines the S0A
decision. Later historical shadow is reported separately and cannot rescue a
failed confirmation result.

## Candidate-pair construction

Within each economic group, construct every unordered pair of eligible ETFs.
Ticker-alphabetical order fixes member `A` and member `B`; pair orientation
may not be selected by outcome.

Using TRAIN adjusted closes:

```text
log_price_A(t) = alpha + beta * log_price_B(t) + residual(t)
```

The regression is fit on TRAIN only. A candidate pair is structurally eligible
only when:

- TRAIN daily-return correlation is at least `0.60`;
- `beta` is positive and between `0.25` and `4.00`;
- relative beta drift between the first and second TRAIN halves is no more
  than `50%` of the full-TRAIN absolute beta;
- residual AR(1) coefficient is strictly between zero and one;
- implied residual half-life is between `2` and `30` sessions;
- residual standard deviation is finite and nonzero.

For ranking only, fit the fixed one-lag residual regression:

```text
delta_residual(t)
  = gamma * residual(t-1)
  + delta * delta_residual(t-1)
  + error(t)
```

Rank eligible pairs by the t statistic on `gamma`, most negative first. This is
a frozen residual-stability score, not a formal claim that a cointegration
p-value proves tradability.

## Frozen pair selection

In each fold:

1. sort eligible pairs within each group by the residual-stability score;
2. take at most three pairs per group;
3. greedily skip a pair if either ETF is already used by another selected pair
   in that group and fold;
4. break exact ties lexically by pair ID.

The maximum is 12 selected pairs per fold. No famous pair is manually added,
and no OOS result enters selection.

## Frozen dislocation signal

For each selected pair, retain TRAIN `alpha`, `beta`, residual mean, and
residual standard deviation. During OOS:

```text
residual_oos(t)
  = log_price_A(t) - alpha_train - beta_train * log_price_B(t)

z(t)
  = (residual_oos(t) - residual_mean_train)
    / residual_sd_train
```

An event occurs after a completed close when `abs(z(t)) >= 2.00`.

- Positive `z`: short `A`, long `B`.
- Negative `z`: long `A`, short `B`.
- Entry is no earlier than the next regular-session open.
- No pair may admit another event until the prior event's 20-session endpoint
  has matured.
- No same-close execution, intraday reconstruction, or outcome-aware
  cancellation is allowed.

## Hedge normalization

At entry, gross absolute exposure is normalized to one:

```text
w_A = -sign(z) / (1 + abs(beta_train))
w_B =  sign(z) * beta_train / (1 + abs(beta_train))
```

Positions are fixed from entry through each diagnostic endpoint. This is a
beta-informed residual hedge, not a claim of complete factor neutrality.

## Frozen outcome

For horizon `h` in `5, 10, 20` sessions:

```text
gross_convergence_h
  = w_A * simple_return_A(entry_open, endpoint_open_h)
  + w_B * simple_return_B(entry_open, endpoint_open_h)
```

The primary horizon is `10` sessions. Five and twenty sessions are fixed
diagnostics and may not replace the primary horizon after inspection.

Within every OOS quarter:

1. average events within each selected pair;
2. average the resulting pair means equally;
3. treat that pair-equal quarter mean as one fold observation.

The confirmation estimand is the equal-weight mean of the 12 confirmation
quarter means. Raw event-pooled results are descriptive only.

## Frozen ordinary cost model

- Primary ordinary cost: `5 bp` per one-way gross notional traded.
- Stress ordinary cost: `10 bp` per one-way gross notional traded.
- Charge cost on both entry and exit.
- Apply the same cost model to selected pairs and controls.

These costs represent spread and ordinary slippage. They exclude unavailable
historical borrow and locate costs. Every S0A table and chart must state that
boundary.

## Frozen controls

### Random within-group pair policies

Use `2,000` deterministic random policies with seed `5403`.

For each formation fold, each policy selects the same number of pairs per group
as S0A from the structurally eligible candidate pool, respecting the same
no-shared-ETF rule. Each random pair uses its own TRAIN-frozen regression,
z-score, timing, embargo, horizons, and costs.

Compare S0A's confirmation primary estimand with the empirical distribution of
the 2,000 random-policy estimands.

### Same-pair non-event dates

Use seed `5404`. For every selected-pair event, sample without replacement from
the same pair and OOS fold on dates where `abs(z) < 0.50`, enough future opens
exist, and the 20-session embargo is respected. Apply the corresponding event
direction to the sampled date.

This tests whether the apparent result is merely an unconditional residual
drift. If a fold lacks enough eligible non-event dates, the unmatched support
is reported and the control-support gate can fail; controls are not relaxed
after inspection.

### No-trade

Zero return is the mechanism-level no-trade comparator.

## Frozen S0A gates

S0A passes only if all nine gates hold in retrospective confirmation:

1. **Integrity:** every explicit-as-of, adjusted-bar, TRAIN-only,
   point-in-time eligibility, next-open, embargo, common-endpoint, and
   no-outcome-in-selection check passes.
2. **Pair breadth:** at least eight selected pairs and at least three economic
   groups are represented in at least `10 / 12` confirmation quarters.
3. **Event support:** at least 120 non-overlapping confirmation events exist;
   every confirmation quarter contains an event; and at least eight distinct
   pairs contribute five or more events across confirmation.
4. **Primary convergence:** 5 bp-costed, pair-equal 10-session convergence is
   positive overall and positive in at least `8 / 12` confirmation quarters.
5. **Random-pair superiority:** the selected-pair primary estimand exceeds the
   empirical `90th percentile` of the 2,000 random-policy estimands.
6. **Non-event superiority:** selected-event minus same-pair non-event
   convergence is positive overall and positive in at least `8 / 12`
   confirmation quarters; at least `80%` of selected events receive a valid
   non-event control.
7. **Cost and horizon robustness:** 10 bp-costed primary convergence is
   nonnegative, and the 5- and 20-session diagnostics do not both have
   nonpositive 5 bp-costed confirmation means.
8. **Contribution breadth:** no economic group supplies more than `50%`, no
   pair more than `20%`, and no calendar year more than `50%` of total positive
   arithmetic primary-horizon contribution.
9. **Relationship stability:** at least `60%` of selected pair-folds remain
   structurally eligible at the following quarterly formation, and no
   confirmation quarter has a next-formation survival rate below `40%`.

If any gate fails, record:

```text
STOP_S0A_RELATIVE_VALUE_MECHANISM
```

Do not retune the ETF panel, groups, TRAIN length, eligibility thresholds,
pair score, number of pairs, z-score, embargo, horizon, costs, controls, or
gates on the inspected confirmation outcomes.

If all gates pass, record:

```text
PASS_S0A_TO_PROSPECTIVE_BORROW_SHADOW_DISCUSSION
```

This opens a separate S0B design discussion only. It does not authorize live
shorting, portfolio construction, capital allocation, or order placement.

## Required human-facing evidence

An implemented S0A packet must include:

- run specification and explicit-as-of manifest;
- data and timing health;
- quarterly pair-selection and relationship-stability table;
- selected versus random-pair convergence visualization;
- selected-event versus same-pair non-event visualization;
- group, pair, quarter, and year contribution visualization;
- 5-, 10-, and 20-session convergence under both cost levels;
- representative pair tapes showing TRAIN relationship, OOS z-score,
  next-open entry, both legs, and all three endpoints;
- representative failures and structural breaks;
- nine-gate summary;
- concise report and evidence slide deck.

Every artifact must distinguish historical mechanism evidence from historical
borrow executability.

## Explicit exclusions

S0A does not open a stock-pair universe, full-universe historical
reconstruction, intraday execution, formal cointegration-test selection,
optimized entry or exit rules, leverage, volatility targeting, factor-neutral
portfolio optimization, portfolio CAGR/Sharpe/drawdown claims, historical
borrow imputation, short orders, ML/PCA/Markov fitting, or any live-advice
change.

## Frozen implementation record

The operator explicitly approved this contract without revision. S0A ran at
as-of `2026-07-24 17:30:00` with the frozen 37-ETF survivor panel, four groups,
504-session TRAIN, quarterly OOS schedule, residual model, structural
eligibility rules, maximum three non-overlapping pairs per group, `2.00`
dislocation threshold, 20-session embargo, 10-session primary horizon, 5/20
diagnostics, ordinary two-leg costs, 2,000 seeded random-pair policies,
same-pair non-event controls, and all nine gates.

All 37 ETFs covered every actual reference session and all 12 integrity rows
passed. The raw data-health WARN was limited to the requested weekend boundary
before the first 2016 trading session and did not remove an analytical session.

Only gates G1, G4, and G7 passed. Breadth, support, randomized-selection,
matched-control coverage, contribution breadth, and relationship stability
failed. Record:

```text
STOP_S0A_RELATIVE_VALUE_MECHANISM
```

S0B remains closed. Do not retune S0A on these outcomes, impute historical
borrow, calculate portfolio performance, or infer live short executability.
