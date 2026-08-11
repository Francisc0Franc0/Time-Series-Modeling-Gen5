# HYP-MOM-04.1 S&P 500 Point-in-Time Source-Repair Results

Status: `STOP_SP500_PIT_SOURCE_REPAIR_INCOMPLETE_FALLBACK_DISCUSSION_OPEN`

## Question

Can an accessible data source repair the three failed
`SP500-PIT-DATA-AUDIT-01` gates without lowering a threshold, dropping an
inconvenient security, or changing the `HYP-MOM-04.1` model?

## What was attempted

The existing Alpaca credentials were used for one read-only request to the
official corporate-actions endpoint:

`https://data.alpaca.markets/v1/corporate-actions`

The request covered the 39 unresolved audit identities from `2017-01-01`
through `2020-12-31` and requested name changes, cash mergers, stock mergers,
mixed cash-and-stock mergers, spin-offs, redemptions, worthless removals, and
rights distributions. The endpoint returned HTTP 200.

Alpaca documents support for those action types and exposes fields such as the
old/acquiree symbol, successor/acquirer symbol, effective date, exchange ratio,
and cash rate when available:

https://docs.alpaca.markets/us/v1.1/reference/corporateactions-1

## Result

Only eight records matched the 39 unresolved identities:

- four name changes: `CBS -> VIAC`, `CTL -> LUMN`, `JEC -> J`, and
  `UTX -> RTX`;
- one mixed merger: `AGN -> ABBV` plus cash; and
- three stock mergers: `ETFC -> MS`, `MYL -> VTRSV`, and `NBL -> CVX`.

The exact event IDs and terms are retained in:

`operator_hypothesis_lab/registries/hyp_mom_04_1_alpaca_corporate_action_probe_2017_2020.csv`

This is source evidence, not eight automatically accepted returns. Each event
would still require successor-price alignment and holding-rule valuation.
Even if all eight were accepted, at least 31 of 39 unresolved frozen targets
would remain. The terminal-event completeness gate therefore cannot pass.

The endpoint result also does not repair the historical alias/identity or
contemporaneous sector-coverage failures.

## External source feasibility

| Source | What it could contribute | Access observed here | Decision |
|---|---|---|---|
| S&P DJI SPICE / Data Services | Official historical constituents, identifiers, GICS classifications, and index corporate events | Subscription and authenticated account required; no project entitlement found | Conceptually strongest membership/sector authority, not currently accessible |
| CRSP through WRDS | Permanent identifiers and researched delisting amounts/returns | No WRDS credentials or local client found | Strong terminal-return authority, but a separate licensed S&P membership source would still be required |
| Norgate Data Platinum/Diamond | Historical S&P 500 membership plus delisted-security histories and symbol maintenance | No installation or subscription found | Promising practical research product, but sector-history and exact terminal valuation would still need a fresh audit |
| EODHD | Historical index-constituent and delisted EOD products | No API credential found; relevant products are subscription services | Potential challenger, but the inspected public documentation does not by itself prove all three frozen gates |
| Alpaca corporate actions | Existing-provider event terms | Accessible; 8 / 39 unresolved identities returned | Useful supplement, insufficient repair |

Primary vendor references:

- S&P DJI API data services:
  https://www.spglobal.com/spdji/en/landing/topic/api-data-solutions/
- S&P DJI SPICE history and event coverage:
  https://www.spglobal.com/spdji/en/landing/topic/spice/
- CRSP delisting-data description:
  https://wrds-www.wharton.upenn.edu/documents/399/Data_Descriptions_Guide.pdf
- Norgate historical-constituent coverage:
  https://norgatedata.com/data-content-tables.php
- EODHD delisted-security documentation:
  https://eodhd.com/financial-apis/delisted-stock-companies-data-2

## Decision

Retain:

`STOP_SP500_PIT_DATA_GATES_FAILED_REPLICATION_NOT_RUN`

Add:

`STOP_SP500_PIT_SOURCE_REPAIR_INCOMPLETE_FALLBACK_DISCUSSION_OPEN`

No Ridge fit, lambda selection, score, 2021+ target, vendor installation,
trial enrollment, purchase, or provider substitution was performed.

## Recommended fallback for discussion

The recommended next lane is a **deployment-date-conditioned broad-universe
replication**, not another claim of historical point-in-time S&P 500
membership.

Provisional identifier:

`HYP-MOM-04.1 / DEPLOYMENT_UNIVERSE_REPLICATION_01`

Recommended universe authority:

1. use the complete SPDR S&P 500 ETF Trust holdings in the SEC-filed Form
   N-PORT for `2020-12-31`, accession `0001752724-21-043869`;
2. retain every common-stock holding that maps uniquely to an Alpaca identity;
3. use a pinned contemporaneous `2020-12-31` sector snapshot;
4. freeze the resulting identities before inspecting any 2021+ outcome; and
5. keep all six features, Ridge mechanics, TRAIN folds, lambda grid, gates,
   costs, and OOS policy unchanged.

This would answer:

> For the broad stock universe actually known at the 2020 deployment date,
> does the model trained on those securities' pre-2021 histories generalize
> into unseen 2021-2023 quarters?

It would **not** answer whether the model worked across the historical S&P 500
opportunity set in 2017-2020. Conditioning the training panel on membership at
the deployment date is a survivorship/sample-selection limitation, although
the 2021+ OOS outcomes remain genuinely unseen.

This full snapshot is preferable to expanding the prior hand-curated 122-name
registry because it is broader, reproducible, and selected by one external
date-stamped source rather than by model outcomes. It should still receive a
new universe-feasibility audit before any Ridge run, especially for sector
coverage, pre-2021 history, and post-2020 terminal events.

The main alternative is an ETF breadth lane. It would reduce issuer-terminal
risk, but replacing GICS sector-relative momentum with an ETF taxonomy changes
a feature mechanic and therefore warrants a new concept identifier rather
than an `04.1` replication.
