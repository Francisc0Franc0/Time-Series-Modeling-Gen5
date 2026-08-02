# LIT-MOM-01.1 Interday Time-Series Momentum Results

Status: `OOS_DEVELOPMENT_COMPLETE_STOP_RECOMMENDED`

## Question

Can Chan's Chapter 6 workflow—screening a table of past/future return
horizons before choosing a sign rule—produce a causal, cost-aware swing
strategy on an accessible Treasury ETF proxy?

This is a textbook exercise, not a claim that `SHY` reproduces the economics
of the two-year Treasury-note future `TU`.

## What Chan actually does

Example 6.1 does not choose `250/25` from nowhere. Chan first compares:

\[
R_t^{past}(L)=C_t/C_{t-L}-1
\]

with:

\[
R_t^{future}(H)=C_{t+H}/C_t-1
\]

over:

\[
L,H \in \{1,5,10,25,60,120,250\}.
\]

The resulting table leaves several plausible combinations. Chan then uses a
250-session lookback and 25-session hold for `TU`, favoring a roughly
12-month signal with a roughly one-month holding period. This is an informed
literature choice and a bridge to the time-series-momentum study cited in the
chapter; it is not the unique optimum of the displayed table.

## Non-overlap clarification

Daily labels reuse most of the same observations when the outcome spans
multiple sessions. Treating all such rows as independent exaggerates the
effective sample size and makes ordinary Pearson uncertainty too optimistic.

Chan's prose and Figure 6.1 advance anchors by `min(L,H)`. For `250/25`, that
is 25 sessions: future 25-session outcomes no longer overlap, but the
250-session predictors still do. The printed MATLAB condition advances by
`max(L,H)`, which conflicts with the prose and figure. Neither convention
makes both raw return intervals fully independent. The POC therefore reports:

- Chan's `min(L,H)` view as the source-faithful screen;
- an `L+H` strict sensitivity in which neither return interval overlaps; and
- a daily-overlapping view as descriptive only.

This sparse inference convention does not prohibit daily trading. Example 6.1
starts one `1/H` sleeve per session and holds each sleeve for `H` sessions.
Daily sleeves create a smooth implementable position path; they do not create
daily independent statistical evidence.

### Revisit: a distinct-formation `STEP_L` view

The operator subsequently proposed a different, intuitive estimand: partition
the history into nonoverlapping `L`-session formation chunks and ask how
often each chunk's return sign agrees with the following `H`-session return.
This is a valid diagnostic and is labeled `STEP_L`.

`STEP_L` answers a clearer “distinct formation episodes” question than
daily-overlapping rows because one fixed phase does not reuse an `L`-session
lookback. It does **not** make the observations fully independent:

- when `H > L`, adjacent future outcomes can overlap;
- when `H < L`, one pair's future outcome can fall inside the next pair's
  formation interval; and
- a fixed partition has an arbitrary starting phase, so an apparent result can
  depend on which of the `L` possible offsets is used.

It is also sparse for long lookbacks. Roughly 1,000 sessions provide only about
16 distinct `L=60` chunks and four `L=250` chunks before warm-up and endpoint
losses. `STEP_L` is therefore a strong teaching and robustness view, but it
should not automatically replace the source-faithful `CHAN_MIN_STEP` selector
or be given an ordinary independent-sample Pearson p-value.

The per-chunk question is most directly reported as sign consistency:

`sign_consistency = count(sign(R_past_i) = sign(R_future_i)) / N`

Pearson correlation remains one statistic estimated across the full set of
return pairs; an individual chunk is not itself “correlated.”

## Frozen retail translation

- Instrument: `SHY`, the closest Alpaca-tradable adjusted-daily ETF maturity
  proxy inside the opened provider scope.
- Warm-up query: January 4, 2016.
- TRAIN: January 3, 2017 through December 31, 2020.
- DEVELOPMENT: January 4, 2021 through December 29, 2023.
- CONFIRMATION: 2024 onward, unqueried.
- Horizon grid: the source's 49 `L,H` combinations.
- Admissible swing holds: at least five sessions.
- TRAIN selection: at least 20 sparse pairs, then highest Pearson
  correlation t-statistic; exact ties prefer the shorter hold and then the
  shorter lookback. The selected row must have positive correlation and
  nominal `p <= 0.10`.
- Trading: next-open entry, `1/H` daily sleeves, exit after `H` opens, flat
  start in each evidence window, exposure bounded to `[-1,+1]`.
- Primary cost: 5 bp per one-way net turnover.
- Stress: 10 bp per one-way turnover plus 100 bp annual short borrow.

The canonical `250/25` result remains a side-by-side literature reference. It
is not allowed to replace the frozen SHY selection after outcomes.

## TRAIN readout

The frozen selector chose `60/5`:

| Diagnostic | TRAIN result |
|---|---:|
| Chan min-step pairs | 201 |
| Past/future return correlation | 0.2084 |
| Nominal Pearson p-value | 0.0030 |
| Past-sign/future-sign accuracy | 60.2% |
| Completed daily sleeves | 982 |
| Primary cumulative return | +6.55% |
| Autocorrelation-adjusted Sharpe | 1.55 |
| Primary maximum drawdown | -0.84% |
| Stress cumulative return | +4.29% |
| Positive calendar years | 3 of 4 |

All six frozen TRAIN gates passed, so the single predeclared DEVELOPMENT
replay was opened.

The nominal p-value is a screening statistic across 49 related cells. It is
not multiplicity-adjusted proof. DEVELOPMENT is the actual falsification
surface.

## Canonical 250/25 reference

The `250/25` SHY reference had 40 Chan-min-step pairs, correlation `0.2572`,
nominal `p=0.1092`, 55.0% directional accuracy, +5.80% primary return, and
two positive TRAIN calendar years. Under the frozen SHY rules it would not
have replaced the selected `60/5` row and would not independently have cleared
the calendar-stability condition.

## OOS DEVELOPMENT readout

| Diagnostic | 2021–2023 result |
|---|---:|
| Chan min-step pairs | 150 |
| Past/future return correlation | 0.0846 |
| Nominal Pearson p-value | 0.3032 |
| Past-sign/future-sign accuracy | 44.0% |
| Strict `L+H=65` pairs | 12 |
| Strict correlation | -0.4518 |
| Gross cumulative return | +2.22% |
| Primary cumulative return | +0.09% |
| Primary autocorrelation-adjusted Sharpe | 0.03 |
| Primary maximum drawdown | -4.84% |
| Stress cumulative return | -3.56% |

The long and short sleeve books both had negative mean primary-cost returns.
Calendar results were `-1.38%` in 2021, `+1.35%` in 2022, and `+0.13%` in
2023.

The strong-looking TRAIN relationship did not persist statistically or
economically. Ordinary costs consumed almost all gross progress; stress costs
made the result negative.

## Explicit long/short sleeve audit

The strategy's directional prediction and its implementable economics are
separate questions:

| Evidence window | Direction | Completed sleeves | Direction accuracy | Mean gross per sleeve | Mean primary net per sleeve |
|---|---|---:|---:|---:|---:|
| TRAIN 2017-2020 | Long | 770 | 60.3% | +5.1 bp | -4.9 bp |
| TRAIN 2017-2020 | Short | 212 | 44.8% | -0.4 bp | -10.4 bp |
| OOS 2021-2023 | Long | 299 | 47.2% | +1.3 bp | -8.7 bp |
| OOS 2021-2023 | Short | 442 | 51.1% | +1.6 bp | -8.4 bp |

The TRAIN relationship was primarily a long-side phenomenon. It did not
survive OOS: long accuracy fell below 50%. OOS short calls were slightly above
50% and both directions were mildly positive gross, but neither direction
covered the frozen ordinary round-trip cost. This makes clear why hit rate,
gross predictive direction, and net strategy P&L must all be reported.

The deck now includes:

- an actual OOS opening sequence showing each separately recalculated daily
  signal and the net of still-active sleeves; and
- a TRAIN-versus-OOS long/short scorecard showing support, accuracy, and gross
  versus primary-cost mean return.

Both visuals are reproducible from the frozen packet with:

`literature_studies/scripts/render_gen5_lit_mom_01_1_revisit_audit.R`.

## Boundary for the proposed simplified variant

No all-capital, single-position variant is implemented in this revision.
The operator has opened discussion of a possible `LIT-MOM-01.2` whose
horizon remains selected from a grid and whose execution enters the full
position on one signal, holds for `H` sessions, and then exits. Reusing the
2021-2023 window is acceptable for that learning exercise, but it must be
labeled `RETROSPECTIVE_EXPLORATION`, not fresh OOS confirmation. The
selection/inference convention remains the last freeze decision before that
lane is built.

## Decision

Record:

`OOS_DEVELOPMENT_COMPLETE_LIT_MOM_01_1`

Recommend:

`STOP_BEFORE_CONFIRMATION`

The exercise succeeded as a reconstruction of the literature workflow. It did
not produce durable OOS evidence for this retail proxy. Do not rescue it by
reselecting a horizon on DEVELOPMENT, replacing `SHY`, changing the sign,
costs, sleeve construction, or evidence boundary. Keep 2024+ CONFIRMATION
sealed and move to the next Chapter 6 exercise.

## Data-health transparency

The authoritative packet contains complete requested `SHY` and `SPY` coverage
for January 2016 through December 2023: 2,012 sessions per symbol, with all
six custom coverage checks passing. The generic workbench health file reports
`stale_symbol` because this deliberately bounded historical cache ends before
the July 2026 as-of date. That warning does not indicate a hole in the
requested TRAIN or DEVELOPMENT windows.

Preliminary packets ending `_v2` and `_v3` are invalid because the requested
2015 history was unavailable and made 2016 an uninvested warm-up artifact.
The authoritative packet is:

`runs/research_workbench/literature_grounded/lit_mom_01_1_interday_momentum_20260730_v6/`

## Human-facing evidence

- Report:
  `runs/research_workbench/literature_grounded/lit_mom_01_1_interday_momentum_20260730_v6/lit_mom_01_1_report.md`
- Deck:
  `literature_studies/presentations/gen5_lit_mom_01_1_interday_momentum_evidence.pptx`
- Contract:
  `literature_studies/docs/GEN5_LIT_MOM_01_1_INTERDAY_TIME_SERIES_MOMENTUM_POC_CONTRACT.md`
