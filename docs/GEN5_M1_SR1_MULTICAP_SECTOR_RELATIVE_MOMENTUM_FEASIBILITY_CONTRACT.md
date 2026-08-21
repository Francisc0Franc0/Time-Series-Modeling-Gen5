# Gen5 M1-SR1 Multi-Cap Sector-Relative Momentum Feasibility Contract

Status: `APPROVED_DESIGN_STOP_POINT_IN_TIME_MULTICAP_AUTHORITY_MISSING`

## Operator decision

The operator approved a stock-level extension of the cross-sectional momentum
question across large-, mid-, and investable small-cap US equities. Market
capitalization is a predeclared heterogeneity dimension, not a universe to be
selected after outcomes are inspected. The smallest NYSE size quintile is a
separate microcap challenger and is not pooled into the core experiment.

This slice freezes the research identity and the data-admissibility design. It
does not authorize a data-vendor addition, provider change, outcome
calculation, portfolio replay, confirmation opening, allocation decision, or
live behavior.

## Place in the research sequence

`M1-SR1` is a new sibling hypothesis. It does not rescue or retune the stopped
24-ETF M1 experiment. M1 asked whether relative winners across a fixed panel
of sector and country ETFs continued to outperform. `M1-SR1` asks whether
individual stocks continue to outperform economically comparable peers inside
the same sector and contemporaneous capitalization tier.

It also does not reopen `HYP-MOM-04.3B`. That lane tested a quarterly,
four-feature Ridge model and a six-month sector-relative momentum comparator
on a fixed September 2020 SPY cohort. Its 2024+ confirmation remains sealed.
The proposed `M1-SR1` measurement is monthly, single-feature, model-free, and
multi-cap, but the weak H04.3B sector-momentum result remains relevant prior
evidence.

The Chan concept remains a separate future hypothesis.

## Approved economic question

At a completed month-end decision, within stocks that belong to the same
contemporaneously known sector and capitalization tier, does a higher trailing
12-minus-1-month adjusted-return rank predict a higher next-month return
relative to those peers?

The core claim is cross-sectional continuation among comparable peers. It is
not market timing, an absolute-return forecast, a claim that every sector has
momentum, or evidence that any portfolio is implementable.

## Core population

The intended parent population is point-in-time US primary-listed common
equity on NYSE, Nasdaq, or NYSE American. The source-specific security-type
mapping must be frozen before an audit and must exclude at least:

- ETFs and other exchange-traded products;
- mutual funds, closed-end funds, preferred stock, bonds, rights, warrants,
  units, and depositary receipts;
- OTC securities;
- blank-check shells before an operating-company combination; and
- any security whose common-equity or primary-listing status cannot be
  established as of the decision date.

Current survivors may not define the historical population. Every security
must carry a stable issuer identifier, stable security identifier, original
symbol history, listing effective dates, and removal effective dates.

When an issuer has multiple eligible common share classes, use a
source-designated primary security when one is available. Otherwise retain
only the class with the highest trailing 63-session median adjusted dollar
volume known at the decision date, with stable security identifier as the
deterministic tie-break. The exclusion must remain visible in the audit.

## Point-in-time sector definition

GICS is the preferred taxonomy because its top level is an explicit 11-sector
investment classification. A usable source must provide the company
classification, classification effective date, and applicable hierarchy
version. A current GICS label may not be backfilled through history.

If contemporaneous GICS history is unavailable, stop for an operator data
decision. ICB may be proposed as an alternative under a separately documented
mapping, but it may not be silently substituted because its hierarchy and use
of the word `Sector` differ. SEC SIC codes are a regulatory industry label and
are not an equivalent replacement for an investment peer taxonomy.

## Point-in-time capitalization tiers

Market equity at decision month-end comes from authoritative point-in-time
reference data or, when the source requires construction, from split-
consistent inputs:

```text
market_equity(i,t) = point_in_time_reference_price(i,t)
                     * point_in_time_shares_outstanding(i,t)
```

The price and share count must use the same split basis and have effective
timestamps no later than the decision timestamp. Current shares outstanding
may not be backfilled. This reference-data calculation does not replace Alpaca
adjusted daily OHLCV as the canonical signal and target bar surface.

At every decision month, calculate market-equity quintile breakpoints from the
eligible NYSE common-stock reference population, not from the eventual
research sample. Assign the parent population as follows:

| Tier | Point-in-time NYSE market-equity band | Role |
|---|---|---|
| `micro` | At or below the 20th percentile | Separate challenger; excluded from core |
| `small` | Above the 20th through the 40th percentile | Core |
| `mid` | Above the 40th through the 80th percentile | Core |
| `large` | Above the 80th percentile | Core |

The labels are research bands, not claims of equivalence to a commercial
large-, mid-, or small-cap index. Exact breakpoint values and boundary ties
must be written to every audit packet. If the authoritative source cannot
represent the full NYSE reference population at a decision date, that month
fails; do not replace the reference with parent-sample percentiles.

## Point-in-time stock eligibility

At decision month-end `t`, a core stock is eligible only when all conditions
hold using information available through `t`:

1. It satisfies the frozen security-type and listing rules.
2. Its issuer and security identifiers are resolved without a future alias.
3. Its sector and capitalization tier are known point in time.
4. It has at least 13 completed month-end observations.
5. It has at least 60 observed bars across the preceding 63 reference
   sessions, including the decision session.
6. Its decision-session adjusted close is at least `$5`.
7. Its trailing 63-session median adjusted dollar volume is at least
   `$5 million`.
8. The completed `t-12` and `t-1` month-end adjusted closes required by the
   future signal exist.

The price and liquidity floors are conservative feasibility defaults inherited
from M1. The audit must show support immediately above and below both floors.
Neither floor may be changed after momentum or return outcomes are inspected.

## Approved peer cells

A peer cell is one `decision_month x sector x core_cap_tier` group. A cell is
valid only with at least `12` eligible issuers after share-class deduplication.

A month is structurally admissible only when:

- at least `24 / 33` possible core sector-cap cells are valid;
- each of `large`, `mid`, and `small` contains valid cells in at least `8 / 11`
  sectors; and
- no valid cell contains an unresolved future alias, sector backfill, market-
  equity backfill, or unledgered removal.

The feasibility surface passes breadth only if at least 90% of proposed
decision months are structurally admissible. These requirements prevent the
combined result from becoming a disguised test of only a few large sectors or
only the most numerous small stocks.

## Future signal and target shape

No signal or target is authorized in the feasibility slice. If data authority
later passes and the operator opens an outcome contract, the intended frozen
shape is:

```text
momentum_12_1(i,t) = log(adjusted_close(i,t-1) / adjusted_close(i,t-12))

next_month_return(i,t) =
  next_month_following_open(i,t) / following_open_after_t(i,t) - 1

cell_relative_return(i,t) =
  next_month_return(i,t) - mean(next_month_return(eligible peers in cell,t))
```

Ranks are formed separately inside every valid sector-cap cell. Signal inputs
end before the execution-aligned outcome begins. All securities in a cell use
the same scheduled next-open to next-month-next-open interval.

The intended primary measurement is cell-level Spearman rank correlation.
The combined monthly readout gives every valid sector-cap cell equal weight,
not every stock equal weight. Capitalization-tier and sector estimates are
predeclared heterogeneity diagnostics. A strong result in one inspected tier
cannot be promoted without a new untouched interval.

No regression, Ridge fit, feature search, horizon search, volatility scaling,
portfolio construction, transaction-cost claim, allocation, leverage, or live
advice belongs in this first outcome question.

## Microcap challenger boundary

The `micro` tier is retained in the source and coverage audit but excluded from
the core signal question. It may receive a later contract only after the core
data authority is resolved. That contract must add explicit stale-price,
spread, price-impact, capacity, extreme-return, removal, and corporate-action
controls. A microcap result may never be pooled into the core estimate after
inspection.

## Data-admissibility audit

The next authorized technical action, once an in-scope source exists, is a
return-blind audit that writes:

- a source and entitlement manifest with retrieval timestamps, versions,
  URLs or table names, hashes, and explicit `as_of_timestamp`;
- a point-in-time security and issuer ledger;
- listing, symbol, share-class, sector, and market-equity effective-date
  ledgers;
- monthly NYSE size breakpoints;
- monthly eligibility and exclusion counts;
- sector-cap cell counts and structural-admissibility status;
- removed-security and corporate-action coverage counts;
- missingness and source-disagreement tables; and
- a compact sector-by-cap-by-month coverage chart or heatmap.

The audit must not calculate momentum, future return, rank correlation, bucket
return, PnL, Sharpe, drawdown, or any other outcome.

## Data gates

All gates are conjunctive:

| Gate | Requirement |
|---|---|
| F1 Provenance | Exact source, entitlement, table/file version, retrieval timestamp, hash, and explicit as-of recorded |
| F2 Identity | 100% of retained rows have stable issuer/security identifiers and effective-dated symbol history |
| F3 Security type | 100% of retained rows pass the frozen common-equity and primary-listing rules |
| F4 Sector | At least 98% monthly contemporaneous classification coverage; current-label backfill count is zero |
| F5 Market equity | At least 98% monthly point-in-time market-equity coverage, or split-consistent reference-price and shares-outstanding coverage; future backfill count is zero |
| F6 Bars | At least 95% monthly feature-window coverage before price/liquidity filtering |
| F7 Cell breadth | At least 90% of proposed months satisfy the `24 / 33`, `8 / 11` per tier, and `n >= 12` rules |
| F8 Removals | Every observed removal has an explicit event-status ledger; silent deletion count is zero |
| F9 Boundary | All source facts and bar inputs used for eligibility are timestamped no later than the decision; outcome fields are absent |

Any failure records:

```text
STOP_M1_SR1_MULTICAP_DATA_GATES_FAILED_OUTCOMES_NOT_RUN
```

Passing the audit authorizes only a later operator discussion about freezing
the historical evidence window, uncertainty procedure, outcome gates, and
confirmation boundary. It does not automatically authorize outcome access.

## Current data STOP

The repository does not presently contain one authoritative surface that
combines:

- point-in-time US common-stock population and stable identifiers;
- contemporaneous sector history;
- point-in-time shares outstanding sufficient for monthly market equity; and
- corporate-action and removal authority sufficient for scheduled outcomes.

Alpaca adjusted daily bars remain the canonical price surface, but bars alone
do not supply the other authorities. The earlier public S&P 500 audit failed
historical identity, sector, and terminal-outcome gates, while the September
2020 SPY filing supports only a fixed large-cap snapshot rather than a rolling
multi-cap population.

Therefore the active state is:

```text
STOP_POINT_IN_TIME_MULTICAP_AUTHORITY_MISSING
```

Do not install or purchase a provider, add a dependency, substitute current
market caps or sectors, query outcomes, or weaken the audit gates without a
new operator decision.

## Related evidence

- `docs/GEN5_M1_CROSS_SECTIONAL_MOMENTUM_POC_CONTRACT.md`
- `operator_hypothesis_lab/docs/HYP_MOM_04_1_SP500_PIT_DATA_AUDIT_RESULTS.md`
- `operator_hypothesis_lab/docs/HYP_MOM_04_1_DEPLOYMENT_UNIVERSE_RESULTS.md`
- `operator_hypothesis_lab/docs/HYP_MOM_04_3B_SECTOR_RELATIVE_REPLICATION_RESULTS.md`
- `operator_hypothesis_lab/docs/HYP_MOM_04_3C_FEATURE_TRANSPORT_AUDIT_RESULTS.md`
- S&P GICS overview: <https://www.spglobal.com/spdji/en/landing/topic/gics/>
- FTSE Russell ICB overview: <https://www.lseg.com/en/ftse-russell/industry-classification-benchmark-icb>
- Kenneth French size-and-momentum data descriptions:
  <https://mba.tuck.dartmouth.edu/pages/faculty/ken.french/data_library.html>
