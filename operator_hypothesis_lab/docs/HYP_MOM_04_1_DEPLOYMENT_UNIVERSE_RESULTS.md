# HYP-MOM-04.1 Deployment-Universe Audit and TRAIN Results

Status: `STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN`

## Question and correction

This sub-lane asked whether the unchanged `HYP-MOM-04.1` Ridge experiment
could be repeated on a broad, externally defined cohort that was publicly
knowable before the retrospective `2021-2023` OOS interval.

The initially discussed `2020-12-31` SPY holdings report is inadmissible for
that purpose: the SEC did not accept it until February 2021. The authoritative
cohort therefore comes from SPDR S&P 500 ETF Trust Form N-PORT accession
`0001752724-20-236128`, reporting holdings on `2020-09-30` and filed in
November 2020. This is a fixed deployment-date cohort, not historical S&P 500
membership.

The SEC's official N-PORT archive is named by dissemination quarter. Because
the September report was filed in November, the exact accession appears in
the `2020 Q4` archive rather than the `2020 Q3` archive. The complete archive
and exact retained accession rows were hashed in the ignored evidence packet.

## Source reconciliation

The filing contained `505` equity holdings. SPY supplied ISIN and CUSIP values
but no ticker values in the identifier table. The audit therefore reconciled
the filing against Wikipedia revision `980783480`, timestamped
`2020-09-28T12:34:09Z`, the last revision before the frozen September 30
cutoff.

- `465` holdings matched by deterministic legal-name normalization;
- `37` additional aliases or share classes used a pinned, reviewable
  filing-title/CUSIP to contemporaneous-symbol crosswalk;
- `3` late-September filing additions remained unresolved and visible; and
- `502 / 505` identities and sectors resolved without a later roster.

Counting the three unresolved filing identities distinctly, roster Jaccard was
`0.9882`; identity and sector completeness were each `99.41%`. No unresolved
identity was replaced with a current symbol or outcome-convenient stock.

## Bounded provider audit

Only Alpaca adjusted daily bars through `2020-12-31` were queried. The audit
found:

- some provider history for `502 / 505` filed holdings (`99.41%`); and
- exact coverage for every SPY session from `2016-01-04` through `2020-12-31`
  for `481 / 505` holdings (`95.25%`).

All nine frozen universe gates passed, including the `95%` provider-history
and `80%` exact-TRAIN thresholds. Twenty-one partial histories and three
unresolved identities remained in the audit ledger but were excluded from the
model registry without replacement. No `2021+` observation entered the audit.

## Unchanged Ridge TRAIN

The passing audit authorized the original `HYP-MOM-04.1` TRAIN procedure. No
feature, target, lambda, fold, gate, or selection mechanic changed:

- `481` complete identities across the fixed deployment cohort;
- the original six trend-state features and next-quarter relative-return
  target;
- `15` TRAIN signal quarters through `2020Q3`;
- `7,208` asset-quarter rows after the original minimum-sector-member rule;
- the original five-lambda grid and one-standard-error selection rule; and
- the original full-procedure 500-draw within-quarter permutation control.

The one-standard-error rule again selected `lambda = 100`. The pooled final
fit looked attractive:

- mean top-quartile relative return: `+1.45` percentage points per quarter;
- mean quartile-4 minus quartile-1 spread: `+3.01` points;
- positive top-quartile excess in `9 / 15` quarters;
- permutation percentile: `100%`; and
- maximum positive-contribution sector share: `21.61%`.

These are pooled TRAIN descriptions, not chronological validation.

## Temporal transport failed

Every lambda produced negative mean expanding-validation IC. At the selected
`lambda = 100`:

- mean held-out Spearman IC was `-0.0623`;
- only `4 / 9` validation quarters were positive; and
- quarter IC ranged from `-0.2905` in `2020Q3` to `+0.1233` in `2020Q2`.

Gate G3 required positive mean IC and at least `60%` positive validation
quarters. It failed both conditions. The other six TRAIN gates passed.

The contrast in `2020Q3` is particularly instructive: the model refit on all
TRAIN quarters describes that quarter as unusually favorable, while the model
trained only on earlier quarters ranked it backward. The pooled permutation
result therefore cannot override the chronological failure.

## Decision

Record `STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN`.

- The fixed deployment cohort solved data feasibility, not temporal
  generalization.
- No `2021-2023` bar, score, selected portfolio, return, Sharpe, drawdown, or
  trade tape was queried or created.
- Preserve `HYP-MOM-04.1` unchanged. Do not relax G3 or reinterpret six of
  seven model gates as a near-pass.
- A simpler fixed-sign composite, reduced feature set, or rolling model would
  require a new identifier and contract frozen before later outcomes.

Evidence lives under:

- `runs/research_workbench/operator_hypothesis_lab/hyp_mom_04_1_deployment_universe_data_audit_20260811/`; and
- `runs/research_workbench/operator_hypothesis_lab/hyp_mom_04_1_deployment_universe_train_20260811/`.
