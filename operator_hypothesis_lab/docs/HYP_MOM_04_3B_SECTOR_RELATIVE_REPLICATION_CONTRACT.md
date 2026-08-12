# HYP-MOM-04.3B Sector-Relative Temporal Replication Contract

Status: `FROZEN_EXECUTED_STOP`

## Decision carried forward

`SECTOR_RELATIVE` is now the primary target:

`next-quarter stock return - next-quarter mean return of same-sector eligible peers`.

The question is: which stocks will outperform their own sector peers? The
sector-plus-prior-beta residual target remains diagnostic only and cannot
replace the primary target after results are inspected.

## Fresh evidence boundary

- TRAIN: retained H04.2 panel, signal quarters `2017Q1-2020Q3`.
- DEVELOPMENT: `2021Q1-2023Q3`, with targets ending in `2023Q4`.
- SEALED: every observation dated `2024-01-01` or later.
- Universe: the 481 identities that passed the September 2020 SPY deployment-
  cohort TRAIN coverage gate.
- Provider: Alpaca adjusted daily OHLCV only.
- Features at each signal close; entry and exit at next-quarter opens.

## Frozen primary model

One four-feature Ridge model:

1. `sector_relative126` — prior six-month strength versus sector peers;
2. `trend_r2_63` — recent trend quality;
3. `recovery_from_low252` — path recovery; and
4. `positive_month_fraction12` — persistence across monthly blocks.

All features are rank-normalized within signal quarter. Ridge lambda is chosen
once from `0.01, 0.1, 1, 10, 100` using only expanding validation inside the
retained 2017-2020 TRAIN period. No DEVELOPMENT choice is permitted.

Predeclared comparators are a fixed equal-weight rank composite of the same
four positively signed features and prior `sector_relative126` alone.

## Data gate before scoring

For every identity active and feature-eligible at a DEVELOPMENT signal:

- the entry and scheduled exit opens must exist;
- sector must be known and the sector-quarter must contain at least three
  eligible identities;
- no missing terminal outcome may be silently dropped;
- all 11 DEVELOPMENT quarters and at least 400 identities must remain; and
- no source observation may reach 2024.

The cache audit exposed corporate-action endpoints before any DEVELOPMENT
outcome was scored. The terminal policy was therefore fixed as follows:

- ordinary observations exit at the scheduled next-quarter open;
- corporate-action endpoints use the final available adjusted close on or
  before the scheduled exit;
- FRC and SIVB use a conservative zero-recovery convention for their
  receivership-related common-stock endpoints;
- no terminal observation may be silently deleted; and
- realized feature rows must equal signal-eligible rows before scoring.

Any unresolved terminal outcome records
`STOP_DEVELOPMENT_DATA_GATES_FAILED_MODEL_NOT_RUN`. This is a data-feasibility
amendment, not a change to the target, features, model, comparators, or
replication gates.

## Replication gates if data pass

All are conjunctive:

1. mean DEVELOPMENT Spearman IC is positive;
2. at least 7 of 11 quarterly ICs are positive;
3. mean within-sector top-quartile target return is positive;
4. at least 7 of 11 top-quartile target returns are positive;
5. the primary model exceeds both frozen comparators in mean IC; and
6. no sector supplies more than 35% of positive top-quartile contribution.

Passing records `DEVELOPMENT_REPLICATION_PASS_CONFIRMATION_STILL_LOCKED`.
Failure records `STOP_DEVELOPMENT_REPLICATION_FAILED_CONFIRMATION_NOT_RUN`.
Neither state opens 2024+ without a new operator decision.
