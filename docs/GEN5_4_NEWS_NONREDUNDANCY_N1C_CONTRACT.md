# Gen5.4 News Nonredundancy N1C Contract

Status: completed frozen POC; `PASS_N1C_TO_MINIMAL_REPRESENTATION_DISCUSSION`

Decision date: 2026-07-25

Branch: `codex/Gen5.4-ml-decision-engine-plan`

## Purpose

N1B established that unusually high issuer-local novel-news activity tends to
precede unusually wide five-session price paths. N1C asks the necessary next
question before adding a more elaborate news representation:

> Does the frozen N1B news-intensity measurement retain positive ordering of
> future five-session path volatility after accounting for volatility and
> trading attention already visible in OHLCV at the decision cutoff?

This is a nonredundancy audit. It is not a causal study, sentiment analysis,
directional-return model, exposure rule, allocation method, or trading
backtest.

## Why This Gate Comes Before Recency Weighting

Volatility clusters, and unusually high trading volume often accompanies
important events. The N1B association could therefore arise because the news
count is restating conditions that price and volume already reveal.

Adding recency weights, source weights, text embeddings, sentiment, or event
classes before checking this would increase researcher degrees of freedom
without first proving that news is an incrementally useful information family.

N1C therefore keeps the news representation and future outcome unchanged and
adds only two pre-decision OHLCV controls.

## Frozen Research Population

N1C must begin from the accepted N1B authority population:

- the same fixed 24-stock retrospective candidate panel;
- the same permanent issuer identities and point-in-time `FB`/`META` mapping;
- the same 2020-01-01 through 2024-12-31 archive;
- the same twelve OOS quarters, 2022Q1 through 2024Q4;
- the same eight-complete-quarter rolling TRAIN windows;
- the same scheduled 17:30 America/New_York decision cutoffs;
- the same next-open outcome alignment;
- the same article availability, 24-hour stale-update exclusion, and
  backward-looking 72-hour exact-title novelty rules.

The OOS analysis population must reproduce the N1B eligible issuer-decision
rows. A missing control value is a data-health failure to explain, not a reason
to silently change the population. The long TRAIN history should provide the
required OHLCV lookback for every accepted OOS row.

## Frozen News Measurement

N1C uses the continuous N1B news-intensity value without modification:

1. count novel admissible article clusters entering after the previous
   scheduled decision and no later than the current cutoff;
2. transform the count with `log1p`;
3. map it through the issuer's frozen fold-local TRAIN empirical distribution.

No recency weighting, source weighting, sentiment, embeddings, relevance
model, cross-issuer pooling, threshold search, or change to the p80 diagnostic
is permitted. The p80 high state is not an N1C success criterion; N1C uses the
continuous measurement to avoid making discrete-count ties the research
question.

## Frozen Outcome

The only outcome remains the N1B five-session realized path volatility
beginning at the next executable open:

`sqrt((log(C1 / O1))^2 + sum((log(Cj / C[j-1]))^2, j = 2..5))`

Within each fold and issuer, divide the outcome by that issuer's strictly
positive median TRAIN five-session realized path volatility. No alternate
horizon, return direction, tail label, threshold, or market-relative outcome
may be inspected.

## Frozen OHLCV Controls

Both controls use only information available after the decision session's
close and before the frozen 17:30 cutoff.

### Control 1: prior five-session path volatility

For decision session `t`, calculate:

`sqrt((log(C[t-4] / O[t-4]))^2 + sum((log(C[j] / C[j-1]))^2, j = t-3..t))`

This is the backward-looking analogue of the future-volatility outcome. Divide
it by the issuer's strictly positive median TRAIN value of the same
backward-looking measurement.

This control asks whether news adds information beyond recent realized
turbulence already visible in the price path.

### Control 2: current dollar-volume surprise

For decision session `t`, define adjusted daily dollar volume as:

`DV[t] = adjusted_close[t] * adjusted_volume[t]`

Then calculate:

`log(DV[t] / median(DV[t-60..t-1]))`

The trailing baseline contains exactly the prior 60 eligible completed market
sessions and excludes the current session. It may roll through earlier OOS
sessions because every included value was observable by decision time. No
full-sample baseline, forward fill, winsorization, or tuned lookback is
permitted.

This control asks whether news adds information beyond same-day market
attention already visible in trading activity.

The operator approved these exact formulas before implementation. They were
not changed after outcome inspection.

## Primary Statistic

For each OOS quarter:

1. rank the frozen news intensity, relative future volatility, relative prior
   volatility, and dollar-volume surprise across all eligible issuer-decision
   rows in that fold, using average ranks for ties;
2. regress the news rank on an intercept and the two control ranks;
3. separately regress the future-volatility rank on an intercept and the same
   two control ranks;
4. calculate the Pearson correlation between the two residual series.

That residual correlation is the fold-level partial Spearman correlation.
Both residualizations must use OOS rows only for evaluation; they do not fit a
predictive model or create a deployable transform. The accepted N1B raw
fold-level Spearman values must also be reproduced as a paired integrity
check.

No alternate control subset, nonlinear residualization, interaction,
regularization, clustered pooling rule, or post-hoc robust-statistic
substitution may be inspected.

## Success And Stop Rules

N1C may advance to a separate minimal representation-challenger discussion
only when all three conditions hold:

1. mean fold-level partial Spearman correlation is positive;
2. fold-level partial Spearman correlation is positive in at least 8 of the 12
   OOS quarters;
3. all data, timestamp, population-reproduction, TRAIN-support, and leakage
   checks pass.

The size of the reduction from raw to partial correlation is descriptive, not
a fourth gate. Statistical significance is also not a gate: overlapping
five-session outcomes make naive row-level p-values inappropriate, and twelve
quarterly authorities are too few to justify a fragile significance ritual.

Interpretation is deliberately binary:

- **Pass:** news retains stable incremental ordering beyond the two frozen
  OHLCV controls. Open a new theory session for exactly one predeclared
  representation challenger, with recency weighting the leading candidate.
- **Stop:** the conditional ordering is nonpositive on average or positive in
  fewer than 8 quarters. Stop news feature expansion. Retain raw news only as
  descriptive operator context unless a genuinely new hypothesis and fresh
  confirmation sample are later opened.

N1C may not be rescued by changing controls, horizons, transforms, issuer
subsets, quarters, news thresholds, or article rules after inspection.

## Causal And Economic Interpretation

N1C does not estimate the causal effect of news. Scheduled earnings,
macro announcements, latent firm events, and other omitted variables can
jointly influence news, current OHLCV, and future volatility.

Current volume may also be partly caused by the same news. In causal inference,
controlling for a mediator can answer the wrong causal question. Here that is
intentional: the system-design question is whether news contributes
information not already encoded in the observable tape at the decision cutoff.
If the news measurement merely restates volume or recent turbulence, expanding
it is unlikely to earn its operational complexity.

A pass therefore means **incremental predictive association for uncertainty
ordering**, not causation, unique event identification, return direction, or
tradeability.

## Authority Result

The completed authority packet is
`runs/research_workbench/gen54_ml_decision_engine/g54_news_n1c_20260725`.
It reproduced the accepted N1B OOS population and raw fold correlations, then
applied only the two frozen controls above.

- mean raw N1B fold Spearman: `0.107321`;
- mean conditional N1C fold partial Spearman: `0.087842`;
- mean raw-to-conditional attenuation: `0.019479`;
- positive conditional quarters: `12 / 12`, versus the frozen `8 / 12`
  requirement;
- integrity and leakage checks: `11 / 11` passed;
- issuer-fold TRAIN control-support failures: `0`;
- maximum absolute difference from the accepted N1B raw fold correlations:
  `4.44e-16`;
- material data-health warnings: `0`.

Record `PASS_N1C_TO_MINIMAL_REPRESENTATION_DISCUSSION`. The controls absorb
some of the raw association, as expected, but do not remove its stable
quarterly ordering. The effect remains modest and associational. This result
opens a theory discussion about exactly one minimal representation challenger;
it does not authorize that challenger, a predictive model, an exposure rule,
allocation, PnL analysis, or live behavior.

## Human-Facing Evidence

The N1C packet includes:

- a run manifest identifying the accepted N1B authority and exact population;
- a row-count reconciliation proving the N1B OOS population was reproduced;
- control-definition and availability audits;
- fold-level raw and partial Spearman tables;
- a paired fold chart showing raw versus conditional ordering;
- a compact control-state chart showing where the two OHLCV controls absorb or
  preserve the news relationship;
- representative issuer/event tapes comparing observations with similar prior
  volatility and dollar-volume surprise but different news intensity;
- a leakage and boundary audit;
- a concise report and slide-deck update that distinguishes nonredundancy from
  causality or policy authority.

No PnL, portfolio replay, exposure recommendation, sentiment score, model
probability, or order ticket belongs in this packet.

## Implementation Boundary

The completed implementation reused the accepted N1B authority inputs and
wrote a separate ignored evidence packet; it did not mutate the N1B packet.
No alternate controls, horizons, representation, sentiment, model, policy,
exposure, allocation, PnL, or live-facing behavior were added.

The next STOP gate belongs to the operator: decide in a theory-first session
whether one recency-weighted representation challenger is economically
defensible and can be frozen without using the inspected N1C outcomes to tune
its form. Until that decision is made, representation implementation remains
closed.
