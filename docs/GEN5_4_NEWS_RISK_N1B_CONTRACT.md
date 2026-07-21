# Gen5.4 News Risk Measurement N1B Contract

Status: completed POC; `PASS_N1B_TO_REPRESENTATION_DISCUSSION`; policy and model gates remain closed

Decision date: 2026-07-21

Branch: `codex/Gen5.4-ml-decision-engine-plan`

## Question

Does unusually high novel-news activity for an issuer order unusually high
five-session post-entry realized volatility, without claiming that news tone
predicts return direction?

N1B is a measurement-only association POC. It is not a trading strategy,
sentiment model, exposure policy, or allocation rule.

## Frozen Hypothesis

When an issuer experiences unusually high novel-news activity relative to its
own TRAIN history, its five-session realized path volatility beginning at the
next executable open tends to be unusually high relative to that issuer's
TRAIN volatility baseline.

The permissible claim concerns the width of the future return distribution,
not the sign of the future return.

## Issuer And Symbol Identity

The fixed 24-stock N1A candidate panel remains retrospective and cannot support
a historical-universe-discovery claim.

`FB` and `META` are one permanent issuer identity, `META_PLATFORMS`, with
point-in-time symbol validity:

- accept `FB` associations through 2022-06-08;
- accept `META` associations from 2022-06-09 onward;
- retrieve both symbol keys and retain the provider's historical symbol in raw
  and normalized provenance;
- never rewrite an old provider association as though the later ticker had
  been transmitted at the earlier date.

All other candidate symbols map one-to-one to their frozen issuer identity for
this POC.

## Archived-Article Availability And Staleness

1. `updated_at` remains the conservative historical availability authority.
2. Exclude an article from the information-arrival measurement when
   `updated_at - created_at` exceeds 24 hours.
3. Retained articles enter at the first scheduled 17:30 America/New_York
   decision cutoff at or after `updated_at`.
4. Execution and outcome measurement begin at the following market session's
   open.
5. Apply the frozen N1A backward-looking 72-hour exact-title clustering rule.
   Repeated articles do not become independent events.

The 24-hour exclusion is a theory decision made before inspecting any market
outcome. It removes archival backfills and very late edits that cannot safely
represent fresh economic information.

## Frozen News Measurement

For each issuer and scheduled decision:

1. Count novel admissible article clusters entering after the prior scheduled
   decision and no later than the current cutoff.
2. Transform the count as `log1p(novel_cluster_count)`.
3. Within each walk-forward fold and issuer, map the transformed value through
   that issuer's TRAIN empirical distribution.
4. Freeze that TRAIN empirical distribution before mapping OOS rows.

The resulting continuous measurement is a symbol-local TRAIN percentile.
Raw article counts may not be compared across issuers. No pooled global
normalizer, OOS refit, expanding OOS distribution, or full-sample percentile is
permitted.

High news intensity is defined before inspection as a nonzero decision-cycle
count whose fixed TRAIN percentile is at least 0.80.

## Frozen Risk Outcome

The single permissible outcome is five-session realized path volatility
beginning at the next executable open:

`sqrt((log(C1 / O1))^2 + sum((log(Cj / C[j-1]))^2, j = 2..5))`

where `O1` and `C1` are the adjusted open and close on the execution session
and subsequent terms are adjusted close-to-close log returns.

Within each fold and issuer, divide this value by that issuer's median TRAIN
five-session realized path volatility. The outcome is therefore relative
future volatility, not raw cross-symbol volatility. The TRAIN median must be
finite and strictly positive.

## Walk-Forward Design

- archive window: 2020-01-01 through 2024-12-31;
- rolling TRAIN: eight complete calendar quarters;
- OOS folds: 2022Q1 through 2024Q4;
- total OOS folds: 12;
- all feature distributions, outcome scales, and thresholds are TRAIN-only;
- purge observations whose five-session outcome path is incomplete or crosses
  a prohibited fold boundary;
- do not tune the window, percentile boundary, outcome horizon, or success
  gates after inspecting results.

## Frozen Success Gates

N1B may advance to a separate representation discussion only when all three
conditions hold:

1. mean fold-level Spearman correlation between news intensity and relative
   future volatility is positive;
2. the fold-level correlation is positive in at least 8 of 12 OOS quarters;
3. high-intensity observations have higher mean relative future volatility
   than other observations in at least 8 of 12 OOS quarters.

Data-health failures, insufficient TRAIN support for an issuer, or an
unresolved N1L live-equivalence failure are STOP conditions, not missing values
to be silently removed.

## Required Human-Facing Evidence

If N1B is later implemented, the packet must include:

- fold manifest and leakage audit;
- issuer-quarter event coverage and eligible observation counts;
- fold correlation and high-versus-other separation tables;
- symbol-local TRAIN percentile calibration examples;
- representative event and future-volatility tapes;
- concise charts showing fold stability and concentration;
- a report and slide-deck update that distinguish association from a usable
  exposure policy.

## Authority Run Readout

The accepted authority packet is
`runs/research_workbench/gen54_ml_decision_engine/g54_news_n1b_20260721`.
It adds 4,757 historical `FB` articles before issuer mapping, unifies `FB` and
`META` under the frozen point-in-time validity windows, and evaluates 24
issuers across 12 quarterly OOS folds. Every issuer has adjusted-bar coverage
from 2019-12-20 through 2024-12-31. The refreshed hot-cache rerun contains zero
material bar warnings, zero issuer-fold TRAIN support failures, and 11 of 11
passing leakage and boundary checks.

All three frozen association gates passed:

- mean fold-level Spearman correlation: `0.107321`;
- positive fold-level Spearman correlation: `12 / 12` quarters;
- positive high-intensity-minus-other separation: `12 / 12` quarters.

The high-intensity definition produced 5,725 eligible OOS issuer-cycles. Its
quarterly share ranged from 24.8% to 46.8%, not exactly 20%, because discrete
article counts create ties at the TRAIN ECDF boundary. That is a representation
limitation to carry forward, not authority to retune the frozen percentile on
the inspected folds.

The result is `PASS_N1B_TO_REPRESENTATION_DISCUSSION`. It establishes a stable
descriptive association between issuer-local news intensity and subsequent
path width. It does not establish return direction, causality, an optimal
threshold, a model, or a usable exposure policy.

## Hard Boundary

Sentiment, embeddings, language models, event taxonomies, directional-return
prediction, horizon search, threshold search, exposure scaling, allocation,
portfolio performance, and live advice remain closed.

N1B implementation does not begin until the separately frozen N1L live-news
feasibility check establishes an operationally reproducible data path or the
operator explicitly accepts a documented limitation.

The first N1L authority run passed all 13 transport and reconciliation gates
but observed no live candidate article during two 120-second connections. A
later premarket shadow run used two 300-second connections and captured one
complete live article that matched the REST overlap by article ID, headline,
and symbol metadata without a same-version conflict. N1L therefore advanced to
`PASS_N1L_LIVE_PATH_READY`, removing the operational data-path STOP.

The live article's local receipt timestamp preceded the provider `created_at`
metadata by approximately six seconds. N1B must therefore keep point-in-time
availability and decision-cycle assignment conservative: local receipt time is
authoritative prospectively, while archived provider timestamps remain
metadata whose boundary behavior requires explicit audit. N1B has now joined
the single frozen uncertainty outcome under these rules; all downstream
representation, model, exposure, allocation, and live-advice decisions remain
separate gates.
