# LIT-MOM-01.4 Multi-Market Horizon-Surface Predictor Atlas Contract

Status: `FROZEN_IMPLEMENTATION_APPROVED_RESULTS_UNREAD`

Frozen on `2026-08-21` after the operator approved broadening the stopped
single-SPY `LIT-MOM-01.3` predictor test to a diverse, outcome-blind atlas.
No `01.4` predictor or target outcome was queried before this contract.

## Place in the research progression

`LIT-MOM-01.3` proved that the direct predictor-only engine can be executed
without strategy contact. Its frozen 2017-2023 SPY surface failed the global
search-adjusted gate, so no SPY horizon was nominated and 2024-2025 remained
sealed.

`LIT-MOM-01.4` asks whether that null is asset-specific. It preserves the same
continuous trailing-return predictor, causal next-open target, and 28-cell
horizon surface, but changes the inference architecture. Horizon discovery is
confined to 2017-2020; exactly one independently tested cell per asset may
enter 2021-2023 DEVELOPMENT. False-discovery-rate control is applied across
assets only after this sample split.

This is a predictor atlas, not a strategy atlas. Its visible output will be a
multi-market evidence packet, asset/category maps, and a bounded list of any
fixed-cell transport candidates.

## Research question

Across a diverse, previously frozen set of currently tradable U.S.-listed
market exposures, does any asset's own past return positively predict its own
causally attainable future return after independent horizon selection and
within-stratum false-discovery control?

## Frozen registry

Reuse every row of:

`literature_studies/registries/gen5_lit_mom_02_1_opening_gap_atlas_registry.csv`

The file contains exactly 92 instruments and has frozen SHA-256:

`69C481DCB8443AADC30D8BF10FC7FFB7EC23D193CE88A992E42F8529225E4737`

The registry was assembled before the opening-gap atlas outcomes and is reused
in full. No symbol may be added, removed, or replaced because of remembered
performance, apparent momentum, volatility, later fame, or `01.4` results.

Freeze three analysis strata:

1. `PLAIN_ETF`: all 68 ETF rows outside `Leveraged or inverse ETF`;
2. `ENGINEERED_ETF`: all six `Leveraged or inverse ETF` rows; and
3. `STOCK_CHALLENGER`: all 18 `Stock` rows.

`SPY` is a locked reproduction reference. Its rows and diagnostics must be
reported, but its already inspected history cannot produce an `01.4`
candidate and it is excluded from false-discovery calculations.

The plain-ETF stratum is the primary evidence family. Engineered products are
kept separate because daily reset, leverage, inverse exposure, financing, and
path dependence can create product-specific behavior. The stock stratum is a
secondary currently tradable challenger with an explicit survivor limitation;
it is not a point-in-time historical equity-universe claim.

## Instrument and provider boundary

- Provider: Alpaca only.
- Bar type: adjusted daily OHLCV only.
- Symbols: exactly the frozen 92-row registry.
- Explicit design as-of timestamp:
  `2026-08-21 17:30:00 America/New_York`.
- Query start: `2016-01-04`.
- Maximum query end in this execution: `2023-12-29`.
- Refresh is permitted only to complete that bounded historical range.

Commodity, currency, rate, and international-equity ETFs are U.S.-listed
tradable proxies. They do not reproduce native futures rolls, futures margin,
interbank FX, local-market closes, or continuous-contract economics. Native
futures, spot FX, crypto, and intraday bars remain outside this provider and
hypothesis contract.

## Frozen predictor and target surface

For adjusted close `C` and adjusted open `O`, define:

\[
X_{t,L}=\log(C_t/C_{t-L})
\]

and the causal target known only after the next session opens:

\[
Y_{t,H}=\log(O_{t+1+H}/O_{t+1}).
\]

Freeze:

\[
L \in \{1,5,10,25,60,120,250\}
\]

and:

\[
H \in \{5,10,25,60\}.
\]

For each asset and cell estimate:

\[
Y_{t,H}=\alpha_{L,H}+\beta_{L,H}X_{t,L}+\epsilon_{t,L,H}.
\]

Every cell inside an asset/period uses one common anchor panel requiring all
250 prior closes and all 60 future open intervals. The search score is Pearson
correlation `rho[L,H]`; `beta[L,H]` is the reported effect size. The canonical
Chan `250/25` cell remains a reference without selection preference.

## Mechanical data eligibility

Eligibility is determined without using return signs or magnitudes. An asset
must have:

- exact adjusted-daily identity and no duplicate sessions;
- finite positive adjusted opens and closes;
- bounded coverage from no later than `2016-01-04` through at least
  `2023-12-29`;
- no row on or after `2024-01-02` in the execution input;
- at least 600 common TRAIN anchors and 600 common DEVELOPMENT anchors; and
- all 28 unique cells constructible in each period.

All registry rows remain in the coverage report. An ineligible row receives a
frozen reason and is never replaced. Data-health `WARN` states that affect the
requested 2016-2023 window require refresh and rerun before interpretation.
A cache stale only relative to dates after the requested end is provenance,
not a coverage failure.

## Stage A: TRAIN horizon discovery

- Earliest signal anchor: `2017-01-03`.
- Every target exit open must be on or before `2020-12-31`.

For each eligible asset, compute all 28 cells and nominate the cell with the
largest strictly positive TRAIN correlation. Exact ties prefer shorter `H`,
then shorter `L`. If every TRAIN correlation is nonpositive, record
`NO_POSITIVE_TRAIN_CELL` and test no DEVELOPMENT hypothesis for that asset.

TRAIN significance is deliberately not a gate. TRAIN selects one hypothesis;
the independent period tests it. This avoids applying an unnecessarily harsh
maximum-statistic threshold twice while preserving full protection against
post-DEVELOPMENT horizon selection.

## Stage B: fixed-cell DEVELOPMENT transport

- Earliest signal anchor: `2021-01-04`.
- Every target exit open must be on or before `2023-12-29`.

For every TRAIN nominee, evaluate exactly its frozen `(L,H)` cell. No other
DEVELOPMENT surface may replace it.

Primary fixed-cell inference uses every unique circular shift of the target
whose shortest circular displacement is at least 60 sessions. The observed
statistic is the fixed-cell correlation. The one-sided empirical probability
is:

\[
p=(1+\#\{\rho_{shift}\geq\rho_{obs}\})/(1+N_{shift}).
\]

Apply Benjamini-Hochberg adjustment at `q=0.10` separately within
`PLAIN_ETF`, `ENGINEERED_ETF`, and `STOCK_CHALLENGER`, using every eligible
non-SPY TRAIN nominee in the stratum. Negative and null DEVELOPMENT outcomes
remain in the adjustment family.

An asset becomes an `FDR_CONTROLLED_DEVELOPMENT_TRANSPORT_CANDIDATE` only if:

1. its fixed DEVELOPMENT `rho > 0`;
2. its fixed DEVELOPMENT `beta > 0`; and
3. its within-stratum BH-adjusted probability is `<= 0.10`.

Freeze a 10,000-draw stationary-block bootstrap of the ordered fixed-cell rows
with expected block length 60. Use deterministic seed
`2026082104 + registry_order`. Report the percentile 90% beta interval and a
null-centered one-sided bootstrap probability as diagnostics. The interval is
not an extra DEVELOPMENT veto; the independent fixed-cell shift probability
and BH adjustment are the single transport gate.

## Locked confirmation

- Signal anchors begin no earlier than `2024-01-02`.
- Target exit opens must be on or before `2025-12-31`.
- No confirmation bar may be queried during the initial atlas execution.
- Confirmation requires a later explicit operator gate after the complete
  DEVELOPMENT packet and implementation freeze.
- Only fixed DEVELOPMENT candidates may enter, with unchanged symbol, cell,
  predictor, target, bootstrap, direction, and stratum.

If confirmation is later opened, repeat the fixed-cell circular-shift test
with the same 60-session minimum displacement and BH `q=0.10` separately by
the already frozen strata. A candidate confirms only if `rho > 0`, `beta > 0`,
the within-stratum BH probability is `<= 0.10`, and its stationary-bootstrap
90% beta lower bound is strictly positive.

All targets entering or exiting in 2026 remain outside this contract.

## Required diagnostics

1. Registry checksum, row counts, stratum assignments, and complete coverage
   ledger including ineligible assets.
2. Reproduction of the stopped SPY surface and a clear noncandidate label.
3. All 28 TRAIN correlations and slopes for every eligible asset.
4. One frozen TRAIN nominee row per eligible asset or an explicit no-positive
   status.
5. Fixed-cell DEVELOPMENT pairs, effect estimates, shift probabilities,
   bootstrap intervals, and BH values.
6. Category and stratum summaries of positive/negative transport, candidate
   counts, median effects, and support.
7. TRAIN-versus-DEVELOPMENT scatter and horizon-selection maps.
8. Candidate predictor/target scatter, quintiles, calendar years, phase
   offsets, and neighboring TRAIN cells.
9. Canonical `250/25` rows by asset and category.
10. Masked analytical IDs in intermediate computation; ticker mappings may be
    restored only in the completed packet.

Diagnostics explain the gate. They may not rescue a failed BH value, remove a
negative asset from a family, or promote a category by visual inspection.

## Interpretation map

- **No FDR-controlled transport:** no stratum contains a DEVELOPMENT candidate.
  Record `STOP_LIT_MOM_01_4_NO_FDR_CONTROLLED_TRANSPORT`, preserve
  confirmation, and stop.
- **Isolated candidate:** one or more assets pass inside a stratum without
  broad category support. Freeze them as asset-specific discovery evidence;
  do not claim a universal mechanism.
- **Category breadth:** multiple assets in one economic category transport
  with aligned effects. Report stronger mechanism breadth, but do not bypass
  confirmation.
- **Engineered-only evidence:** candidates appear only among leveraged or
  inverse ETFs. Attribute the result first to product mechanics, not the
  underlying market.
- **Stock-only evidence:** candidates appear only in the survivor-limited stock
  stratum. Do not generalize to a historical stock universe.
- **Confirmation success or failure:** applies only after a later explicit
  gate and cannot reopen horizon or asset selection.

## Explicitly closed work

This contract does not authorize:

- any asset outside the frozen checksum registry;
- any horizon outside the frozen 28-cell surface;
- deletion or substitution after coverage or outcomes;
- a mega-maximum gate across all 2,576 cells;
- reversal nomination from negative results;
- thresholds, positions, entries beyond the target definition, exits, sleeves,
  costs, turnover, P&L, Sharpe, drawdown, allocation, or portfolio replay;
- native futures, FX, crypto, options, or intraday data;
- 2024-2025 access during the initial execution; or
- advice, leverage policy, live execution, or production behavior.
