# Return-Geometry Wide Atlas (2018-2023)

## Question

Does the cumulative loss-rebound plateau observed in the frozen 30-asset
atlas survive a much wider, sector-balanced atlas through 100 sessions when
the complete existing regime vocabulary is retained?

## Why this slice

The 30-asset atlas showed that the signed-down loss-rebound morphology was not
peculiar to TSLA. The subsequent sparse boundary probe showed no cumulative
boundary by 100 sessions. Neither result provided deep representation within
economic sectors, and the five-name behavioral groups were too small to tell
whether repetition was concentrated in a few related assets.

This slice therefore expands breadth while freezing the already inspected
measurement grammar. It is a transport/falsification exercise, not a search
for the best asset, state, or horizon.

## Frozen atlas

The registry contains 129 unique instruments:

- 88 core stocks: eight names in each of the 11 top-level GICS sectors;
- 16 separately labeled attention/meme challengers;
- 15 broad or sector equity ETF controls; and
- 10 fixed-income, commodity, and currency proxies.

Only the 88-stock core enters the equal-sector headline. Each sector first
receives an equal-asset median and the 11 sector summaries then receive equal
weight. The attention sleeve is not a synthetic sector and cannot change the
sector-balanced result.

GICS provides an explicit 11-sector top level and is maintained jointly by
S&P Dow Jones Indices and MSCI. The sector labels in this atlas are frozen
current research metadata, not point-in-time membership histories. Sources:

- <https://www.spglobal.com/spdji/en/landing/topic/gics/>
- <https://www.spglobal.com/spdji/en/documents/methodologies/methodology-gics.pdf?force_download=true>

## Measurement contract

- Provider: Alpaca SIP adjusted daily OHLCV.
- Query window: 2016-01-04 through 2023-12-29.
- Analysis window: 2018-01-02 through 2023-12-29.
- Explicit as-of timestamp: 2026-08-27 17:30 America/New_York.
- Prior and following horizons: 20, 25, 30, 35, 40, 50, 75, and 100 sessions.
- Returns: cumulative log close-to-close.
- Primary response: within-negative-prior Pearson correlation.
- Comparator retained: positive-prior branch.
- States: unfiltered; ER20 sideways/trending; ATR% low/medium/high; signed-ER20
  up/sideways/down.
- Inference: none. No BH family, performance statistic, trading rule, or
  post-2023 outcome was opened.

## Coverage and integrity

All 129 instruments are analyzable. The entire 88-stock sector core and all
controls have full 2016-2023 query coverage. Ten attention names have explicit
partial histories: CVNA, BYND, ROKU, PLTR, COIN, SOFI, HOOD, RIVN, LCID, and
MARA. Their available histories all reach the frozen 2023 endpoint and contain
at least 537 sessions. A live refresh was attempted; the provider returned no
pre-listing rows, confirming that the remaining `partial_history` and
`refresh_needed` health labels are structural rather than unrefreshed cache
gaps. These names remain secondary cohort evidence only.

Twelve integrity checks passed, including:

- exact 129-name registry and cohort sizes;
- exact eight-by-11 sector balance;
- 129/129 coverage eligibility and 88/88 full-history core coverage;
- exact 8x8 horizon grid and nine-state vocabulary;
- all 74,304 expected asset-state-horizon rows;
- adjusted daily bars only and no observations after 2023-12-29; and
- exact overlap parity with the original 30-name atlas to below `5e-16`.

## Primary readout

The signed-ER20 DOWN loss branch remains a plateau across the full coarse
8x8 surface. On the equal prior/following diagonal:

| Horizon | Equal-sector median r | Equal-sector mean r | Sectors with negative median | Core-asset median r | Core negative breadth | Attention median r | Attention negative breadth |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 20 | -0.245 | -0.260 | 11/11 | -0.271 | 88.6% | -0.105 | 56.3% |
| 25 | -0.243 | -0.255 | 11/11 | -0.274 | 86.4% | -0.169 | 68.8% |
| 30 | -0.302 | -0.272 | 11/11 | -0.281 | 86.4% | -0.185 | 75.0% |
| 35 | -0.277 | -0.271 | 11/11 | -0.289 | 89.8% | -0.188 | 75.0% |
| 40 | -0.262 | -0.272 | 11/11 | -0.271 | 88.6% | -0.272 | 81.3% |
| 50 | -0.328 | -0.330 | 11/11 | -0.323 | 89.8% | -0.198 | 87.5% |
| 75 | -0.367 | -0.356 | 11/11 | -0.362 | 92.0% | -0.267 | 75.0% |
| 100 | -0.362 | -0.338 | 10/11 | -0.347 | 83.0% | -0.295 | 75.0% |

The 100-session exception is informative rather than damaging: Health Care is
approximately flat at `+0.013`, while the other ten sector medians remain
negative. The phenomenon is therefore broad, but not a law that every sector
must obey at every checkpoint.

The control cohorts preserve useful separation. Equity ETFs are strongest
throughout (median `-0.390` at 20 and `-0.501` at 100). Non-equity proxies are
near zero at short horizons (`+0.005` at 20) and only modestly negative at 100
(`-0.109`). That contrast argues against treating the geometry as a purely
mechanical consequence that must appear equally in every traded series.

The attention sleeve is heterogeneous. Its median is only `-0.105` with 56.3%
negative breadth at 20, then becomes `-0.295` with 75.0% negative breadth at
100. Several individual attention names retain opposite signs. This is a
challenging cohort that partially recapitulates the broad shape without
becoming uniformly confirmatory.

## What the other filters add

The full nine-state artifact is retained rather than collapsing the study to
signed-down states:

- unfiltered losses remain negative across the diagonal, with equal-sector
  medians from `-0.165` to `-0.255` through 50 and `-0.179` at 100;
- ER20 trending and ATR%-high states carry stronger, more persistent loss
  rebound than ER20 sideways and ATR%-low/medium states;
- signed-down states remain the cleanest directional version of that pattern;
  and
- the negative-prior branch inside signed-up states is structurally sparse at
  20-30 sessions. This is expected because a strongly positive signed path and
  a negative cumulative prior return are mechanically discordant. Sparse cells
  remain blank rather than being imputed or narrated as nulls.

These differences show that the template discriminates behavior. They do not
authorize choosing the darkest filter after inspection.

## Full-vocabulary completion

For completeness, the same 129-instrument atlas was rerun on the union of the
original short horizons and the coarse extension:

`1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 35, 40, 50, 75, 100`

This produces a 15 by 15 grid for each of the same nine states and retains both
prior-sign branches symmetrically: 261,225 asset-state-horizon rows. All 12
integrity checks passed, including exact parity with every original-atlas cell
to `5.55e-16`. No asset, filter, or endpoint was added after reading results.

The complete surface adds two useful qualifications:

- loss rebound is not monotone at the shortest equal horizons. In the
  signed-down diagonal, `1/1` is negative (`-0.189`), `2/2` and `3/3` are
  slightly positive (`+0.019`, `+0.028`), `4/4` is near zero (`-0.010`), and
  the broad negative plateau strengthens from roughly 5-15 sessions onward;
- across all 225 cells, the loss branch remains most negative in ER20 trending
  (`-0.173` median), signed-down (`-0.165`), and ATR%-high (`-0.151`) states;
- the gain branch discriminates differently. ER20/signed-ER sideways states
  have a `+0.027` median and positive continuation sign in 81.8% of cells,
  while ER20 trending has a `-0.028` median and positive continuation sign in
  only 27.6% of cells, consistent with gain exhaustion rather than classical
  continuation in that state; and
- signed-state/prior-sign conflicts create structural sparsity. Only 165/225
  signed-up loss cells and 135/225 signed-down gain cells are described. Those
  blanks remain visible rather than being imputed.

The gain-branch effects are much smaller in magnitude than the loss-rebound
surface. Their value here is behavioral discrimination and hypothesis
generation, not an edge claim or parameter selection.

## Interpretation

This slice did not falsify the broad cumulative loss-rebound morphology. It
strengthened the case that the observation is not confined to TSLA, the
original five-stock groups, one economic sector, or attention-driven equities.
It also exposed real heterogeneity: weaker short-horizon attention behavior,
near-null short-horizon non-equity controls, and a flat Health Care sector at
100.

The result remains cumulative and overlapping. A 100-session forward return
contains all earlier return blocks, so persistence through 100 does not reveal
when the rebound accrues and does not imply a 100-session holding period. The
conditioning variables and prior returns are also shared path functions. No
causal, temporal-transport, independent-observation, or net-edge claim follows.

## Decision

Status:

`DESCRIPTIVE_WIDE_ATLAS_FULL_VOCABULARY_COMPLETE_STOP_BEFORE_SELECTION_OR_TEMPORAL_GATE`

Stop horizon expansion at 100 and do not choose a best horizon or filter from
this surface. The next clean gate belongs to the operator: either decompose the
future into non-overlapping incremental blocks to locate when the cumulative
rebound accrues, or freeze one compact summary and transport it into an
untouched time window.

## Artifacts

- Packet: `runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827`
- Full-vocabulary packet: `runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_full_vocabulary_20260827`
- Registry: `operator_hypothesis_lab/registries/return_geometry_wide_atlas.csv`
- Runner: `scripts/inspect/run_return_geometry_wide_atlas.R`
- Helpers: `operator_hypothesis_lab/R/return_geometry_wide_atlas.R`
- Running deck: `operator_hypothesis_lab/presentations/tsla_descriptive_microscope_evidence.pptx` (slides 114-123 complete the horizon, filter, and prior-sign vocabulary)
