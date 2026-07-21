# Gen5.4 News Admissibility N1A Contract

Status: completed; `PASS_N1A_ADMISSIBLE_FOR_N1B_DISCUSSION`

Decision date: 2026-07-21

Branch: `codex/Gen5.4-ml-decision-engine-plan`

## Question

Can Alpaca's historical news archive support a conservative, point-in-time
symbol-session event panel across the fixed Gen5.4 24-stock universe before any
news measurement is compared with market outcomes?

N1A is an admission and density audit. It is not a sentiment test, a return or
risk study, or a model-fitting exercise.

## Frozen Economic Role

The first permissible news hypothesis is information arrival, not directional
tone. A later measurement POC may ask whether unusually intense new information
orders future post-entry uncertainty or volatility. It may not assume that a
positive-sounding headline predicts a positive return.

## Frozen Universe And Window

Use the existing 24 ranked candidates from the Gen5.4 cross-sectional POC:

- semiconductors: `AMD`, `NVDA`, `AVGO`, `MU`, `QCOM`;
- platforms/media: `AAPL`, `MSFT`, `META`, `AMZN`, `NFLX`;
- high-beta/special situations: `TSLA`, `MSTR`;
- defensive consumer/health: `KO`, `PEP`, `WMT`, `COST`, `JNJ`, `UNH`;
- financials: `JPM`, `BAC`, `GS`;
- energy/industrial: `XOM`, `CVX`, `CAT`.

The audit window is 2020-01-01 through 2024-12-31, partitioned by calendar
year for resumable retrieval. Candidate identities remain retrospective and
cannot support a historical-universe-discovery claim.

## Point-In-Time Rules

1. Treat `updated_at` as the conservative availability timestamp. `created_at`
   remains provenance, not authority for archived headline or summary text.
2. The operational signal cutoff is 17:30 America/New_York on trading
   sessions. An article is assigned to the first scheduled cutoff at or after
   `updated_at`.
3. News arriving after a session cutoff, on a weekend, or on a market holiday
   enters the next scheduled after-close decision. Its hypothetical execution
   session is the following trading session.
4. A current archived article whose update occurs after an earlier cutoff is
   not backdated to its creation time. N1A records whether creation and update
   would map to different decision sessions.
5. The Alpaca market calendar supplies session dates. No price, volume, return,
   or other OHLCV field is joined to news.
6. Article IDs must be unique after yearly packets are combined. Multi-symbol
   articles remain one article and may create one association row per requested
   symbol.

## Deterministic Duplicate Rule

Normalize headlines by lowercasing, transliterating to ASCII where possible,
removing punctuation, and collapsing whitespace. Within an identical normalized
headline, a later article is a repeat of the earliest still-prior article when
the update gap is no more than 72 hours. This is a backward-looking exact-title
rule only. N1A does not use embeddings, semantic similarity, LLM classification,
or future articles to decide whether the current article is new.

## Frozen Outputs

The ignored authority packet must include:

- run specification, yearly request and page manifests, and raw response paths;
- article-level admissibility rows with creation/update delay and assigned
  decision and execution sessions;
- article-to-candidate association rows;
- symbol-year and symbol-quarter coverage tables;
- representative exact-title repeat clusters;
- severity-labeled health and gate tables;
- coverage heatmap, update-delay distribution, event-density distribution,
  revision-crossing summary, and representative duplicate-cluster visual;
- a compact human-readable report and slide-deck addendum.

## Frozen Admission Gates

N1A passes only when all hard gates pass:

- every request page returns HTTP 200 and pagination exhausts cleanly;
- article IDs, headlines, `created_at`, and `updated_at` are complete;
- combined article IDs are unique;
- every update delay is non-negative;
- every article can be assigned to a decision session and a later execution
  session;
- in each calendar year, at least 20 of 24 symbols have at least 20 novel
  exact-title clusters;
- no one symbol supplies more than 25% of all candidate-association rows;
- no more than 50% of article rows are backward-looking exact-title repeats.

The audit records a WARN when more than 25% of rows are repeats or more than 10%
of articles cross a decision cycle between creation and final update. A WARN is
not silently accepted as research authority; the operator decides whether it
changes the next gate.

## Hard Boundary

Sentiment, embeddings, event taxonomies, features, labels, outcomes, OHLCV
joins, correlations, portfolio results, model fits, allocation, and live advice
remain zero. Passing N1A would authorize discussion of one measurement-only N1B
hypothesis; it would not authorize N1B implementation automatically.

The historical REST archive remains a current archive snapshot rather than a
documented version-by-version replay. Even a passing N1A is preliminary
historical research evidence. Prospective equivalence eventually requires a
separate real-time shadow archive with local receipt timestamps.

## N1A Readout

The completed packet retrieved 95,126 articles across 1,904 HTTP 200 pages and
five yearly partitions. It produced 130,695 candidate-association rows over
1,258 Alpaca market sessions. All nine frozen hard gates passed and neither
predeclared WARN threshold fired:

- article IDs and required timestamps/headlines were complete and unique;
- all update delays were non-negative and all rows received a decision and
  execution session;
- the minimum yearly density result was 23 of 24 symbols meeting 20 novel
  exact-title clusters;
- maximum single-symbol association share was 19.29%;
- backward-looking exact-title repeats were 1.76%;
- creation-to-final-update decision-cycle crossings were 1.01%.

Detailed inspection exposed three limitations that do not overturn the frozen
gate result but must constrain any N1B contract:

1. `META` had zero novel clusters in 2020 and 12 in 2021 under the current
   symbol key. This is a symbol-history discontinuity, not evidence of no news.
2. The five most-covered symbols supplied 60.15% of candidate associations.
   Raw article counts are not cross-sectionally comparable; any later intensity
   measure requires symbol-local, TRAIN-only normalization.
3. The archive has a small long-update tail: 630 articles exceeded a 24-hour
   creation-to-update delay, 159 exceeded 30 days, and 39 exceeded one year.
   Delaying them to `updated_at` is leakage-conservative, but treating them as
   fresh information arrival would be economically wrong without an additional
   frozen staleness rule.

No sentiment, feature, outcome, OHLCV join, correlation, portfolio calculation,
or model was created. The result opens N1B theory discussion only.
