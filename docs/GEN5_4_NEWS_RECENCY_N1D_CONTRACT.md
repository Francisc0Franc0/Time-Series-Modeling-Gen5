# Gen5.4 News Recency Representation N1D Contract

Status: completed frozen confirmation POC;
`STOP_N1D_KEEP_EQUAL_COUNT_AND_CLOSE_REPRESENTATION_EXPANSION`

Decision date: 2026-07-25

Branch: `codex/Gen5.4-ml-decision-engine-plan`

## Purpose

N1B found stable issuer-local ordering between novel-news intensity and future
five-session path volatility. N1C found that the ordering remained positive
after conditioning on recent path volatility and current dollar-volume
surprise. N1D asks one narrower representation question:

> On an untouched six-quarter confirmation window, does a single fixed
> recency-weighted news mass improve conditional uncertainty ordering over the
> accepted equal-count representation?

N1D is a representation audit. It is not a sentiment study, directional-return
model, policy, exposure rule, allocation method, PnL test, or live-advice
change.

## Economic Hypothesis

Two otherwise identical issuer-decision cycles can contain the same number of
novel admissible article clusters while differing materially in timing. An
article arriving shortly before the scheduled decision cutoff may carry more
unresolved information than an article that arrived near the start of the
cycle.

The challenger therefore changes only the within-cycle weighting of accepted
novel article clusters. It does not change which articles are admissible,
their issuer mapping, the novelty rule, the decision clock, the outcome, or the
OHLCV controls.

## Frozen Confirmation Boundary

The six confirmation folds are exactly:

- `2025Q1`
- `2025Q2`
- `2025Q3`
- `2025Q4`
- `2026Q1`
- `2026Q2`

These folds were not used to choose the challenger, half-life, gates, outcome,
controls, or minimum improvement. N1D may not inspect alternate half-lives,
subperiods, issuer subsets, horizons, transforms, or thresholds after opening
this confirmation window.

The population retains:

- the fixed 24-stock retrospective issuer panel;
- permanent issuer identities and point-in-time `FB`/`META` mapping;
- scheduled 17:30 America/New_York decision cutoffs;
- next-open outcome alignment;
- the accepted article-availability rule;
- the 24-hour stale-update exclusion;
- the backward-looking 72-hour exact-title novelty rule;
- issuer-local, fold-local TRAIN empirical calibration;
- the N1C prior-h5 path-volatility and dollar-volume-surprise controls.

The retrospective issuer panel remains a research convenience selected with
historical knowledge. N1D does not convert it into a claim about a
point-in-time investable-universe selection process.

## Frozen Challenger

For each admissible novel article cluster in an issuer-decision cycle, define:

`age_hours = decision_cutoff - article_updated_at`

The fixed weight is:

`weight = 2^(-age_hours / 24)`

The cycle's raw recency mass is the sum of these weights. Thus an article at
the cutoff has weight `1`, after 24 hours has weight `0.5`, after 48 hours has
weight `0.25`, and after 72 hours has weight `0.125`.

The half-life is exactly 24 hours. It was selected before confirmation
inspection as a simple clock-time expression of decaying unresolved
information. No alternate half-life, stepped decay, market-hours clock,
source weight, sentiment score, embedding, relevance model, or event class may
be evaluated in N1D.

Both the accepted equal count and the recency mass are transformed separately
through the issuer's frozen fold-local TRAIN empirical distribution. OOS rows
never contribute to either calibration distribution.

## Frozen Outcome And Controls

The outcome remains the accepted future five-session realized path volatility
beginning at the next executable open, divided by the issuer-fold TRAIN median
of the same strictly positive measure.

The controls remain:

1. relative prior five-session path volatility available at the decision
   cutoff;
2. log current dollar volume relative to the median of exactly the prior 60
   eligible completed sessions.

Within each confirmation quarter, N1D computes the same partial-Spearman
procedure used in N1C separately for:

- the accepted equal-count TRAIN-ECDF representation;
- the fixed 24-hour-recency TRAIN-ECDF representation.

The fold-level difference is:

`delta = recency_partial_rho - equal_count_partial_rho`

## Frozen Gates

The challenger earns candidate-feature status only if all five gates pass:

1. all data, timestamp, population, TRAIN-support, and leakage checks pass;
2. mean recency partial Spearman is positive;
3. recency partial Spearman is positive in at least `4 / 6` confirmation
   quarters;
4. mean fold-level delta versus equal count is at least `0.01`;
5. fold-level delta is positive in at least `4 / 6` confirmation quarters.

These gates require both absolute usefulness and a nontrivial, reasonably
stable improvement over the simpler accepted measurement. A recency
representation that is merely positive but does not improve on equal count
does not earn its additional complexity.

## Interpretation

The only two admissible method decisions are:

- `PASS_N1D_RECENCY_REPRESENTATION_EARNS_CANDIDATE_STATUS`: all five gates
  pass. Recency may enter a separate downstream theory gate as a candidate
  uncertainty feature.
- `STOP_N1D_KEEP_EQUAL_COUNT_AND_CLOSE_REPRESENTATION_EXPANSION`: integrity
  passes but at least one evidence gate fails. Retain equal count and do not
  rescue recency by inspecting alternate half-lives or richer text features
  on these confirmation outcomes.

A data or leakage failure produces
`STOP_N1D_DATA_OR_LEAKAGE_FAILURE` and cannot be interpreted as evidence for
or against the economic hypothesis.

Even a pass would establish only incremental uncertainty ordering on this
retrospective panel. It would not establish causality, return direction,
economic value, a deployable model, exposure, allocation, PnL, or live
authority.

## Authority Result

The completed authority packet is
`runs/research_workbench/gen54_ml_decision_engine/g54_news_n1d_20260725`.
The initial network run refreshed the requested adjusted-bar range and
preserved all 698 historical-news pages. The required hot-cache rerun then
reconstructed both news partitions from raw receipts, cleared the transient
pre-refresh health warning, and produced the admissible result below.

- confirmation observations: `8,232`;
- issuer coverage: all `24 / 24` issuers in every one of the six quarters;
- representation and control TRAIN-support failures: `0`;
- integrity and leakage checks: `15 / 15` passed;
- mean equal-count conditional partial Spearman: `0.038762`;
- mean recency conditional partial Spearman: `0.036938`;
- positive recency quarters: `5 / 6`;
- mean recency-minus-equal-count improvement: `-0.001824`, versus the frozen
  requirement of at least `0.01`;
- positive-improvement quarters: `3 / 6`, versus the frozen requirement of at
  least `4 / 6`;
- alternate decay, sentiment, source-weight, embedding, model, policy,
  exposure, allocation, portfolio-metric, and live-change counts: all `0`.

The recency representation created substantially more distinct issuer-local
TRAIN percentile values, but ordering detail is not itself predictive value.
It passed the three absolute/integrity gates and failed both predeclared
complexity-penalty gates. Record
`STOP_N1D_KEEP_EQUAL_COUNT_AND_CLOSE_REPRESENTATION_EXPANSION`.

Retain the simpler equal-count representation as the descriptive
uncertainty-context measurement. Do not inspect alternate half-lives,
sentiment, source weights, embeddings, or other text representations on these
confirmation outcomes. Any future news hypothesis would require a genuinely
new economic question and fresh uninspected data, not a rescue of N1D.

## Human-Facing Evidence

The authority packet must include:

- a manifest with the fixed clock, folds, half-life, controls, and gates;
- page-level historical-news retrieval receipts and a data-health surface;
- issuer-quarter confirmation coverage;
- TRAIN-support and leakage audits;
- fold-level equal-count, recency, and delta comparisons;
- a fixed-decay curve;
- a tie-resolution view showing what recency changes when counts are equal;
- representative timing pairs selected without future outcomes;
- a compact gate summary;
- a concise report and slide-deck update.

No sentiment, direction, alternate representation, threshold search, model,
policy, exposure, allocation, PnL, or live-facing output belongs in this
packet.
