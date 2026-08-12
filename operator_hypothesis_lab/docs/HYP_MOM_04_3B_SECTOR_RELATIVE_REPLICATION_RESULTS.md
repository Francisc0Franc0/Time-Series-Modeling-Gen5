# HYP-MOM-04.3B Sector-Relative Temporal Replication Results

Status: `STOP_DEVELOPMENT_REPLICATION_FAILED_CONFIRMATION_NOT_RUN`

## Question

After the H04.3A target audit, does one compact four-feature Ridge model rank
next-quarter stock returns relative to same-sector peers in later data?

## Evidence boundary

- Target: stock next-quarter return minus the eligible same-sector mean.
- TRAIN retained from H04.2: `2017Q1-2020Q3`.
- DEVELOPMENT: signals `2021Q1-2023Q3`, targets through `2023Q4`.
- SEALED: every observation dated `2024-01-01` or later.
- Fixed cohort: 481 identities from the September 2020 SPY filing; 479 were
  signal-eligible in DEVELOPMENT.
- Model inputs: prior sector-relative six-month return, 63-session trend R2,
  252-session recovery from low, and positive-month fraction.

## Data feasibility passed before scoring

The bounded refresh ended on `2023-12-29`. All 11 quarters and 479 identities
were represented. The runner reconciled all `5,124` signal-eligible rows.

Twenty-six rows ended through ticker or corporate-action events before their
scheduled quarter exit. The policy was fixed before model scoring: 24 use the
final available adjusted close and FRC/SIVB use a conservative zero-recovery
convention. The terminal ledger retains every case; none was silently
discarded.

## Result

TRAIN-only expanding validation selected Ridge lambda `10`; even there, all
five candidate lambdas had negative mean validation IC.

In DEVELOPMENT, the primary model produced:

- mean Spearman IC `-0.0342`;
- positive IC in `3 / 11` quarters;
- mean top-quartile sector-relative return `-0.582%`;
- positive top-quartile return in `5 / 11` quarters; and
- largest positive-contribution sector share `16.42%`.

Only the concentration guardrail passed. The primary model also lost to both
frozen comparators:

| Candidate | Mean IC | Positive IC quarters | Mean top-quartile target | Positive top quarters |
|---|---:|---:|---:|---:|
| Four-feature Ridge | -0.0342 | 3 / 11 | -0.582% | 5 / 11 |
| Equal-weight four-feature composite | -0.0083 | 5 / 11 | +0.074% | 5 / 11 |
| Prior sector-relative momentum alone | +0.0042 | 6 / 11 | +0.302% | 7 / 11 |

The simple momentum comparator was directionally better than Ridge but did not
earn promotion: its mean IC was near zero and only 6 of 11 ICs were positive.

## Interpretation

H04.3A improved the economic definition of the target; it did not establish
that the old feature basket contained a durable signal for that target.
H04.3B separates those claims. Sector-relative return remains a cleaner stock-
selection question, while this four-feature linear combination shows negative
temporal transport in the next 11 quarters.

The result also argues against immediately searching many feature subsets.
The next useful work, if reopened, is feature-level temporal diagnosis on the
sector-relative target: measure which individual relationships recur, in what
quarters or environments, and whether any predeclared simple baseline merits a
new lane. It is not permission to tune H04.3B after seeing DEVELOPMENT.

## Decision

Record `STOP_DEVELOPMENT_REPLICATION_FAILED_CONFIRMATION_NOT_RUN`. Do not:

- access 2024+ confirmation outcomes;
- change the four features, lambda grid, target, comparators, or gates under
  `HYP-MOM-04.3B`;
- promote the momentum comparator from this inspected result; or
- treat target clarity as evidence of alpha.

## Artifacts

- Contract: `operator_hypothesis_lab/docs/HYP_MOM_04_3B_SECTOR_RELATIVE_REPLICATION_CONTRACT.md`
- Runner: `operator_hypothesis_lab/scripts/run_hyp_mom_04_3b_sector_relative_replication.R`
- Engine: `operator_hypothesis_lab/R/hyp_mom_04_3b_engine.R`
- Ignored packet: `runs/research_workbench/operator_hypothesis_lab/hyp_mom_04_3b_sector_relative_replication_20260811/`
- Evidence deck: `operator_hypothesis_lab/presentations/hyp_mom_04_3b_sector_relative_replication_evidence.pptx`
